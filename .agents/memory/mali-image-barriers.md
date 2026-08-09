---
name: Mali image barrier validation
description: Defensive Vulkan image-barrier validation for Android Mali drivers that may crash on malformed or stale barrier inputs.
---

Vulkan texture barriers must validate the wrapper lifetime and native image state before constructing `VkImageMemoryBarrier`. A stale `RenderTexture*`, null `VkImage`, zero mip/layer range, or missing aspect mask can make Android Mali crash inside command encoding instead of returning a validation error.

**Why:** The SM-X110 crash symbolized to `VulkanCommandList::barriers` while the driver consumed the image barrier, and the renderer’s guest-resource lifetime allowed raw texture pointers to remain in pending barrier state.

**How to apply:** Keep live Vulkan texture wrappers trackable, reject invalid barriers before dereferencing them, initialize base mip/layer fields explicitly, and only update tracked layout state after a valid barrier is accepted.