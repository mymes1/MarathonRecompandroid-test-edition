Copy the freshly built libmain.so here before assembling the APK:

  cp out/build/android-arm64/MarathonRecomp/libmain.so \
     android-apk/app/src/main/jniLibs/arm64-v8a/libmain.so

(or run ../build_apk.sh, which does this automatically).
