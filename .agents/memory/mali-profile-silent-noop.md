---
name: Mali profile can silently no-op
description: On SM-X110 a clean log.txt does not mean the renderer is healthy - every geometry/texture workaround AND all of its validation logging are gated on g_isMali.
---

Every Mali workaround in `gpu/video.cpp` is gated on `g_isMali`: canonical 32-bit-lane
vertex endian conversion, tight upload row packing (`g_uploadPitchAlignment = 1`),
triangle-fan emulation, conservative descriptor limits, MSAA/query-pool/conditional-survey
disabling. So is the validation that would otherwise explain a bad frame —
`ValidateMaliVertexRange`, `WarnSkippedMaliDraw`, and the `UploadMaliGuestVertexBuffer`
warnings all early-return or are unreachable when `g_isMali` is false.

**Consequence:** a device that fails Mali detection renders Xbox big-endian vertex buffers
unconverted and uploads textures with desktop row padding, producing exactly the reported
"geometry and textures constantly stretching and morphing" — while log.txt stays completely
clean, because nothing on that path warns. A clean log is therefore *not* evidence the
renderer is healthy; it is equally consistent with the compatibility profile never engaging.

**Why:** Multiple fix rounds targeted the renderer while the profile that the fixes live
inside may not have been active. Without an explicit record of which path ran, the log
cannot distinguish "workaround applied and insufficient" from "workaround never applied".

**How to apply:**
- `IsMaliDevice()` is the single source of truth; both call sites (ETC2 transcode decision
  and the main capability block) must use it so textures and pipelines never disagree.
- Detection sources, in order: lowered Vulkan device name (`mali`/`meow`), `ro.product.model`
  prefix `SM-X11`, then `ro.hardware.vulkan` / `ro.hardware.egl` / `ro.hardware.gralloc` /
  `ro.soc.model` containing `mali`/`meow`.
- `LogMaliDetection` prints every property verbatim, marking absent ones `<empty>`, and the
  capability block logs `Mali compatibility profile: ENABLED` or an explicit `DISABLED`
  warning. `LogRendererProfile` records the effective texture path, descriptor limits,
  upload alignments, viewport/window sizes and quality settings.
- When triaging a glitch report on this device family, read `maliProfile=` first. If it says
  `DISABLED`, extend detection — do not patch the renderer.
