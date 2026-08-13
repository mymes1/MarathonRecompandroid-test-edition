---
name: Mali Vulkan object creation
description: Android Mali driver behavior when resource loading overlaps render-thread shader and pipeline creation
---

On affected Android Mali system drivers, serialize Vulkan device-object construction across threads, including shader modules, graphics pipelines, textures, buffers, descriptor sets, and views. Vulkan's external synchronization rules do not prevent this vendor-driver crash pattern.

**Why:** Startup crashes occurred inside `libGLES_mali` while resource loading overlapped render-thread pipeline compilation, even after descriptor, MSAA, upload, and present workarounds were enabled.

**How to apply:** Keep the serialization at the Vulkan backend's object-construction boundary so new renderer call sites inherit the protection without requiring every caller to know about the Mali limitation.