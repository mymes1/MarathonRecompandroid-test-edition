---
name: Mali command-buffer boundaries
description: Android Mali upload recording must not cross a Present/BeginCommandList boundary.
---

Mali texture and texture-lock upload commands must only record while the graphics command buffer is open. A concurrent producer can enqueue an upload after `ExecuteCommandList` closes the current buffer but before the next `BeginCommandList` is dequeued; defer that command on the render thread and replay it after begin.

**Why:** The SM-X110 Mali driver can SIGSEGV inside `vkCmdPipelineBarrier` instead of reporting an invalid command-buffer recording state.

**How to apply:** Treat the bootstrap command list as open while it remains unsubmitted, and keep upload handlers guarded by the render command-list state across every Present transition.