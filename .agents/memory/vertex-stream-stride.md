---
name: Vertex stream stride width
description: Durable constraint for Xbox 360 vertex stream stride handling in the Vulkan renderer.
---

Vertex stream strides must remain full 32-bit values through pipeline-state caching and Vulkan input-slot creation. Treating a stride as an 8-bit value silently wraps larger meshes and makes the GPU advance through the wrong vertex rows, producing persistent stretched or morphing geometry.

**Why:** The corruption pattern can affect both the title screen and gameplay while leaving 2D UI correct, which points to malformed shared vertex input rather than swapchain output.

**How to apply:** When adding or reviewing vertex stream state, keep the guest/API stride and the cached pipeline stride at `uint32_t`; do not introduce narrowing casts for storage or dirty-state comparisons.

Vertex upload endian conversion must begin at buffer byte zero, matching the established desktop unlock path. The active stream offset is applied only when binding the already-converted buffer and remains part of the per-frame cache key.

**Why:** Xbox vertex storage is arranged as big-endian 32-bit lanes from the start of the allocation. Treating a non-word-aligned stream offset as a fresh endian boundary rotates every subsequent lane, producing stretched geometry and fragmented meshes on Mali.

**How to apply:** Convert every complete 32-bit lane in the immutable buffer snapshot, preserve only the final incomplete tail verbatim, then bind at `allocation + streamOffset`; invalidate/rebuild when the offset changes.