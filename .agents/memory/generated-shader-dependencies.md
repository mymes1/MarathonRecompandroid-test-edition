---
name: Generated shader dependencies
description: Keep embedded DXC SPIR-V headers synchronized with shared HLSL includes.
---

Generated shader headers must depend on every shared HLSL header that can change their resource declarations, not only the direct `.hlsl` source.

**Why:** CMake custom commands do not automatically track DXC includes. A shared descriptor-layout change can otherwise leave stale SPIR-V in the Android binary, causing vendor shader-compiler failures even though the source HLSL looks fixed.

**How to apply:** When changing shared shader declarations, verify the generated `.spirv.h` files directly and ensure the build graph reruns DXC for all affected shaders.