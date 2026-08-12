---
name: Vertex stream stride width
description: Durable constraint for Xbox 360 vertex stream stride handling in the Vulkan renderer.
---

Vertex stream strides must remain full 32-bit values through pipeline-state caching and Vulkan input-slot creation. Treating a stride as an 8-bit value silently wraps larger meshes and makes the GPU advance through the wrong vertex rows, producing persistent stretched or morphing geometry.

**Why:** The corruption pattern can affect both the title screen and gameplay while leaving 2D UI correct, which points to malformed shared vertex input rather than swapchain output.

**How to apply:** When adding or reviewing vertex stream state, keep the guest/API stride and the cached pipeline stride at `uint32_t`; do not introduce narrowing casts for storage or dirty-state comparisons.

Vertex upload endian conversion must begin at the active stream offset, and that offset must be part of the per-frame upload cache key.

**Why:** Converting from byte zero while binding from a nonzero stream offset interprets padding or another stream as vertex zero, producing stretched geometry and fragmented meshes on Mali.

**How to apply:** Copy the full immutable snapshot if needed, but swap only `[streamOffset, dataSize)` using `(dataSize - streamOffset) / stride` vertices; invalidate/rebuild when the offset changes.