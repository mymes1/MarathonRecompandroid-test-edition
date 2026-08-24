#include <stdafx.h>
#include "memory.h"
#include <os/logger.h>

#include <atomic>
#include <cstring>

Memory::Memory()
{
#ifdef _WIN32
    base = (uint8_t*)VirtualAlloc((void*)0x100000000ull, PPC_MEMORY_SIZE, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

    if (base == nullptr)
        base = (uint8_t*)VirtualAlloc(nullptr, PPC_MEMORY_SIZE, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

    if (base == nullptr)
        return;

    DWORD oldProtect;
    VirtualProtect(base, 4096, PAGE_NOACCESS, &oldProtect);
#else
    base = (uint8_t*)mmap((void*)0x100000000ull, PPC_MEMORY_SIZE, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);

    if (base == (uint8_t*)MAP_FAILED)
        base = (uint8_t*)mmap(nullptr, PPC_MEMORY_SIZE, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);

    if (base == (uint8_t*)MAP_FAILED)
    {
        base = nullptr;
        return;
    }

#ifdef __ANDROID__
    // Keep the guest null page readable and writable. The SM-X110 startup race
    // can briefly dereference a half-constructed CSD object at guest offset
    // 0x2A. Although the full guest mapping is requested RW, the device report
    // proves that this address was protected at the point of access
    // (SIGSEGV/SEGV_ACCERR at base+0x2A). Explicitly establish and verify the
    // compatibility-page contract rather than relying on the initial mapping's
    // permissions remaining unchanged. Zero it so absorbed reads are deterministic.
    if (mprotect(base, 4096, PROT_READ | PROT_WRITE) != 0)
    {
        munmap(base, PPC_MEMORY_SIZE);
        base = nullptr;
        return;
    }
    memset(base, 0, 4096);
    guestNullPageReadable = true;
#else
    mprotect(base, 4096, PROT_NONE);
#endif
#endif

    for (size_t i = 0; PPCFuncMappings[i].guest != 0; i++)
    {
        if (PPCFuncMappings[i].host != nullptr)
            InsertFunction(PPCFuncMappings[i].guest, PPCFuncMappings[i].host);
    }
}

void* MmGetHostAddress(uint32_t ptr)
{
    return g_memory.Translate(ptr);
}

// Called from the hardened PPC_CALL_INDIRECT_FUNC (MarathonRecompLib/ppc/ppc_detail.h)
// when an indirect call's target is outside the recompiled code range or resolves to no
// host function - a wild jump the process could never survive. Skipping the call keeps
// the half-constructed-state races (indirect call through guest null while loading
// archives) non-fatal; the log keeps them visible.
extern "C" void PPCIndirectCallMissing(PPCContext& ctx, uint8_t* base, uint32_t target)
{
    static std::atomic<uint32_t> s_reportCount{ 0 };
    if (s_reportCount.fetch_add(1, std::memory_order_relaxed) < 16)
    {
        LOGF_ERROR("Indirect call to unmapped guest address {:08X} skipped (r3={:08X}).",
            target, ctx.r3.u32);
    }
}
