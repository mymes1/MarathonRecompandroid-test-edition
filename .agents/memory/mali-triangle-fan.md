---
name: Mali triangle fan emulation
description: Avoid native Vulkan triangle-fan draws on Samsung SM-X110 Mali-G57.
---

Force `g_capabilities.triangleFan = false` on the Mali/SM-X110 compatibility path and emulate triangle fans with generated triangle-list indices.

**Why:** Native `VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN` on the Android 15 Mali-G57 stack can produce screen-sized wedges/smeared triangles while UI overlays remain intact.

**How to apply:** Convert both sequential and indexed triangle-fan submissions to triangle-list index buffers before flushing render state. Do the same for indexed quad-list submissions on Mali. Pass the generated triangle-list index count to `drawIndexedInstanced`; for `DrawPrimitiveUP`, generate indices from the computed vertex count (`PrimitiveVertexCount`), not the raw primitive count.
