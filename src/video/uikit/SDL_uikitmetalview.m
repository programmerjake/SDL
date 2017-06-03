/*
 Simple DirectMedia Layer
 Copyright (C) 2017, Mark Callow.
 
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

/*
 * Thanks to Alex Szpakowski, @slime73 on GitHub, for his gist showing
 * how to add a CAMetalLayer backed view.
 */

#include "../../SDL_internal.h"

#if SDL_VIDEO_VULKAN_SURFACE && SDL_VIDEO_DRIVER_UIKIT

#import "../SDL_sysvideo.h"
#import "SDL_uikitwindow.h"
#import "SDL_uikitmetalview.h"

#include "SDL_assert.h"
#include "SDL_loadso.h"
#include <dlfcn.h>

typedef id <MTLDevice> __nullable (*PFN_MTLCreateSystemDefaultDevice)(void);
static PFN_MTLCreateSystemDefaultDevice MtlCreateSystemDefaultDevice;

static void* loader_handle;

@implementation SDL_uikitmetalview

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
                        scale:(CGFloat)scale
                          tag:(int)tag
{
    if ((self = [super initWithFrame:frame])) {
        /* Resize properly when rotated. */
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        _metalLayer = (CAMetalLayer *) self.layer;
        _metalLayer.opaque = YES;
        _metalLayer.device = MtlCreateSystemDefaultDevice();

        /* Set the appropriate scale (for retina display support) */
        self.contentScaleFactor = scale;
        self.tag = tag;

        [self updateDrawableSize];
    }

    return self;
}

/* Set the size of the metal drawables when the view is resized. */
- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateDrawableSize];
}

- (void)updateDrawableSize
{
    CGSize size  = self.bounds.size;
    size.width  *= self.contentScaleFactor;
    size.height *= self.contentScaleFactor;

    _metalLayer.drawableSize = size;
}

@end

int UIKit_Mtl_LoadLibrary(const char *path)
{
    if (MtlCreateSystemDefaultDevice) {
        SDL_SetError("Metal already loaded.");
        return -1;
    }
    loader_handle = SDL_LoadObject("Metal.framework/Metal");
    if (!loader_handle)
        return -1;        
    MtlCreateSystemDefaultDevice =
            SDL_LoadFunction(loader_handle, "MTLCreateSystemDefaultDevice");
    if (!MtlCreateSystemDefaultDevice) {
        UIKit_Mtl_UnloadLibrary();
        return -1;
    }
    return 0;
}

void UIKit_Mtl_UnloadLibrary()
{
    if (loader_handle) {
        SDL_UnloadObject(loader_handle);
        loader_handle = NULL;
    }
}

SDL_uikitmetalview*
UIKit_Mtl_AddMetalView(SDL_Window* window)
{
    SDL_WindowData *data = (__bridge SDL_WindowData *)window->driverdata;
    SDL_uikitview *view = (SDL_uikitview*)data.uiwindow.rootViewController.view;
    CGFloat scale = 1.0;
    
    SDL_assert(loader_handle != 0 && MtlCreateSystemDefaultDevice != 0);
    
    if (window->flags & SDL_WINDOW_ALLOW_HIGHDPI) {
        /* Set the scale to the natural scale factor of the screen - the
         * backing dimensions of the Metal view will match the pixel
         * dimensions of the screen rather than the dimensions in points.
         */
#ifdef __IPHONE_8_0
        if ([data.uiwindow.screen respondsToSelector:@selector(nativeScale)]) {
            scale = data.uiwindow.screen.nativeScale;
        } else
#endif
        {
            scale = data.uiwindow.screen.scale;
        }
    }
    SDL_uikitmetalview *metalview
         = [[SDL_uikitmetalview alloc] initWithFrame:view.frame
                                          scale:scale
                                            tag:METALVIEW_TAG];
#if 1
    [view addSubview:metalview];
#else
    /* Sets this view as the controller's view, and adds the view to
     * the window hierarchy.
     *
     * Left here for information. Not used because I suspect that for correct
     * operation it will be necesary to copy everything from the window's
     * current SDL_uikitview instance to the SDL_uikitview portion of the
     * SDL_metalview. The latter would be derived from SDL_uikitview rather
     * than UIView. */
    [metalview setSDLWindow:window];
#endif

    return metalview;
}

void
UIKit_Mtl_GetDrawableSize(SDL_Window * window, int * w, int * h)
{
    SDL_WindowData *data = (__bridge SDL_WindowData *)window->driverdata;
    SDL_uikitview *view = (SDL_uikitview*)data.uiwindow.rootViewController.view;
    SDL_uikitmetalview* metalview = [view viewWithTag:METALVIEW_TAG];
    if (metalview) {
        CAMetalLayer *layer = (CAMetalLayer*)metalview.layer;
        assert(layer != NULL);
        // XXX Something is setting drawable size back to the size in points.
        // Possiby a bug in MoltenVK. May need to * metalview.contentScaleFactor
        if (w)
            *w = layer.drawableSize.width;
        if (h)
            *h = layer.drawableSize.height;
    } else
        SDL_GetWindowSize(window, w, h);
}

#endif
