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

## Touch controls — structural cause and fix

The device log proves the overlay is emitted (`viewport`, `window` and `imguiDisplay` all
1340x800), so it is not layout, clipping, or a degenerate rect. The structural weakness is
that **every renderer-modifier callback is emitted into `ImGui::GetBackgroundDrawList()`
while the touch controls live in `ImGui::GetForegroundDrawList()`**.

Modifiers (gradient, shader modifier, origin, scale, outline, procedural origin, additive)
are *persistent push constants* consumed when a draw list is replayed, and
`ProcDrawImGui` only re-uploads a range when its bytes change. The previous Android fix
published a neutral state at the *end of the background list*, which relies on nothing
between that list and the foreground list touching the state — an invariant no code
enforces. Two concrete ways it breaks: a stale transparent gradient multiplies every pixel
by zero, and a stale `Scale` of 0 collapses every vertex via
`Origin + (position - Origin) * Scale`. Both leave CPU-side hit testing perfectly correct
while all primitives disappear — the reported "controls are hidden but work".

**Fix:** `AddImGuiCallbackTo(ImDrawList*, ImGuiCallback)` emits a callback into an arbitrary
list, and `PushNeutralImGuiState(ImDrawList*)` publishes the complete neutral set.
`TouchControls::Draw()` calls it on the foreground list *before* any of its own geometry, so
the guarantee is local to the list instead of inherited across lists. The pre-`ImGui::Render`
reset now uses the same helper (no longer Android-gated; the invariant holds on every
backend).

Verified by compiling the real `imgui_common.cpp` and the real `PushNeutralImGuiState` body
against stubbed ImGui types: 7 callbacks emitted in order, gradient zeroed (all 32 bytes,
`boundsMin == boundsMax` so the shader's `any(BoundsMin != BoundsMax)` test skips the
multiply), `scale == (1,1)`, modifier NONE, outline 0, procedural origin 0, additive off;
`AddImGuiCallback` still targets the background list; slots still reuse across frames;
`AddImGuiCallbackTo(nullptr)` returns null.

`ProcDrawImGui` also logs a one-shot draw-list inventory
(`[imgui] drawList[i/n] vtx= idx= cmds=`, last entry being the foreground list). If the
controls are *still* invisible after this fix, that line tells us whether the foreground
list reaches the renderer at all.

### Preprocessor hazard

`DrawImGui()` has two adjacent `#ifdef __ANDROID__` blocks around `TouchControls::Draw()`
and the modifier reset. Removing the reset's `#endif` while editing silently swallows the
rest of the function on non-Android builds. Check `#if`/`#endif` depth after editing here.

## Method note

A clean `log.txt` is not evidence of health on this device family: both the Mali workarounds
and the validation that would warn about bad draws are gated on `g_isMali`, and a large
visual defect (resolution scale) is pure configuration that logs nothing. Read
`maliProfile=` and `resolutionScale=` before investigating the renderer.
