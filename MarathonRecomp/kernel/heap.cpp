#include <stdafx.h>
#include "heap.h"
#include "memory.h"
#include "function.h"
#include "xdm.h"

#include <cstdint>

constexpr size_t RESERVED_BEGIN = 0x7FEA0000;
constexpr size_t RESERVED_END = 0xA0000000;

namespace
{
    // Bookkeeping for physically-aligned allocations. It lives INSIDE the
    // o1heap allocation, in the bytes immediately before the aligned pointer
    // that is returned to the guest.
    //
    // CRITICAL CONTRACT (violated by the previous implementation): o1heap
    // keeps its own FragmentHeader {next, prev, size, used} in the
    // O1HEAP_ALIGNMENT bytes (32 on 64-bit) immediately BEFORE the pointer
    // o1heapAllocate returns, and every returned pointer is already aligned
    // to O1HEAP_ALIGNMENT. The old code rounded the o1heap pointer down/up
    // to the requested alignment and stored bookkeeping at returned[-1] and
    // returned[-2]. For any requested alignment <= O1HEAP_ALIGNMENT (every
    // AllocPhysical<T> object and every 0x10-aligned texture/buffer lock)
    // the aligned pointer EQUALLED the o1heap pointer, so those writes
    // landed directly on top of o1heap's `size` and `used` fields. The
    // corrupted fragment headers then desynchronised the free lists on
    // o1heapFree, handing out overlapping guest allocations. On Android
    // (SM-X110 included) this presented as garbage overwriting guest data
    // (CSD resource names turned into binary junk), guest function
    // pointers becoming small integers (SIGBUS/SIGSEGV at guest_base+2 and
    // guest_base+0xA during archive loads), missing UI/touch overlays and
    // glitching geometry - varying run to run with allocation timing.
    struct PhysicalHeader
    {
        void* original; // Pointer originally returned by o1heapAllocate.
        size_t size;    // Payload size requested by the caller.
    };

    size_t RoundUpToPowerOfTwo(size_t value)
    {
        size_t result = 1;
        while (result < value)
            result <<= 1;
        return result;
    }
}

void Heap::Init()
{
    heap = o1heapInit(g_memory.Translate(0x20000), RESERVED_BEGIN - 0x20000);
    physicalHeap = o1heapInit(g_memory.Translate(RESERVED_END), 0x100000000 - RESERVED_END);
}

void* Heap::Alloc(size_t size)
{
    std::lock_guard lock(mutex);

    return o1heapAllocate(heap, std::max<size_t>(1, size));
}

void* Heap::AllocPhysical(size_t size, size_t alignment)
{
    size = std::max<size_t>(1, size);
    alignment = alignment == 0 ? 0x1000 : RoundUpToPowerOfTwo(std::max<size_t>(alignment, O1HEAP_ALIGNMENT));

    std::lock_guard lock(physicalMutex);

    // Reserve enough room for the interior bookkeeping header plus the worst
    // case alignment shift, so the aligned user pointer (and the header
    // directly before it) always fit inside this allocation. The header must
    // NEVER be written into the O1HEAP_ALIGNMENT bytes preceding the o1heap
    // pointer: that region belongs to o1heap's fragment header.
    void* ptr = o1heapAllocate(physicalHeap, size + alignment + sizeof(PhysicalHeader));
    if (ptr == nullptr)
        return nullptr;

    const uintptr_t raw = reinterpret_cast<uintptr_t>(ptr);
    const uintptr_t user = (raw + sizeof(PhysicalHeader) + alignment - 1) & ~uintptr_t(alignment - 1);

    auto* header = reinterpret_cast<PhysicalHeader*>(user - sizeof(PhysicalHeader));
    header->original = ptr;
    header->size = size;

    return reinterpret_cast<void*>(user);
}

void Heap::Free(void* ptr)
{
    if (ptr == nullptr)
        return;

    if (ptr >= physicalHeap)
    {
        // Aligned physical allocations carry their bookkeeping header
        // immediately before the returned pointer (see AllocPhysical).
        auto* header = reinterpret_cast<PhysicalHeader*>(
            reinterpret_cast<uintptr_t>(ptr) - sizeof(PhysicalHeader));
        void* original = header->original;

        std::lock_guard lock(physicalMutex);
        o1heapFree(physicalHeap, original);
    }
    else
    {
        std::lock_guard lock(mutex);
        o1heapFree(heap, ptr);
    }
}

size_t Heap::Size(void* ptr)
{
    if (ptr == nullptr)
        return 0;

    if (ptr >= physicalHeap)
        return reinterpret_cast<PhysicalHeader*>(
            reinterpret_cast<uintptr_t>(ptr) - sizeof(PhysicalHeader))->size;

    return *((size_t*)ptr - 2) - O1HEAP_ALIGNMENT; // relies on fragment header in o1heap.c
}

uint32_t RtlAllocateHeap(uint32_t heapHandle, uint32_t flags, uint32_t size)
{
    void* ptr = g_userHeap.Alloc(size);
    if ((flags & 0x8) != 0)
        memset(ptr, 0, size);

    assert(ptr);
    return g_memory.MapVirtual(ptr);
}

uint32_t RtlReAllocateHeap(uint32_t heapHandle, uint32_t flags, uint32_t memoryPointer, uint32_t size)
{
    void* ptr = g_userHeap.Alloc(size);
    if ((flags & 0x8) != 0)
        memset(ptr, 0, size);

    if (memoryPointer != 0)
    {
        void* oldPtr = g_memory.Translate(memoryPointer);
        memcpy(ptr, oldPtr, std::min<size_t>(size, g_userHeap.Size(oldPtr)));
        g_userHeap.Free(oldPtr);
    }

    assert(ptr);
    return g_memory.MapVirtual(ptr);
}

uint32_t RtlFreeHeap(uint32_t heapHandle, uint32_t flags, uint32_t memoryPointer)
{
    if (memoryPointer != NULL)
        g_userHeap.Free(g_memory.Translate(memoryPointer));

    return true;
}

uint32_t RtlSizeHeap(uint32_t heapHandle, uint32_t flags, uint32_t memoryPointer)
{
    if (memoryPointer != NULL)
        return (uint32_t)g_userHeap.Size(g_memory.Translate(memoryPointer));

    return 0;
}

uint32_t XAllocMem(uint32_t size, uint32_t flags)
{
    void* ptr = (flags & 0x80000000) != 0 ?
        g_userHeap.AllocPhysical(size, (1ull << ((flags >> 24) & 0xF))) :
        g_userHeap.Alloc(size);

    if ((flags & 0x40000000) != 0)
        memset(ptr, 0, size);

    assert(ptr);
    return g_memory.MapVirtual(ptr);
}

void XFreeMem(uint32_t baseAddress, uint32_t flags)
{
    if (baseAddress != NULL)
        g_userHeap.Free(g_memory.Translate(baseAddress));
}

uint32_t XVirtualAlloc(void *lpAddress, unsigned int dwSize, unsigned int flAllocationType, unsigned int flProtect)
{
    assert(!lpAddress);
    return g_memory.MapVirtual(g_userHeap.Alloc(dwSize));
}

uint32_t XVirtualFree(uint32_t lpAddress, unsigned int dwSize, unsigned int dwFreeType)
{
    if ((dwFreeType & 0x8000) != 0 && dwSize)
        return FALSE;

    if (lpAddress)
        g_userHeap.Free(g_memory.Translate(lpAddress));

    return TRUE;
}

GUEST_FUNCTION_HOOK(sub_82915668, XVirtualAlloc);
GUEST_FUNCTION_HOOK(sub_829156B8, XVirtualFree);

GUEST_FUNCTION_STUB(sub_82535588); // HeapCreate // replaced
// GUEST_FUNCTION_STUB(sub_82BD9250); // HeapDestroy

GUEST_FUNCTION_HOOK(sub_82535B38, RtlAllocateHeap); // repalced
GUEST_FUNCTION_HOOK(sub_82536420, RtlFreeHeap); // replaced
GUEST_FUNCTION_HOOK(sub_82536708, RtlReAllocateHeap); // replaced
GUEST_FUNCTION_HOOK(sub_82534DD0, RtlSizeHeap); // replaced

GUEST_FUNCTION_HOOK(sub_82537E70, XAllocMem); // replaced
GUEST_FUNCTION_HOOK(sub_82537F08, XFreeMem); // replaced
