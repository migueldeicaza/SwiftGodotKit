#include "apple_plugin_stubs.h"

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
__attribute__((weak)) void godot_apple_embedded_plugins_initialize() {}
__attribute__((weak)) void godot_apple_embedded_plugins_deinitialize() {}
#endif
