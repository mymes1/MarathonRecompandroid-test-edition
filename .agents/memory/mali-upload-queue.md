---
name: Mali upload queue ownership
description: Queue-synchronization constraint for staged vertex and index uploads on Samsung Mali-G57 Android devices.
---

When Mali compatibility disables host-visible device-local upload memory, staged vertex/index buffer copies must execute on the graphics command list or use an explicit queue-ownership handoff before graphics consumption.

**Why:** A copy submitted on a separate transfer queue can race the graphics queue when the renderer has no ownership-transfer semaphore/barrier path. The resulting stale or partially visible geometry corrupts 3D draws while 2D UI remains intact.

**How to apply:** Keep staged geometry copies on the graphics list and place a COPY-to-GRAPHICS buffer barrier before vertex fetch/index reads, unless a complete transfer-queue synchronization contract is implemented.