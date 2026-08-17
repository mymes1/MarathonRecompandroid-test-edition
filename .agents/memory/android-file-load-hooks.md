---
name: Android file-load hooks
description: Safety rule for diagnostic hooks around the game's guest file objects on Android.
---

The file object's `Length` field describes file data, not the NUL-terminated path string. A diagnostic hook must not use it to format or scan `pFilePath`; the hook should avoid reading the path unless its allocation length is independently known and validated.

**Why:** On Android 15 with fortified libc, an invalid or stale guest path read caused a stack-protector abort while loading character resources, before the underlying file routine completed.

**How to apply:** Keep file-load tracing disabled or use a separately validated path representation. Never pass the raw guest path pointer to `fmt` as a C string in this hook.