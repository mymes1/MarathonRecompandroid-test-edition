---
name: Guest physical heap o1heap header corruption
description: AllocPhysical bookkeeping overwrote o1heap fragment headers, corrupting guest memory on every aligned allocation - the root cause of the SM-X110 "two scenarios" (instant crash / glitchy boot with hidden controls).
---

## Root cause (found 2026-08-21 from device logs)

`Heap::AllocPhysical` (kernel/heap.cpp) realigned the o1heap pointer and stored
bookkeeping at `returned[-1]`/`returned[-2]`. o1heap keeps its `FragmentHeader
{next, prev, size, used}` in the `O1HEAP_ALIGNMENT` bytes (32 on arm64)
immediately **before** every returned pointer, and already guarantees 32-byte
alignment. For every requested alignment <= 32 (all `AllocPhysical<T>` guest
resource wrappers - GuestTexture/GuestBuffer/GuestShader/GuestSurface/etc. -
plus every 0x10-aligned texture/buffer lock buffer) the aligned pointer equalled
the o1heap pointer, so the writes clobbered the fragment `size` and `used`
fields. The first `o1heapFree` of such a fragment then desynchronised the free
lists and handed out **overlapping guest allocations**.

## On-device symptoms (SM-X110, Android 15, log.txt evidence)

- Scenario A (crash at black screen): SIGBUS pc=guest_base+2 and SIGSEGV
  memcpy fault at guest_base+0xA during the enemy.arc/player.arc load burst -
  guest pointers corrupted to small integers (fault addrs 0x7600000002 /
  0x750000000a decode exactly as mmap_base + 2 / + 0xA).
- Scenario B (boots, "everything glitches", touch controls never visible but
  hit-testing works): log shows `CSD loaded: <binary garbage>` - resource name
  buffers overwritten with vertex-like data from overlapping allocations;
  ImGui font/overlay data corrupted -> whole overlay invisible. Older builds
  also spammed `Ignoring invalid Vulkan texture barrier` as collateral.
- Which scenario occurs varies with allocation/free timing - same APK.

This was NOT a Mali/GPU bug; the earlier renderer fixes were treating fallout.

## Fix

Bookkeeping header (`original` pointer + payload `size`) now lives **inside**
the allocation at `[user-16, user)`, alignment normalised to >= O1HEAP_ALIGNMENT
and a power of two, and `Free`/`Size` read that interior header for physical
pointers. Never write into the O1HEAP_ALIGNMENT bytes preceding an o1heap
pointer.

## How to verify on device

After the fix, `CSD loaded:` lines in log.txt must always print clean ASCII
names (e.g. `english`, `sprite/loading/loading_english`), never binary junk -
that log line is the live corruption canary.
