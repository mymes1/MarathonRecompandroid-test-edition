Optional bundled Vulkan drivers (Adreno-only Mesa Turnip builds, named exactly as
in MarathonRecomp/os/android/vulkan_driver_android.cpp):

  vulkan.marathon_a732.so                      (default; Adreno 732-class)
  vulkan.vauzi710_v2_7.so                      (Adreno 710, Vauzi v2.7)
  vulkan.wb26_2_rp_pair_ccu_color_a725.so      (Adreno 725 experimental)

These are community-built driver binaries and are NOT committed to this repository.
If the folder is empty the launcher falls back to the system Vulkan driver, and
drivers can still be imported at runtime from the launcher (Import .so / .zip).
