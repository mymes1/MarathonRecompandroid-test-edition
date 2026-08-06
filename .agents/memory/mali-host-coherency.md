---
name: Mali host-memory coherency
description: Vulkan upload buffers on Mali must explicitly flush host writes before GPU consumption.
---

Persistent mapped upload allocations cannot be assumed to be host-coherent on Android Mali.

**Why:** The tablet’s GPU-only corruption pattern is consistent with stale or partially visible constant, vertex, index, or staging data, while the UI remains intact.

**How to apply:** Flush the written range after persistent mapped uploads and before command submission; also flush one-shot staging buffers before transfer commands. Keep this backend operation a no-op on coherent backends.