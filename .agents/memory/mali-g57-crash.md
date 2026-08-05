---
name: Mali-G57 Android 15 crash fixes
description: Root causes and fixes for SIGSEGV in libGLES_mali and vkGetBufferDeviceAddress on Samsung Galaxy Tab A9 (SM-X110, Mali-G57, Android 15, SDK 35).
---

## Device Info
- SM-X110 (Galaxy Tab A9 Wi-Fi), MT8781V/NA SoC, Mali-G57 MC2, Android 15 SDK 35, arm64-v8a
- EGL driver reports as "meow"; Vulkan HAL reports as "mali"
- Detection: `deviceName.find("mali") || deviceName.find("meow") || IsGalaxyTabA9()` (IsGalaxyTabA9 checks `strncmp(model, "SM-X11", 6)`)

---

## Crash 1 — Shader compiler SIGSEGV (libGLES_mali)

**Pattern:** SIGSEGV in `libGLES_mali.so+0x16c5d38` immediately after shader cache loads, on first `vkCreateGraphicsPipeline`.

### Root Causes (priority order)

### 1. Mixed pipeline layout (PRIMARY)
`g_pipelineLayout` added a 5th descriptor set (set 4) containing a `VK_DESCRIPTOR_TYPE_STORAGE_BUFFER` (conditional survey) alongside 4 UPDATE_AFTER_BIND variable-count bindless sets (sets 0-3). Mali-G57 crashes in the shader compiler when processing any pipeline against such a mixed layout.

**Fix:** `g_capabilities.conditionalSurvey = false` for Mali. Guard all conditional survey buffer/descriptor creation, pipeline layout addition, descriptor binding, and `ProcSetConditionalSurvey` with this flag.

**Why:** Even though the pipeline's shader doesn't use set 4, the Vulkan driver processes the entire pipeline layout during shader compilation. The mixed layout triggers a driver bug in Mali-G57 / Android 15.

### 2. MSAA resolve depth pipelines compiled unconditionally (SECONDARY)
`g_resolveMsaaDepthPipelines[0/1/2]` are created during initialization even on Mali where MSAA is disabled.

**Fix:** `if (!g_isMali)` guard around MSAA resolve depth pipeline creation. Add fallback null-check at runtime usage. Guard lazy MSAA color pipeline creation with `!g_isMali`.

### 3. Timestamp query pools not guarded (TERTIARY)
`VK_QUERY_TYPE_TIMESTAMP` pools created unconditionally; Mali-G57 may report `timestampValidBits == 0`.

**Fix:** `g_capabilities.queryPools = false` for Mali. Guard `createQueryPool`, `resetQueryPool`, `writeTimestamp`, and `queryResults` with this flag.

---

## Crash 2 — vkGetBufferDeviceAddress null pointer (pc=0x0)

**Pattern:** SIGSEGV at `pc=0x0`, `lr` resolving to `plume::VulkanBuffer::getDeviceAddress()` at `plume_vulkan.cpp:955`. Crash on a background thread during archive loading at ~2.4 s.

**Root cause:** MT8781/Mali-G57 on Android 15 exposes buffer-device addressing through the Vulkan 1.1 KHR path. The renderer requested the feature but called only the Vulkan 1.2 core function name, `vkGetBufferDeviceAddress`; that pointer is null on this driver. Every upload buffer creation calls `buffer->getDeviceAddress()`, which then crashes at pc=0x0.

**Fix (in `thirdparty/plume/plume_vulkan.cpp`):**
1. **Always** append `VkPhysicalDeviceBufferDeviceAddressFeatures` to the `vkGetPhysicalDeviceFeatures2` query chain — drivers silently ignore unknown pNext structs, so this is safe on all devices.
2. Enable the KHR feature path on pre-1.2 devices.
3. In `VulkanBuffer::getDeviceAddress`, use `vkGetBufferDeviceAddressKHR` when the Vulkan 1.2 core pointer is unavailable; fail explicitly rather than calling a null pointer if neither is resolved.

**Why:** Volk loads core and KHR command names into separate pointers without automatically aliasing the KHR name to the core one. Supporting both names is required for drivers that expose the original extension API instead of Vulkan 1.2's promoted API.

---

## Key Files
- `MarathonRecomp/gpu/video.cpp`: Mali compat section ~line 2234, BeginCommandList ~line 1957, pipeline creation ~line 2480+
- `thirdparty/plume/plume_vulkan.cpp`: BDA detection ~line 3942, device creation chain ~line 4059
- `thirdparty/plume/plume_render_interface_types.h`: `bool conditionalSurvey = true` in `RenderDeviceCapabilities`
