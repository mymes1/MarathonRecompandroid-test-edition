---
name: Mali upload reuse and generations
description: Correctness rules for Mali guest-buffer upload caching and Vulkan texture wrapper identity.
---

Mali guest-buffer uploads must be immutable snapshots cached by frame-slot serial and content-generation. Re-copying an entire guest buffer at every draw can exhaust the per-frame upload arena; caching only a native reference without invalidating on unlock can render stale geometry.

**Why:** The guest lock memory is reused after unlock, while the GPU may still read prior frames. The safe boundary is an unlock snapshot, followed by one upload per frame slot and element width.

**How to apply:** Invalidate the cached upload on every writable unlock and when a frame slot's fence retires. Also clear the stream cache whenever an upload cannot obtain source memory; a failed upload must never leave a reference that can satisfy the fast path. Keep the snapshot alive until the upload is no longer referenced.

Vulkan texture wrapper generations must come from a process-wide monotonic source for every wrapper lifetime, including default construction, move construction, and move assignment replacement.

**Why:** Swapchain textures live in movable vectors, and address reuse can make a stale deferred barrier appear to target a newly assigned image.

**How to apply:** Capture generation when queuing a barrier and reject it unless both the wrapper is live and its generation still matches.

Queued Mali texture unlocks need the same native-wrapper generation check and in-flight ownership as uploads.

**Why:** An unlock can cross a Present/BeginCommandList boundary while the guest texture is replaced or released; a raw pointer alone can otherwise submit a copy to a stale image or outlive its guest wrapper.

**How to apply:** Capture the native wrapper and generation when queuing the unlock, defer destruction while it is pending, and release the in-flight ownership on every completion or rejection path.