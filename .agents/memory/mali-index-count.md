---
name: Indexed draw count semantics
description: Guest DrawIndexedPrimitive wrapper count argument is already an index count.
---

The hooked `DrawIndexedPrimitive` entry point used by Marathon passes an expanded index count, not a D3D primitive count. Do not run it through `PrimitiveVertexCount()` again.

**Why:** Re-expanding the count makes valid title/game meshes look out of range (e.g. a valid count of 6360 becomes 19080), causing large portions of geometry to be skipped or glitch after the title screen.

**How to apply:** Store the command field as `indexCount`, validate `startIndex + indexCount` against the index buffer, and pass that same count to `drawIndexedInstanced()`.
