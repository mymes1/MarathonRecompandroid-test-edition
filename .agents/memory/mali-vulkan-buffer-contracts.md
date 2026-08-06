---
name: Mali Vulkan buffer contracts
description: Non-obvious Vulkan buffer usage requirements for the Mali-G57 Android renderer
---

The renderer must declare every Vulkan buffer usage that its later command path actually performs. In particular, a buffer bound with vertex-buffer commands needs vertex usage, and a buffer whose GPU address is passed to raw shader loads needs shader-device-address usage.

**Why:** Mobile Mali drivers are less forgiving than desktop drivers when a resource is used outside the usage bits supplied at creation. The resulting failure can look like missing geometry or smeared shader output instead of a clean validation error.

**How to apply:** When adding or changing a render buffer helper, compare its flags with every command and shader path that consumes it; do not infer correctness from the fact that desktop drivers render successfully.