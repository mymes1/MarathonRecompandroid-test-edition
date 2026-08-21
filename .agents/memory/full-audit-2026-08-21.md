---
name: Full-project audit 2026-08-21
description: Findings and fixes from the subsystem-by-subsystem audit that followed the o1heap corruption fix. Lists what was fixed and known-acceptable risks left in place.
---

## Fixed in this audit

1. **File I/O thread safety** (`kernel/io/file_system.cpp`): `FileHandle::stream`
   (std::fstream) was used from multiple guest threads with no lock while the
   360 issues overlapped reads on one HANDLE (archives, movie/audio streaming,
   save data). A concurrent seekg+read pair delivers the wrong file region into
   a guest buffer. Added a per-handle `ioMutex` around read/seek/write.
2. **WIN32_FIND_DATAA size fields were swapped** (same file): nFileSizeLow got
   `size >> 32` and nFileSizeHigh got `size & 0xFFFFFFFF`, so the guest computed
   `size << 32` for every found file. Also made cFileName NUL-termination
   explicit (strncpy alone can leave it unterminated at exactly MAX_PATH).
3. **ImGui fed from foreign threads** (`ui/game_window.cpp`): SDL fires event
   watches on the pushing thread - the Java UI thread for touch on Android -
   while ImGui::NewFrame/Render ran on the present thread. ImGui is not
   thread-safe; its input queue is a plain vector. Events are now queued under
   a mutex and drained by `GameWindow::ProcessPendingImGuiSDLEvents()` on the
   present thread immediately before `ImGui_ImplSDL2_NewFrame`.
4. **Swapchain recreation now spec-clean** (`gpu/video.cpp` + plume
   `RenderDevice::waitIdle()`/`VulkanDevice::waitIdle`): a failed acquire or
   present (background/rotation/OUT_OF_DATE) leaves the frame semaphores in an
   undefined state that must not be reused. The resize path now drains the
   device and recreates all acquire/render semaphores between frames.
5. **Config::Save** (`user/config.cpp`): unsynchronized truncating writes from
   several threads could interleave; now mutex-serialized and published via
   same-directory temp file + rename (with copy fallback).

## Audited and left as-is (known risks, all pre-existing upstream behavior)

- `XMAPlaybackDestroy` is a no-op (playback objects + decoder threads leak per
  stream; bounded, and making it free risks UAF if the game queries a destroyed
  playback).
- `__builtin_debugtrap()` landmines: `CreateShader` on shader-cache miss,
  `XMAPlaybackGetRemainingLoopCount`/`QueryCurrentPosition`, split-frame
  without next packet in the XMA decoder, `NtAllocateVirtualMemory`. None are
  hit by the SM-X110 logs; the shader one fires only with a mismatched dump.
- `KeWaitForSingleObject`/`Event::Wait` only support timeout 0/INFINITE; finite
  timeouts return success without waiting in release builds.
- `XSetFilePointerEx` signature treats the 64-bit distance as int32 (hook is
  disabled in the export table; only `XSetFilePointer` is live).
- `GuestThreadHandle::Wait(timeout)` polls with 1 ms sleeps (correct, just not
  elegant). HID controller state races are read-only u16 tearing at worst.
- Render-command ownership (ownedMemory, deferred Mali upload/unlock commands)
  verified: every path releases exactly once; deferral copies transfer
  ownership; replay cannot re-defer.
- `g_pathCache` is built once before guest threads start, then read-only.
- Kernel pointer marshalling maps guest pointers to `base + u32` with no
  bounds check by design (the readable guest null page on Android relies on
  it). Do not add a blanket low-address reject.
