---
name: Android present threading
description: Android startup can invoke the renderer's present hook from both the loading and gameplay threads.
---

The renderer's present transaction must be serialized on Android because loading and gameplay can both present during startup, while frame indices, swapchain image state, command-list state, and completion signaling are shared.

**Why:** Overlapping startup presents can interleave the shared state and leave the gameplay thread parked on a futex even though the native window and GPU setup are still alive.

**How to apply:** Keep the entire present state transition under one synchronization boundary; do not replace it with a partial lock around only the Vulkan call.