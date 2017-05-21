/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2016 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/
#ifndef _SDL_vulkan_internal_h
#define _SDL_vulkan_internal_h

#include "../SDL_internal.h"
#include "SDL_stdinc.h"

// Android does not support Vulkan in native code using the "armeabi" ABI.
#if defined(__ANDROID__) && defined(__ARM_EABI__) && !defined(__ARM_ARCH_7A__)
#define SDL_VULKAN_SUPPORTED 0
#elif !(HAVE_STDDEF_H || HAVE_LIBC) || defined(SDL_LOADSO_DISABLED)
#define SDL_VULKAN_SUPPORTED 0
#else
#define SDL_VULKAN_SUPPORTED 1
#endif

#if SDL_VIDEO_DRIVER_ANDROID
#define VK_USE_PLATFORM_ANDROID_KHR
#include <android/native_window.h>
#endif
#if SDL_VIDEO_DRIVER_MIR
#define VK_USE_PLATFORM_MIR_KHR
#include <mir_toolkit/client_types.h>
#endif
#if SDL_VIDEO_DRIVER_WAYLAND
#define VK_USE_PLATFORM_WAYLAND_KHR
#include <wayland-client.h>
#endif
#if SDL_VIDEO_DRIVER_WINDOWS
#define VK_USE_PLATFORM_WIN32_KHR
#include <windows.h>
#endif
#if SDL_VIDEO_DRIVER_X11
#define VK_USE_PLATFORM_XLIB_KHR
#define VK_USE_PLATFORM_XCB_KHR
#include <X11/Xlib.h>
//#include <xcb/xcb.h>
typedef struct xcb_connection_t xcb_connection_t;
typedef uint32_t xcb_window_t;
typedef uint32_t xcb_visualid_t;
typedef xcb_connection_t *(*PFN_XGetXCBConnection)(Display *dpy);
#endif

#if SDL_VULKAN_SUPPORTED
#define VK_NO_PROTOTYPES
#include "vulkan/vulkan.h"
#endif

#endif
/* vi: set ts=4 sw=4 expandtab: */
