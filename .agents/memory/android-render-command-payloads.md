---
name: Android render command payload lifetime
description: Render commands carrying copied guest constants or DrawPrimitiveUP vertices must own their payload memory.
---

Do not store render-command payload pointers in a frame-reused global scratch allocator on Android. Startup/loading can enqueue rendering work from multiple guest threads while `Present()` is rotating frame state, so scratch reuse can overwrite queued shader constants or DrawPrimitiveUP vertices before the render thread consumes them.

**Why:** Corrupted command payloads present as large stretched triangles/black or white wedges while ImGui/touch controls remain correct, especially on SM-X110 Mali during title/menu/loading transitions.

**How to apply:** Copy guest constants and DrawPrimitiveUP vertex data into per-command owned memory and release it in the render-thread command handler after copying into renderer state/GPU upload buffers. Avoid resetting/reusing that memory at frame boundaries.
