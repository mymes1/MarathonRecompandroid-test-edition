---
name: SM-X110 Android 15 renderer audit 2026-08-23
description: Findings from the follow-up whole-tree compatibility audit after the 1.0.4 device log showed invisible touch controls, corrupted geometry, and dead Vulkan texture wrappers.
---

## Evidence from device log

- Build 1.0.4 reaches gameplay and no longer terminates with `std::bad_alloc`; ETC2/EAC removed the RGBA memory blow-up.
- Touch hit testing works while controls are invisible, isolating the control issue to render state rather than SDL/Java input.
- `Ignoring Vulkan texture barrier for a dead wrapper` appears while CSD/gameplay resources are replaced, proving stale native texture references still reach barrier assembly.
- CSD resource names remain readable, so the old o1heap fragment-header corruption is not recurring.

## Fixed findings

1. **Touch controls inherited persistent ImGui shader state.** Gradient, additive, origin, scale, outline, and procedural-origin callbacks mutate persistent push constants. Controls are in the foreground list and could inherit a transparent gradient/modifier from earlier UI while hit testing remained correct. Publish a complete neutral callback state immediately before `ImGui::Render` on Android.
2. **Mali vertex conversion used the stream offset as an endian boundary.** Xbox buffers are 32-bit big-endian lanes beginning at byte zero, as used by the established desktop path. Starting conversion at a non-word-aligned stream offset rotates all subsequent lanes. Convert the complete buffer and apply the stream offset only when binding.
3. **Patched controller textures were destroyed without reference cleanup.** The parent cleanup removed barriers/bindings only for the parent, then `unique_ptr` destroyed the separately bindable patched wrapper. Remove patched texture references before destruction.
4. **Resource retirement accepted duplicate destruction commands.** Releases can be produced by multiple guest threads, while the old frame-retirement vectors had no uniqueness guard. Double destruction corrupts the guest heap and leaves arbitrary native pointers in barrier state. Track scheduled resources on the render thread through final free.
5. **Texture stage indexing was unchecked.** A stage >= 16 wrote beyond `g_textures` and shared constants, corrupting adjacent render state. Validate on producer and consumer sides.
6. **Pixel constant dirty ranges could underflow.** Dirty bits above the renderer's 56 pixel groups made `(end-start)` negative and then unsigned, creating a huge command allocation. Ignore non-renderer dirty bits and runtime-check copied constant ranges in release builds.
7. **Shader constant begin ranges were unchecked.** Zero counts underflowed and oversized ranges formed invalid pointers/shifts. Validate the full range before exposing it to the guest.

## Durable contracts

- A stream offset is a binding offset, not an endian-conversion origin.
- Every nested native texture wrapper needs the same barrier/binding cleanup as a top-level guest texture.
- Assertions are not release-build memory safety. Validate every guest-controlled index/range before array access or allocation.
- Android foreground overlays must establish all persistent custom ImGui renderer state explicitly.
