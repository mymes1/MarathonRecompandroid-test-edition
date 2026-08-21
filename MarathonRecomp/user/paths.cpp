#include "paths.h"
#include <os/process.h>
#ifdef __ANDROID__
#include <os/android/storage_android.h>
#endif

std::filesystem::path g_executableRoot = os::process::GetExecutableRoot();

bool CheckPortable()
{
    return std::filesystem::exists(g_executableRoot / "portable.txt");
}

std::filesystem::path BuildUserPath()
{
    if (CheckPortable())
        return g_executableRoot;

    std::filesystem::path userPath;

#if defined(_WIN32)
    PWSTR knownPath = NULL;
    if (SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, NULL, &knownPath) == S_OK)
        userPath = std::filesystem::path{ knownPath } / USER_DIRECTORY;

    CoTaskMemFree(knownPath);
#elif defined(__ANDROID__)
    // No meaningful $HOME/passwd entry for an app UID; getpwuid()->pw_dir returns a
    // generic path apps can't write to. Keep config/saves next to the game files
    // (legacy internal install or external app storage, whichever GetDataRoot picked).
    {
        std::error_code ec;
        std::filesystem::path base = os::android::GetDataRoot();
        userPath = base / ".config" / USER_DIRECTORY;
        std::filesystem::create_directories(userPath, ec);
        // Also create the save subdirectory so SaveData writes succeed on first run.
        std::filesystem::create_directories(userPath / "save", ec);
        // Mirror the writable-probe that GetDataRoot already performs so we never
        // end up with a poisoned directory on devices like the SM-X110.
        if (!os::android::ProbeDirWritable(userPath))
        {
            // Fall back to the external files root itself (already proven writable).
            userPath = base;
            std::filesystem::create_directories(userPath / "save", ec);
        }
    }
#elif defined(__linux__) || defined(__APPLE__)
    const char* homeDir = getenv("HOME");
#if defined(__linux__)
    if (homeDir == nullptr)
    {
        homeDir = getpwuid(getuid())->pw_dir;
    }
#endif

    if (homeDir != nullptr)
    {
        // Prefer to store in the .config directory if it exists. Use the home directory otherwise.
        std::filesystem::path homePath = homeDir;
#if defined(__linux__)
        std::filesystem::path configPath = homePath / ".config";
#else
        std::filesystem::path configPath = homePath / "Library" / "Application Support";
#endif
        if (std::filesystem::exists(configPath))
            userPath = configPath / USER_DIRECTORY;
        else
            userPath = homePath / ("." USER_DIRECTORY);
    }
#else
    static_assert(false, "GetUserPath() not implemented for this platform.");
#endif

    return userPath;
}

const std::filesystem::path& GetUserPath()
{
    // Lazy: on Android the path is resolved through SDL/JNI, which isn't available
    // yet when static initializers of this library run.
    static std::filesystem::path userPath = BuildUserPath();
    return userPath;
}
