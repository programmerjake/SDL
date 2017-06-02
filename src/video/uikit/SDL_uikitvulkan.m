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
#include "../../SDL_internal.h"

#if SDL_VIDEO_VULKAN_SURFACE && SDL_VIDEO_DRIVER_UIKIT

#include "SDL_uikitvideo.h"
#include "SDL_uikitwindow.h"
#include "SDL_assert.h"

#include "SDL_loadso.h"
#include "SDL_uikitvulkan.h"
#include "SDL_uikitmetalview.h"
#include "SDL_syswm.h"

#include <dlfcn.h>

int UIKit_Vulkan_LoadLibrary(_THIS, const char *path)
{
    VkExtensionProperties *extensions = NULL;
    Uint32 extensionCount = 0;
    SDL_bool hasSurfaceExtension = SDL_FALSE;
    SDL_bool hasIOSSurfaceExtension = SDL_FALSE;
    PFN_vkGetInstanceProcAddr vkGetInstanceProcAddr = NULL;

    if(_this->vulkan_config.loader_handle)
        return SDL_SetError("MoltenVK/Vulkan already loaded");

    /* There is no shared MoltenVK/Vulkan dylib on iOS. It is statically
     * linked to the app.
     */
    if (path != NULL)
    {
        return SDL_SetError("iOS Vulkan Load Library just here for compatibility");
    }

    _this->vulkan_config.loader_handle = RTLD_SELF;

    vkGetInstanceProcAddr =
        (PFN_vkGetInstanceProcAddr)dlsym(RTLD_SELF, "vkGetInstanceProcAddr");

    if(!vkGetInstanceProcAddr)
    {
        SDL_SetError("Failed loading %s: %s", "vkGetInstanceProcAddr",
                     (const char *) dlerror());
        goto fail;
    }

    _this->vulkan_config.vkGetInstanceProcAddr = (void *)vkGetInstanceProcAddr;
    _this->vulkan_config.vkEnumerateInstanceExtensionProperties =
        (void *)((PFN_vkGetInstanceProcAddr)_this->vulkan_config.vkGetInstanceProcAddr)(
            VK_NULL_HANDLE, "vkEnumerateInstanceExtensionProperties");
    if(!_this->vulkan_config.vkEnumerateInstanceExtensionProperties)
    {
        SDL_SetError("No vkEnumerateInstanceExtensionProperties found.");
        goto fail;
    }
    extensions = SDL_Vulkan_CreateInstanceExtensionsList(
        (PFN_vkEnumerateInstanceExtensionProperties)
            _this->vulkan_config.vkEnumerateInstanceExtensionProperties,
        &extensionCount);
    if(!extensions)
        goto fail;
    for(Uint32 i = 0; i < extensionCount; i++)
    {
        if(SDL_strcmp(VK_KHR_SURFACE_EXTENSION_NAME, extensions[i].extensionName) == 0)
            hasSurfaceExtension = SDL_TRUE;
        else if(SDL_strcmp(VK_MVK_IOS_SURFACE_EXTENSION_NAME, extensions[i].extensionName) == 0)
            hasIOSSurfaceExtension = SDL_TRUE;
    }
    SDL_free(extensions);
    if(!hasSurfaceExtension)
    {
        SDL_SetError("Installed MoltenVK/Vulkan doesn't implement the "
                     VK_KHR_SURFACE_EXTENSION_NAME " extension");
        goto fail;
    }
    else if(!hasIOSSurfaceExtension)
    {
        SDL_SetError("Installed MoltenVK/Vulkan doesn't implement the "
                     VK_MVK_IOS_SURFACE_EXTENSION_NAME "extension");
        goto fail;
    }
    if (UIKit_Mtl_LoadLibrary(NULL) < 0)
        goto fail;

    return 0;

fail:
    _this->vulkan_config.loader_handle = NULL;
    return -1;
}

void UIKit_Vulkan_UnloadLibrary(_THIS)
{
    if(_this->vulkan_config.loader_handle)
    {
        _this->vulkan_config.loader_handle = NULL;
        UIKit_Mtl_UnloadLibrary();
    }
}

SDL_bool UIKit_Vulkan_GetInstanceExtensions(_THIS,
                                          SDL_Window *window,
                                          unsigned *count,
                                          const char **names)
{
    static const char *const extensionsForUIKit[] = {
        VK_KHR_SURFACE_EXTENSION_NAME, VK_MVK_IOS_SURFACE_EXTENSION_NAME
    };
    if(!_this->vulkan_config.loader_handle)
    {
        SDL_SetError("Vulkan is not loaded");
        return SDL_FALSE;
    }
    return SDL_Vulkan_GetInstanceExtensions_Helper(
            count, names, SDL_arraysize(extensionsForUIKit),
            extensionsForUIKit);
}

SDL_bool UIKit_Vulkan_CreateSurface(_THIS,
                                  SDL_Window *window,
                                  VkInstance instance,
                                  VkSurfaceKHR *surface)
{
    PFN_vkGetInstanceProcAddr vkGetInstanceProcAddr =
        (PFN_vkGetInstanceProcAddr)_this->vulkan_config.vkGetInstanceProcAddr;
    PFN_vkCreateIOSSurfaceMVK vkCreateIOSSurfaceMVK =
        (PFN_vkCreateIOSSurfaceMVK)vkGetInstanceProcAddr(
                                            (VkInstance)instance,
                                            "vkCreateIOSSurfaceMVK");
    VkIOSSurfaceCreateInfoMVK createInfo = {};
    VkResult result;

    if(!_this->vulkan_config.loader_handle)
    {
        SDL_SetError("Vulkan is not loaded");
        return SDL_FALSE;
    }

    if(!vkCreateIOSSurfaceMVK)
    {
        SDL_SetError(VK_MVK_IOS_SURFACE_EXTENSION_NAME
                     " extension is not enabled in the Vulkan instance.");
        return SDL_FALSE;
    }
    createInfo.sType = VK_STRUCTURE_TYPE_IOS_SURFACE_CREATE_INFO_MVK;
    createInfo.pNext = NULL;
    createInfo.flags = 0;
    createInfo.pView = (__bridge void *)UIKit_Mtl_AddMetalView(window);
    result = vkCreateIOSSurfaceMVK(instance, &createInfo,
                                       NULL, surface);
    if(result != VK_SUCCESS)
    {
        SDL_SetError("vkCreateIOSSurfaceMVK failed: %s",
                     SDL_Vulkan_GetResultString(result));
        return SDL_FALSE;
    }
    return SDL_TRUE;
}

void UIKit_Vulkan_GetDrawableSize(_THIS, SDL_Window *window, int *w, int *h)
{
    UIKit_Mtl_GetDrawableSize(window, w, h);
}

#endif

/* vi: set ts=4 sw=4 expandtab: */
