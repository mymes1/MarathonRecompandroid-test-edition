---
name: Mali-G57 Android 15 crash fixes
description: Root causes and fixes for SIGSEGV in libGLES_mali on Samsung Galaxy Tab A9 (SM-X110, Mali-G57, Android 15, SDK 35).
---

## Crash Pattern
FATAL SIGNAL 11 (SIGSEGV) in `libGLES_mali.so+0x16c5d38` (shader compiler) immediately after the embedded shader cache loads, on first `vkCreateGraphicsPipeline` call.

## Root Causes (in priority order)

### 1. Conditional survey storage-buffer in pipeline layout (PRIMARY)
The main `g_pipelineLayout` added a 5th descriptor set (set 4) containing a `VK_DESCRIPTOR_TYPE_STORAGE_BUFFER` (the conditional survey) alongside 4 UPDATE_AFTER_BIND variable-count bindless sets (sets 0-3). The Mali-G57 system Vulkan driver (libGLES_mali) crashes in its shader compiler when processing any pipeline against a layout that mixes UPDATE_AFTER_BIND bindless sets with a non-bindless storage-buffer set.

**Fix:** `g_capabilities.conditionalSurvey = false` for Mali. Guard all conditional survey buffer/descriptor creation, pipeline layout addition, descriptor binding, and `ProcSetConditionalSurvey` with this flag.

**Why:** Even though the pipeline's shader doesn't use set 4, the Vulkan driver processes the entire pipeline layout during shader compilation. The mixed layout triggers a driver bug in Mali-G57 / Android 15.

### 2. MSAA resolve depth pipelines compiled unconditionally (SECONDARY)
`g_resolveMsaaDepthPipelines[0/1/2]` (resolve_msaa_depth_2x/4x/8x shaders) are created during initialization even on Mali where MSAA is disabled. These shaders use multisampled depth texture reads that may additionally crash the Mali shader compiler.

**Fix:** `if (!g_isMali)` guard around MSAA resolve depth pipeline creation. Add fallback null-check at runtime usage. Guard lazy MSAA color pipeline creation with `!g_isMali`.

### 3. Timestamp query pools not guarded (TERTIARY)
`VK_QUERY_TYPE_TIMESTAMP` pools created unconditionally; Mali-G57 may report `timestampValidBits == 0` making timestamp operations undefined behavior.

**Fix:** `g_capabilities.queryPools = false` for Mali. Guard `createQueryPool`, `resetQueryPool`, `writeTimestamp`, and `queryResults` with this flag.

## Key Files
- `MarathonRecomp/gpu/video.cpp`: Mali compat section ~line 2234, BeginCommandList ~line 1957, pipeline creation ~line 2480+
- `thirdparty/plume/plume_render_interface_types.h`: Added `bool conditionalSurvey = true` to `RenderDeviceCapabilities`

## Device Info
- SM-X110 (Galaxy Tab A9 Wi-Fi), MT8781V/NA SoC, Mali-G57 MC2, Android 15 SDK 35, arm64-v8a
- EGL driver reports as "meow"; Vulkan HAL reports as "mali"
- Detection: `deviceName.find("mali") || deviceName.find("meow") || IsGalaxyTabA9()` (IsGalaxyTabA9 checks `strncmp(model, "SM-X11", 6)`)
