/**************************************************************************/
/*  libgodot.h                                                            */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Keep libgodot's C bridge types namespaced to avoid clashes with the
// GDExtension module that SwiftGodot imports.
typedef void *LGDExtensionObjectPtr;
typedef uint8_t LGDExtensionBool;
typedef void (*LGDExtensionInterfaceFunctionPtr)(void);
typedef LGDExtensionInterfaceFunctionPtr (*LGDExtensionInterfaceGetProcAddress)(const char *p_function_name);
typedef void *LGDExtensionClassLibraryPtr;
typedef struct LGDExtensionInitialization LGDExtensionInitialization;
typedef LGDExtensionBool (*LGDExtensionInitializationFunction)(LGDExtensionInterfaceGetProcAddress p_get_proc_address, LGDExtensionClassLibraryPtr p_library, LGDExtensionInitialization *r_initialization);

// Export macros for DLL visibility
#if defined(_MSC_VER) || defined(__MINGW32__)
#define LIBGODOT_API __declspec(dllexport)
#elif defined(__GNUC__) || defined(__clang__)
#define LIBGODOT_API __attribute__((visibility("default")))
#endif // if defined(_MSC_VER)

/**
 * @name libgodot_create_godot_instance
 * @since 4.6
 *
 * Creates a new Godot instance.
 *
 * @param p_argc The number of command line arguments.
 * @param p_argv The C-style array of command line arguments.
 * @param p_init_func GDExtension initialization function of the host application.
 *
 * @return A pointer to created \ref GodotInstance GDExtension object or nullptr if there was an error.
 */
LIBGODOT_API LGDExtensionObjectPtr libgodot_create_godot_instance(int p_argc, char *p_argv[], LGDExtensionInitializationFunction p_init_func);

/**
 * @name libgodot_destroy_godot_instance
 * @since 4.6
 *
 * Destroys an existing Godot instance.
 *
 * @param p_godot_instance The reference to the GodotInstance object to destroy.
 *
 */
LIBGODOT_API void libgodot_destroy_godot_instance(LGDExtensionObjectPtr p_godot_instance);

/**
 * Creates an iOS rendering layer for a libgodot host.
 *
 * Call this function on the main thread. The returned Objective-C object has a
 * +1 retain count. Consume it with `__bridge_transfer` in Objective-C ARC,
 * `takeRetainedValue()` in Swift, or an equivalent ownership transfer. Keep
 * the layer alive until the Godot instance and its native surface are gone.
 */
LIBGODOT_API void *libgodot_ios_create_rendering_layer(const char *p_rendering_driver);

/**
 * Initializes an iOS rendering layer after the host adds it to its view.
 * Call this function on the main thread before the Godot instance starts.
 */
LIBGODOT_API void libgodot_ios_initialize_rendering_layer(void *p_rendering_layer);

/** Updates an iOS rendering layer on the main thread after its bounds change. */
LIBGODOT_API void libgodot_ios_layout_rendering_layer(void *p_rendering_layer);

/**
 * Makes an iOS rendering layer current before a Godot iteration. Call this and
 * the matching stop function on the same thread that performs the iteration.
 */
LIBGODOT_API void libgodot_ios_start_rendering_layer(void *p_rendering_layer);

/** Presents an iOS rendering layer after a Godot iteration. */
LIBGODOT_API void libgodot_ios_stop_rendering_layer(void *p_rendering_layer);

#ifdef __cplusplus
}
#endif
