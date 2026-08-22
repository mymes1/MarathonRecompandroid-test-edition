#include <os/registry.h>

// Android has no Windows registry / desktop config store; all settings live in
// config.toml (user/config.cpp). These stubs keep the shared code linking.
inline bool os::registry::Init()
{
    // Android intentionally uses config.toml instead of a platform registry.
    // Treat that no-op backend as successfully initialized so startup does not
    // report a misleading compatibility warning on every launch.
    return true;
}

template<typename T>
bool os::registry::ReadValue(const std::string_view& name, T& data)
{
    return false;
}

template<typename T>
bool os::registry::WriteValue(const std::string_view& name, const T& data)
{
    return false;
}
