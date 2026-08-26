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

## Confirmed on device (SM-X110, build 1.0.7) — detection is NOT the failure

The diagnostic did its job and **refuted** the detection-failure hypothesis:

```
[LogMaliDetection] [renderer] Vulkan device name='Mali-G57 MC2' | ro.product.model='SM-X110'
  ro.product.device='gta9wifi' ro.soc.model='MT8781V/NA' ro.hardware.vulkan='mali'
  ro.hardware.egl='meow' ro.board.platform='mt6789'
[CreateHostDevice] [renderer] Mali compatibility profile: ENABLED.
[LogRendererProfile] [renderer] maliProfile=ENABLED texturePath=ETC2/EAC CPU transcode
  descriptors=1024textures/1024samplers uploadPitchAlign=1 placementAlign=4
```

So the profile engages and the workarounds are live. Two things the same log settled:

- **The real visual problem was resolution scale** — see
  [android-resolution-scale-lookalike](android-resolution-scale-lookalike.md).
- **Touch controls are genuinely emitted, not skipped.** `[touch] drawing overlay:
  viewport=1340x800 window=1340x800 imguiDisplay=1340x800 edit=false policy=0` — all three
  coordinate spaces agree, so "responds to taps but never visible" is **not** layout or
  clipping. It is renderer state or the draw being discarded downstream. Still open.
  Note `SetGraphicsPushConstants(rangeIndex, data, offset=0, size=0)` uploads the *whole*
  range when `size == 0` (`plume_vulkan.cpp`), so the initial full-struct upload including
  `scale = (1,1)` is correct — that is not the cause.
