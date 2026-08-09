---
name: Mali upload queue ownership
description: Queue-synchronization constraint for staged vertex and index uploads on Samsung Mali-G57 Android devices.
---

When Mali compatibility disables host-visible device-local upload memory, staged vertex/index buffer copies must execute on the graphics command list or use an explicit queue-ownership handoff before graphics consumption. Guest-thread unlock hooks must enqueue the upload work onto the render thread rather than recording against its active command list directly.

**Why:** A copy submitted on a separate transfer queue can race the graphics queue when the renderer has no ownership-transfer semaphore/barrier path. Recording a staged copy directly from a guest thread can also race the render thread's command recording. Either race produces stale or partially visible geometry that corrupts 3D draws while 2D UI remains intact.

**How to apply:** Keep staged geometry copies on the graphics list, place a COPY-to-GRAPHICS buffer barrier before vertex fetch/index reads, and route guest-facing unlock callbacks through the render command queue, unless a complete cross-thread/queue synchronization contract is implemented.