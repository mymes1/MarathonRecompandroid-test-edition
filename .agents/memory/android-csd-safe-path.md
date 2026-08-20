---
name: Android Mali CSD safe path
description: Avoid aspect-ratio CSD vertex rewriting on SM-X110/Mali.
---

On Samsung Tab A9 / Mali-G57 Android 15, the CSD aspect-ratio draw hook should prefer the original CSD draw path instead of copying and rewriting CSD vertices on the guest stack.

**Why:** UI/loading/menu CSD payload corruption presents as huge black/white/textured wedges across the screen while touch/ImGui overlays remain correct.

**How to apply:** Detect SM-X11x or Mali/meow Android properties in `aspect_ratio_patches.cpp` and call the original CSD draw functions directly on that device family. Keep the safer CSD hierarchy cache validation in place for modifier lookup, but avoid the per-draw vertex rewrite path.
