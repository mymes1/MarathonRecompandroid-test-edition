---
name: Android resolution scale is a visual-corruption lookalike
description: A forced 0.25 resolution scale renders SM-X110 at 335x200 upscaled 4x, which is visually indistinguishable from geometry/texture corruption while every renderer diagnostic stays clean.
---

`Config::ResolutionScale` multiplies the viewport to produce the guest's internal render
resolution (`SetResolution`, and the loading/movie surface path):

```cpp
uint32_t width  = uint32_t(round(Video::s_viewportWidth  * Config::ResolutionScale));
uint32_t height = uint32_t(round(Video::s_viewportHeight * Config::ResolutionScale));
```

The Android build defaulted to `0.25f`, and `ApplyMaliRuntimeOverrides` additionally forced
any value above `0.5f` back down to `0.25f` on **every** launch. On the Tab A9's 1340x800
panel that renders the 3D scene at **335x200** and upscales it 4x.

**Why this matters:** a 4x upscale of a 335x200 buffer produces smeared, blocky, constantly
shifting geometry and textures. That is exactly how "geometry and textures are glitching,
stretching, morphing" reads to a player - while the renderer is behaving correctly, so
`maliProfile=ENABLED`, no `WarnSkippedMaliDraw`, and a completely clean log. The forced
downgrade also silently discarded the user's explicit Options choice each launch, so the
setting could never be raised.

Confirmed from device log (SM-X110, build 1.0.7):
`[renderer] viewport=0x0 window=1340x800 resolutionScale=0.25` — the `viewport=0x0` is
benign ordering (`LogRendererProfile` runs before the swapchain reports
`Changed resolution: 1340x800`); by the time the overlay draws it is `1340x800`.

**How to apply:**
- Default to native (`1.0f`) on Android in both `config_def.h` and `ApplyLowEndDefaults`.
  `ApplyLowEndDefaults` runs *after* `ApplyMaliRuntimeOverrides`, so leaving 0.25f there
  re-applies the upscale on a fresh install and undoes the Mali override.
- Only clamp values above 1.0; never downgrade a value the user saved.
- Before treating a "geometry/texture corruption" report as a driver or renderer bug, read
  `resolutionScale=` in the log. If it is well below 1.0, fix that first — it is cheaper than
  a renderer investigation and it changes what the corruption even looks like.
- `Config::ResolutionScale.Callback` clamps to [0.25, 2.0] and
  `VideoConfigValueChangedCallback` sets `g_needsResize`, so the Options change applies live.
