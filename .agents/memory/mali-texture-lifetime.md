---
name: Mali texture wrapper lifetime and upload ordering
description: Swapchain wrapper moves and worker-thread uploads can invalidate Vulkan barriers or race image consumers on SM-X110.
---

Vulkan texture wrappers kept in movable containers must transfer registry membership and native ownership during moves; registering only constructor temporaries makes every swapchain barrier look stale.

**Why:** On SM-X110, rejected swapchain barriers caused black/tearing output, while texture copies recorded from loader threads could race graphics consumption when command-list state was thread-local.

**How to apply:** Use explicit move-only VulkanTexture semantics for movable wrapper storage, and serialize Mali uploads on the graphics queue with completion before exposing the texture to guest rendering.

For Mali-G57 geometry, prefer host-visible vertex/index buffers with explicit mapped-range flushes over device-local destinations fed by staged copy commands.

**Why:** The device-local staging path continued to produce stretched/morphed geometry after image barrier fixes, indicating the Mali driver was not reliably honoring the renderer's generic transfer-to-vertex dependency.

**How to apply:** Select the upload heap for Mali vertex/index buffers and avoid adding a transfer command or temporary staging buffer for those resources.

For Mali guest geometry, publishing a new per-frame upload at unlock is not
enough by itself: active vertex/index bindings must be repointed immediately
when the guest unlocks a buffer, and again when a frame slot is reused.

**Why:** The guest can update a locked buffer without issuing another
SetStreamSource/SetIndices call. Leaving the old view active made the renderer
submit a stale allocation even though the unlock had produced a safe copy,
causing stretched/morphed geometry.

**How to apply:** Treat unlock as the publication boundary. Keep the upload
allocation alive behind the frame fence, refresh every active binding that
references the changed buffer, and refresh bound buffers after the slot fence
retires.