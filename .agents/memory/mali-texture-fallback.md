---
name: Mali texture fallback
description: Texture color-management constraint for BC fallback on Samsung Mali-G57 Android devices.
---

When BC textures are CPU-decoded to RGBA8 on Mali-G57, the fallback texture must retain sRGB sampling semantics whenever the source DDS format is sRGB.

**Why:** Treating decoded sRGB bytes as a linear UNORM texture bypasses the GPU's sRGB-to-linear conversion and can make materials look incorrectly bright or glossy.

**How to apply:** Preserve the source color-space flag through BC1/2/3/7 fallback selection and map the resulting RGBA8 sRGB format to the backend's native sRGB image format.