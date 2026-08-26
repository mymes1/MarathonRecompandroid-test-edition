---
name: SM-X110 Android 15 compatibility audit 2026-08-26
description: Whole-tree compatibility audit for Galaxy Tab A9 Wi-Fi. Records what was fixed, what was verified correct, and which plausible theories the device log or the code ruled OUT.
---

## Device

SM-X110 (Galaxy Tab A9 Wi-Fi), MT8781V/NA, Mali-G57 MC2, Android 15 / SDK 35, arm64-v8a,
3740 MB RAM. Confirmed from device log: Vulkan device name `Mali-G57 MC2`,
`ro.product.device=gta9wifi`, `ro.hardware.vulkan=mali`, `ro.hardware.egl=meow`,
`ro.board.platform=mt6789`.

## Fixed in this audit

1. **Resolution scale was the dominant visual defect.** `ApplyMaliRuntimeOverrides` forced
   any scale above 0.5 back down to 0.25 every launch, and the Android default was 0.25.
   `SetResolution` computes `round(viewport * scale)`, so the 3D scene rendered at 335x200
   and was upscaled 4x across a 1340x800 panel. That is visually indistinguishable from
   geometry/texture corruption while every renderer diagnostic stays clean. Now native
   (1.0) by default, clamped only above 1.0, and a saved value is never downgraded.
   See [android-resolution-scale-lookalike](android-resolution-scale-lookalike.md).
2. **Guest vertex-declaration out-of-bounds.** `GuestVertexElement::stream` is
   `be<uint16_t>` (0..65535) but indexed fixed-size 16-entry arrays (`vertexStreams`,
   `inputSlotIndices`, `inputSlots`, `vertexStrides`). Only 0xFF terminates the list.
   Validated on the producer and consumer sides.
3. **Unmapped guest vertex types.** `ConvertDeclType` only asserts, so a release build fed
   `RenderFormat::UNKNOWN` into a Vulkan vertex input attribute — undefined fetch behaviour
   on Mali, not a validation error. Such elements are now skipped with a warning.
4. **ImGui index width assumption.** `ProcDrawImGui` hardcoded `sizeof(uint16_t)` and
   `R16_UINT` for `ImDrawIdx`, which is compile-time configurable. Now derived from
   `sizeof(ImDrawIdx)` with a `static_assert`, so widening it cannot silently corrupt every
   overlay draw.

## Verified correct — do not re-investigate

- **Mali detection engages.** `maliProfile=ENABLED`; all workarounds live. Detection also
  extended to `ro.hardware.vulkan/egl/gralloc` and `ro.soc.model` as fallbacks.
- **Guest heap corruption is not recurring.** The documented canary is garbage in
  `CSD loaded:` lines; the device log shows clean ASCII names
  (`sprite/loading/loading_english`, `sprite/main_menu`, `sprite/goldmedal/goldmedal`).
- **Vertex stream strides** are full `uint32_t` end to end; no narrowing.
- **Vertex endian conversion** starts at buffer byte zero; the stream offset is applied only
  when binding (`UploadMaliGuestVertexBuffer` / `GetMaliVertexReference`).
- **Upload alignments** resolve correctly on Mali: `g_uploadPitchAlignment = 1` makes the
  align-up expressions identity, giving the intended tight row packing.
- **`ImGuiPushConstants` matches the HLSL `PushConstants`** field for field; NSDMIs give
  `scale = (1,1)`, so the vertex shader's origin/scale transform is identity by default.
- **`setGraphicsPushConstants(rangeIndex, data, offset=0, size=0)`** uploads the *whole*
  range (`plume_vulkan.cpp`: `size == 0 ? range.size : size`). The initial full-struct
  upload is therefore correct — this is NOT the cause of the invisible overlay.
- **`UploadMaliGuestVertexBuffer`'s `stream` index** is already bounded by
  `GetMaliVertexReference`, which checks `stream >= std::size(g_vertexBuffers)`.
- **`vertexStreamFirst/Last` dirty range** initialises to (255, 0) so an unset range fails
  the `first <= last` test rather than binding slot 0.
- **Cutscene collapse no longer hides the controls.** The adaptive layout only ever selects
  `Normal` or `Menu`; the movie/cutscene one-button collapse was deliberately removed.
- **Touch-control drawing and hit testing share radii** (`DrawFaceButton` uses `r * 1.25`
  to draw and `r * 1.3` to test), so degenerate geometry would break input too — and input
  works. The layout is not degenerate.

## Still open

**Touch controls are emitted but invisible.** The device log proves emission:
`[touch] drawing overlay: viewport=1340x800 window=1340x800 imguiDisplay=1340x800
edit=false policy=0` — all three coordinate spaces agree, so it is not layout, clipping, or
a degenerate rect. `ProcDrawImGui` now logs a one-shot inventory
(`[imgui] drawList[i/n] vtx= idx= cmds=`, last entry is the foreground list) to separate
"ImGui never delivers the foreground list" from "the GPU discards its draws".

## Method note

A clean `log.txt` is not evidence of health on this device family: both the Mali workarounds
and the validation that would warn about bad draws are gated on `g_isMali`, and a large
visual defect (resolution scale) is pure configuration that logs nothing. Read
`maliProfile=` and `resolutionScale=` before investigating the renderer.
