---
name: Mali texture wrapper lifetime and upload ordering
description: Swapchain wrapper moves and worker-thread uploads can invalidate Vulkan barriers or race image consumers on SM-X110.
---

Vulkan texture wrappers kept in movable containers must transfer registry membership and native ownership during moves; registering only constructor temporaries makes every swapchain barrier look stale.

**Why:** On SM-X110, rejected swapchain barriers caused black/tearing output, while texture copies recorded from loader threads could race graphics consumption when command-list state was thread-local.

**How to apply:** Use explicit move-only VulkanTexture semantics for movable wrapper storage, and serialize Mali uploads on the graphics queue with completion before exposing the texture to guest rendering.