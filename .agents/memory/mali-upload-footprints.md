---
name: Mali upload footprints
description: Vulkan buffer-to-image copy rules for compressed textures converted on Samsung Mali-G57 Android devices.
---

For buffer-to-image uploads, calculate row and slice metadata from the upload footprint's format, not only from the destination image format. This is required when BC textures are decoded to RGBA8 or transcoded to ETC2/EAC.

**Why:** The source footprint and destination image can have different block geometry. Using destination geometry for `bufferRowLength` or `bufferImageHeight` makes Mali-G57 advance through rows and slices incorrectly, producing stretched or morphing textures.

**How to apply:** Keep the footprint format explicit, provide both block width and block height, and use zero Vulkan row/image lengths only when the footprint is genuinely tightly packed.