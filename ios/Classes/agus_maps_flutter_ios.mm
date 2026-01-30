/// agus_maps_flutter_ios.mm
/// 
/// iOS FFI implementation for agus_maps_flutter.
/// This provides the C FFI functions that Dart FFI calls on iOS.
/// 
/// This file implements the full CoMaps Framework integration for iOS,
/// using Metal for rendering via CVPixelBuffer/IOSurface zero-copy texture sharing.

#include "../src/agus_maps_flutter.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

#include <string>
#include <memory>
#include <atomic>
#include <chrono>
#include <sstream>

// CoMaps Framework includes
#include "base/logging.hpp"
#include "map/framework.hpp"
#include "map/gps_tracker.hpp"
#include "map/place_page_info.hpp"
#include "map/routing_manager.hpp"
#include "map/routing_mark.hpp"
#include "platform/local_country_file.hpp"
#include "platform/location.hpp"
#include "drape/graphics_context_factory.hpp"
#include "drape_frontend/visual_params.hpp"
#include "drape_frontend/user_event_stream.hpp"
#include "drape_frontend/active_frame_callback.hpp"
#include "geometry/mercator.hpp"
#include "storage/country_info_getter.hpp"
#include "storage/storage.hpp"
#include "search/everywhere_search_params.hpp"

// Our Metal context factory
#include "AgusMetalContextFactory.h"

// Forward declarations for AgusPlatformIOS (defined in AgusPlatformIOS.mm)
extern "C" void AgusPlatformIOS_InitPaths(const char* resourcePath, const char* writablePath);
extern "C" void* AgusPlatformIOS_GetInstance(void);

#pragma mark - Global State

static std::unique_ptr<Framework> g_framework;
static drape_ptr<dp::ThreadSafeFactory> g_threadSafeFactory;
static agus::AgusMetalContextFactory* g_metalContextFactory = nullptr; // raw pointer for pixel buffer updates
static std::string g_resourcePath;
static std::string g_writablePath;
static bool g_platformInitialized = false;
static bool g_drapeEngineCreated = false;
// Render keep-alive to push a few extra frames while tiles/fonts load
static dispatch_source_t g_renderKeepAliveTimer = nil;
static int g_renderKeepAliveCount = 0;
static const int kRenderKeepAliveMaxCount = 20; // ~0.33s at 60fps, enough to seed initial tiles

// Surface state
static int32_t g_surfaceWidth = 0;
static int32_t g_surfaceHeight = 0;
static float g_density = 2.0f;
static int64_t g_textureId = -1;

// Frame ready callback
typedef void (*FrameReadyCallback)(void);
static FrameReadyCallback g_frameReadyCallback = nullptr;

// Frame notification timing for 60fps rate limiting (Option 2)
static std::chrono::steady_clock::time_point g_lastFrameNotification;
static constexpr auto kMinFrameInterval = std::chrono::milliseconds(16); // ~60fps

// Throttling flag to prevent queuing too many frame notifications
static std::atomic<bool> g_frameNotificationPending{false};

// Forward declaration for active frame notification
static void notifyFlutterFrameReady(void);
static void startRenderKeepAliveTimer(void);
static void stopRenderKeepAliveTimer(void);

#pragma mark - Logging

// Custom log handler that redirects to NSLog
static void AgusLogMessage(base::LogLevel level, base::SrcPoint const & src, std::string const & msg) {
    NSString* levelStr;
    switch (level) {
        case base::LDEBUG: levelStr = @"DEBUG"; break;
        case base::LINFO: levelStr = @"INFO"; break;
        case base::LWARNING: levelStr = @"WARN"; break;
        case base::LERROR: levelStr = @"ERROR"; break;
        case base::LCRITICAL: levelStr = @"CRITICAL"; break;
        default: levelStr = @"???"; break;
    }
    
    NSLog(@"[CoMaps %@] %s %s", levelStr, 
          DebugPrint(src).c_str(), msg.c_str());
    
    // Only abort on CRITICAL, not ERROR
    if (level >= base::LCRITICAL) {
        NSLog(@"[CoMaps CRITICAL] Aborting...");
        abort();
    }
}

#pragma mark - FFI Functions

FFI_PLUGIN_EXPORT int sum(int a, int b) { 
    return a + b; 
}

FFI_PLUGIN_EXPORT int sum_long_running(int a, int b) {
    [NSThread sleepForTimeInterval:5.0];
    return a + b;
}

FFI_PLUGIN_EXPORT void comaps_init(const char* apkPath, const char* storagePath) {
    // iOS doesn't use APK paths - redirect to comaps_init_paths
    comaps_init_paths(apkPath, storagePath);
}

FFI_PLUGIN_EXPORT void comaps_init_paths(const char* resourcePath, const char* writablePath) {
    NSLog(@"[AgusMapsFlutter] comaps_init_paths: resource=%s, writable=%s", resourcePath, writablePath);
    
    // Set up custom log handler before doing anything else
    base::SetLogMessageFn(&AgusLogMessage);
    base::g_LogAbortLevel = base::LCRITICAL;
    
    // Store paths
    g_resourcePath = resourcePath ? resourcePath : "";
    g_writablePath = writablePath ? writablePath : "";
    
    // Initialize platform paths via AgusPlatformIOS
    AgusPlatformIOS_InitPaths(resourcePath, writablePath);
    g_platformInitialized = true;
    
    NSLog(@"[AgusMapsFlutter] Platform initialized, Framework deferred to surface creation");
}

static void stopRenderKeepAliveTimer(void) {
    if (g_renderKeepAliveTimer) {
        dispatch_source_cancel(g_renderKeepAliveTimer);
        g_renderKeepAliveTimer = nil;
    }
    g_renderKeepAliveCount = 0;
}

static void startRenderKeepAliveTimer(void) {
    stopRenderKeepAliveTimer();

    // Drive a few frames to let tiles/fonts settle; keeps CPU bounded.
    g_renderKeepAliveTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    if (!g_renderKeepAliveTimer) {
        return;
    }

    dispatch_source_set_timer(
        g_renderKeepAliveTimer,
        dispatch_time(DISPATCH_TIME_NOW, 0),
        (uint64_t)(NSEC_PER_SEC / 60),
        1 * NSEC_PER_MSEC);

    dispatch_source_set_event_handler(g_renderKeepAliveTimer, ^{
        g_renderKeepAliveCount++;
        if (g_framework && g_drapeEngineCreated) {
            // MakeFrameActive posts an ActiveFrameEvent so ActiveFrameCallback fires
            g_framework->MakeFrameActive();
            if (g_renderKeepAliveCount <= 5 || g_renderKeepAliveCount % 10 == 0) {
                NSLog(@"[AgusMapsFlutter] Render keep-alive tick %d/%d (MakeFrameActive)",
                      g_renderKeepAliveCount, kRenderKeepAliveMaxCount);
            }
        }
        if (g_renderKeepAliveCount >= kRenderKeepAliveMaxCount) {
            stopRenderKeepAliveTimer();
        }
    });

    dispatch_resume(g_renderKeepAliveTimer);
}

FFI_PLUGIN_EXPORT void comaps_load_map_path(const char* path) {
    NSLog(@"[AgusMapsFlutter] comaps_load_map_path: %s", path);
    
    if (g_framework) {
        g_framework->RegisterAllMaps();
        NSLog(@"[AgusMapsFlutter] Maps registered");
    } else {
        NSLog(@"[AgusMapsFlutter] Framework not yet initialized, maps will be loaded later");
    }
}

FFI_PLUGIN_EXPORT void comaps_set_view(double lat, double lon, int zoom) {
    NSLog(@"[AgusMapsFlutter] comaps_set_view: lat=%.6f, lon=%.6f, zoom=%d", lat, lon, zoom);
    
    if (g_framework) {
        g_framework->SetViewportCenter(m2::PointD(mercator::FromLatLon(lat, lon)), zoom);
        // Force invalidate to ensure tiles reload
        g_framework->InvalidateRect(g_framework->GetCurrentViewport());
    }
}

FFI_PLUGIN_EXPORT void comaps_invalidate(void) {
    NSLog(@"[AgusMapsFlutter] comaps_invalidate");
    if (g_framework) {
        g_framework->InvalidateRect(g_framework->GetCurrentViewport());
    }
}

FFI_PLUGIN_EXPORT void comaps_force_redraw(void) {
    NSLog(@"[AgusMapsFlutter] comaps_force_redraw - triggering full tile reload");
    if (g_framework) {
        // Step 1: Update map style - clears render groups and forces tile re-request
        MapStyle currentStyle = g_framework->GetMapStyle();
        g_framework->SetMapStyle(currentStyle);
        
        // Step 2: InvalidateRendering posts high-priority message to force re-render
        g_framework->InvalidateRendering();
        
        // Step 3: Invalidate viewport rect
        g_framework->InvalidateRect(g_framework->GetCurrentViewport());
    }
}

FFI_PLUGIN_EXPORT void comaps_touch(int type, int id1, float x1, float y1, int id2, float x2, float y2) {
    if (!g_framework || !g_drapeEngineCreated) {
        return;
    }
    
    df::TouchEvent event;
    
    switch (type) {
        case 1: event.SetTouchType(df::TouchEvent::TOUCH_DOWN); break;
        case 2: event.SetTouchType(df::TouchEvent::TOUCH_MOVE); break;
        case 3: event.SetTouchType(df::TouchEvent::TOUCH_UP); break;
        case 4: event.SetTouchType(df::TouchEvent::TOUCH_CANCEL); break;
        default: return;
    }
    
    // Set first touch
    df::Touch t1;
    t1.m_id = id1;
    t1.m_location = m2::PointF(x1, y1);
    event.SetFirstTouch(t1);
    event.SetFirstMaskedPointer(0);
    
    // Set second touch if valid (for multitouch)
    if (id2 >= 0) {
        df::Touch t2;
        t2.m_id = id2;
        t2.m_location = m2::PointF(x2, y2);
        event.SetSecondTouch(t2);
        event.SetSecondMaskedPointer(1);
    }
    
    g_framework->TouchEvent(event);
}

FFI_PLUGIN_EXPORT void comaps_scale(double factor, double pixelX, double pixelY, int animated) {
    if (!g_framework || !g_drapeEngineCreated) {
        return;
    }
    
    // Scale the map by the given factor, centered on the pixel point
    // This is the preferred method for scroll wheel zoom on desktop (macOS)
    g_framework->Scale(factor, m2::PointD(pixelX, pixelY), animated != 0);
}

FFI_PLUGIN_EXPORT void comaps_scroll(double distanceX, double distanceY) {
    if (!g_framework || !g_drapeEngineCreated) {
        return;
    }
    
    // Scroll the map by the given distance
    g_framework->Scroll(distanceX, distanceY);
}

FFI_PLUGIN_EXPORT int comaps_register_single_map(const char* fullPath) {
    // Delegate to versioned registration with version=0 for backwards compatibility
    return comaps_register_single_map_with_version(fullPath, 0);
}

FFI_PLUGIN_EXPORT int comaps_register_single_map_with_version(const char* fullPath, int64_t version) {
    NSLog(@"[AgusMapsFlutter] comaps_register_single_map_with_version: %s (version=%lld)", fullPath, (long long)version);
    
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] Framework not initialized");
        return -1;
    }
    
    try {
        std::string path(fullPath ? fullPath : "");
        if (path.empty()) {
            NSLog(@"[AgusMapsFlutter] Empty path");
            return -2;
        }
        
        // Derive country name from filename (without extension)
        auto name = path;
        auto lastSlash = name.rfind('/');
        if (lastSlash != std::string::npos) {
            name = name.substr(lastSlash + 1);
        }
        auto dotPos = name.rfind('.');
        if (dotPos != std::string::npos) {
            name = name.substr(0, dotPos);
        }
        
        // Get directory from full path
        std::string directory;
        lastSlash = path.rfind('/');
        if (lastSlash != std::string::npos) {
            directory = path.substr(0, lastSlash);
        }
        
        platform::LocalCountryFile file(directory, platform::CountryFile(std::move(name)), version);
        file.SyncWithDisk();
        
        auto result = g_framework->RegisterMap(file);
        if (result.second == MwmSet::RegResult::Success) {
            NSLog(@"[AgusMapsFlutter] Successfully registered %s", fullPath);
            return 0;
        } else {
            NSLog(@"[AgusMapsFlutter] Failed to register %s, result=%d", 
                  fullPath, static_cast<int>(result.second));
            return static_cast<int>(result.second);
        }
    } catch (std::exception const & e) {
        NSLog(@"[AgusMapsFlutter] Exception registering map: %s", e.what());
        return -2;
    }
}

FFI_PLUGIN_EXPORT int comaps_deregister_map(const char* fullPath) {
    NSLog(@"[AgusMapsFlutter] comaps_deregister_map: %s (not implemented)", fullPath);
    
    // TODO: Implement map deregistration when needed
    // Framework only exposes const DataSource, and DeregisterMap requires non-const
    // For MVP, maps are registered at startup and not deregistered at runtime
    
    return -1;  // Not implemented
}

FFI_PLUGIN_EXPORT int comaps_get_registered_maps_count(void) {
    if (!g_framework) {
        return 0;
    }
    
    auto const & dataSource = g_framework->GetDataSource();
    std::vector<std::shared_ptr<MwmInfo>> mwms;
    dataSource.GetMwmsInfo(mwms);
    return static_cast<int>(mwms.size());
}

FFI_PLUGIN_EXPORT void comaps_debug_list_mwms(void) {
    NSLog(@"[AgusMapsFlutter] === DEBUG: Listing all registered MWMs ===");
    
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] Framework not initialized");
        return;
    }
    
    auto const & dataSource = g_framework->GetDataSource();
    std::vector<std::shared_ptr<MwmInfo>> mwms;
    dataSource.GetMwmsInfo(mwms);
    
    NSLog(@"[AgusMapsFlutter] Total MWMs registered: %lu", mwms.size());
    
    for (auto const & mwmInfo : mwms) {
        if (mwmInfo) {
            auto const & rect = mwmInfo->m_bordersRect;
            NSLog(@"[AgusMapsFlutter]   MWM: %s, bounds: [%.4f, %.4f] - [%.4f, %.4f]",
                  mwmInfo->GetCountryName().c_str(),
                  rect.minX(), rect.minY(), rect.maxX(), rect.maxY());
        }
    }
}

FFI_PLUGIN_EXPORT void comaps_debug_check_point(double lat, double lon) {
    NSLog(@"[AgusMapsFlutter] comaps_debug_check_point: lat=%.6f, lon=%.6f", lat, lon);
    
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] Framework not initialized");
        return;
    }
    
    m2::PointD const mercatorPt = mercator::FromLatLon(lat, lon);
    NSLog(@"[AgusMapsFlutter] Mercator coords: (%.4f, %.4f)", mercatorPt.x, mercatorPt.y);
    
    auto const & dataSource = g_framework->GetDataSource();
    std::vector<std::shared_ptr<MwmInfo>> mwms;
    dataSource.GetMwmsInfo(mwms);
    
    for (auto const & mwmInfo : mwms) {
        if (mwmInfo && mwmInfo->m_bordersRect.IsPointInside(mercatorPt)) {
            NSLog(@"[AgusMapsFlutter] Point IS covered by MWM: %s", 
                  mwmInfo->GetCountryName().c_str());
            return;
        }
    }
    
    NSLog(@"[AgusMapsFlutter] Point is NOT covered by any registered MWM");
}

#pragma mark - DrapeEngine Creation

static void createDrapeEngineIfNeeded(int width, int height, float density) {
    if (g_drapeEngineCreated || !g_framework || !g_threadSafeFactory) {
        return;
    }
    
    if (width <= 0 || height <= 0) {
        NSLog(@"[AgusMapsFlutter] createDrapeEngine: Invalid dimensions %dx%d", width, height);
        return;
    }
    
    // Register active frame callback BEFORE creating DrapeEngine
    // This callback is invoked only when isActiveFrame is true (Option 3)
    df::SetActiveFrameCallback([]() {
        notifyFlutterFrameReady();
    });
    NSLog(@"[AgusMapsFlutter] Active frame callback registered");
    
    Framework::DrapeCreationParams p;
    p.m_apiVersion = dp::ApiVersion::Metal;  // Use Metal on iOS
    p.m_surfaceWidth = width;
    p.m_surfaceHeight = height;
    p.m_visualScale = density;
    
    NSLog(@"[AgusMapsFlutter] createDrapeEngine: Creating with %dx%d, scale=%.2f, API=Metal", 
          width, height, density);
    
    g_framework->CreateDrapeEngine(make_ref(g_threadSafeFactory), std::move(p));
    g_drapeEngineCreated = true;
    
    NSLog(@"[AgusMapsFlutter] DrapeEngine created successfully");

    // Kick the render loop immediately so the first frame is active
    g_framework->MakeFrameActive();
}

#pragma mark - Native Surface Functions (called from Swift)

/// Called when Swift creates a new map surface
/// @param textureId Flutter texture ID
/// @param pixelBuffer CVPixelBuffer for rendering target
/// @param width Surface width in pixels
/// @param height Surface height in pixels
/// @param density Screen density
extern "C" FFI_PLUGIN_EXPORT void agus_native_set_surface(
    int64_t textureId,
    CVPixelBufferRef pixelBuffer,
    int32_t width,
    int32_t height,
    float density
) {
    NSLog(@"[AgusMapsFlutter] agus_native_set_surface: texture=%lld, %dx%d, density=%.2f",
          textureId, width, height, density);
    
    if (!g_platformInitialized) {
        NSLog(@"[AgusMapsFlutter] ERROR: Platform not initialized! Call comaps_init_paths first.");
        return;
    }
    
    g_textureId = textureId;
    g_surfaceWidth = width;
    g_surfaceHeight = height;
    g_density = density;
    
    // Reset frame notification state to ensure we don't get stuck with a pending flag
    // from a previous session that might have been interrupted.
    g_frameNotificationPending.store(false);
    g_lastFrameNotification = std::chrono::steady_clock::time_point();
    
    // Create Framework on this thread if not already created
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] Creating Framework...");
        
        FrameworkParams params;
        params.m_enableDiffs = false;
        params.m_numSearchAPIThreads = 1;
        
        g_framework = std::make_unique<Framework>(params, false /* loadMaps */);
        NSLog(@"[AgusMapsFlutter] Framework created");
        
        // Register maps
        g_framework->RegisterAllMaps();
        NSLog(@"[AgusMapsFlutter] Maps registered");
    }
    
    // Create Metal context factory with the CVPixelBuffer
    m2::PointU screenSize(static_cast<uint32_t>(width), static_cast<uint32_t>(height));
    auto metalFactory = new agus::AgusMetalContextFactory(pixelBuffer, screenSize);
    
    if (!metalFactory->IsDrawContextCreated()) {
        NSLog(@"[AgusMapsFlutter] ERROR: Failed to create Metal context");
        delete metalFactory;
        return;
    }
    
    // Save raw pointer for later SetPixelBuffer on resize and wrap in ThreadSafeFactory
    g_metalContextFactory = metalFactory;
    g_threadSafeFactory = make_unique_dp<dp::ThreadSafeFactory>(metalFactory);
    
    // Create DrapeEngine
    createDrapeEngineIfNeeded(width, height, density);
    
    // Enable rendering
    if (g_framework && g_drapeEngineCreated) {
        g_framework->SetRenderingEnabled(make_ref(g_threadSafeFactory));
        NSLog(@"[AgusMapsFlutter] Rendering enabled");
        startRenderKeepAliveTimer();
    }
}

/// Called when Swift resizes the surface
extern "C" FFI_PLUGIN_EXPORT void agus_native_on_size_changed(int32_t width, int32_t height) {
    NSLog(@"[AgusMapsFlutter] agus_native_on_size_changed: %dx%d", width, height);
    
    g_surfaceWidth = width;
    g_surfaceHeight = height;

    if (g_framework && g_drapeEngineCreated) {
        g_framework->OnSize(width, height);
    }
}

/// Update visual scale without resizing surface
extern "C" FFI_PLUGIN_EXPORT void agus_native_set_visual_scale(float density) {
    if (density <= 0) {
        NSLog(@"[AgusMapsFlutter] agus_native_set_visual_scale: invalid density %.2f", density);
        return;
    }

    g_density = density;

    if (g_framework && g_drapeEngineCreated) {
        df::VisualParams::Instance().SetVisualScale(static_cast<double>(density));
        g_framework->InvalidateRendering();
        NSLog(@"[AgusMapsFlutter] agus_native_set_visual_scale: Updated visual scale to %.2f", density);
    } else {
        NSLog(@"[AgusMapsFlutter] agus_native_set_visual_scale: Framework not ready, stored density %.2f", density);
    }
}

/// Called when Swift recreates the CVPixelBuffer on resize
extern "C" FFI_PLUGIN_EXPORT void agus_native_update_surface(
    CVPixelBufferRef pixelBuffer,
    int32_t width,
    int32_t height
) {
    NSLog(@"[AgusMapsFlutter] agus_native_update_surface: %dx%d", width, height);
    if (!g_metalContextFactory) {
        NSLog(@"[AgusMapsFlutter] WARNING: No Metal context factory to update");
        return;
    }
    
    // Reset frame notification state to ensure we don't get stuck
    g_frameNotificationPending.store(false);
    g_lastFrameNotification = std::chrono::steady_clock::time_point();
    
    g_surfaceWidth = width;
    g_surfaceHeight = height;
    m2::PointU screenSize(static_cast<uint32_t>(width), static_cast<uint32_t>(height));
    g_metalContextFactory->SetPixelBuffer(pixelBuffer, screenSize);
    if (g_framework && g_drapeEngineCreated) {
        g_framework->OnSize(width, height);
        // Force a complete re-render into the new pixel buffer.
        // InvalidateRendering() is REQUIRED to actually trigger rendering - 
        // without it, the engine validates but skips the actual render cycle.
        g_framework->InvalidateRendering();
        g_framework->InvalidateRect(g_framework->GetCurrentViewport());
        g_framework->MakeFrameActive();
        startRenderKeepAliveTimer();
    }
}

/// Called when Swift destroys the surface
extern "C" FFI_PLUGIN_EXPORT void agus_native_on_surface_destroyed(void) {
    NSLog(@"[AgusMapsFlutter] agus_native_on_surface_destroyed");
    
    // Reset frame notification state
    g_frameNotificationPending.store(false);
    
    if (g_framework) {
        g_framework->SetRenderingDisabled(true /* destroySurface */);
    }
    
    stopRenderKeepAliveTimer();

    g_threadSafeFactory.reset();
    g_metalContextFactory = nullptr;
    g_drapeEngineCreated = false;
}

/// Called by native code to notify Swift that a new frame is ready
/// This should trigger textureRegistry.textureFrameAvailable(textureId)
extern "C" FFI_PLUGIN_EXPORT void agus_set_frame_ready_callback(FrameReadyCallback callback) {
    g_frameReadyCallback = callback;
}

/// Internal function to notify Flutter about a new frame
/// Called from the DrapeEngine render thread via df::SetActiveFrameCallback
static void notifyFlutterFrameReady(void) {
    // Rate limiting (Option 2): Enforce 60fps max
    auto now = std::chrono::steady_clock::now();
    auto elapsed = now - g_lastFrameNotification;
    if (elapsed < kMinFrameInterval) {
        return;  // Too soon, skip this notification
    }
    
    // Throttle: if a notification is already pending, skip this one
    // This prevents memory buildup from queued dispatch_async calls
    bool expected = false;
    if (!g_frameNotificationPending.compare_exchange_strong(expected, true)) {
        return;  // Already a notification pending, skip
    }
    
    g_lastFrameNotification = now;
    
    if (g_frameReadyCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            g_frameNotificationPending.store(false);
            g_frameReadyCallback();
        });
    } else {
        // Fallback: call Swift static method directly if no callback is set
        dispatch_async(dispatch_get_main_queue(), ^{
            g_frameNotificationPending.store(false);
            // Use the @objc name we assigned to the Swift class
            // The class is declared as @objc(AgusMapsFlutterPlugin)
            Class pluginClass = NSClassFromString(@"AgusMapsFlutterPlugin");
            if (pluginClass) {
                SEL selector = NSSelectorFromString(@"notifyFrameReadyFromNative");
                if ([pluginClass respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [pluginClass performSelector:selector];
#pragma clang diagnostic pop
                }
            } else {
                // Debug: log if class lookup fails
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    NSLog(@"[AgusMapsFlutter] WARNING: Could not find AgusMapsFlutterPlugin class for frame notification");
                });
            }
        });
    }
}

/// Called by Present() to notify Flutter that a frame was rendered
/// Used for initial frames and as fallback when df::SetActiveFrameCallback doesn't trigger
extern "C" void agus_notify_frame_ready(void) {
    notifyFlutterFrameReady();
}

#pragma mark - Render Frame

/// Called to render a single frame - this is triggered by Flutter's texture system
extern "C" FFI_PLUGIN_EXPORT void agus_render_frame(void) {
    if (!g_framework || !g_drapeEngineCreated) {
        return;
    }
    
    // The DrapeEngine handles rendering internally
    // We just need to ensure the render loop is running
    // Frame completion will trigger agus_notify_frame_ready
}

#pragma mark - Map Style

extern "C" FFI_PLUGIN_EXPORT void comaps_set_map_style(int style) {
    NSLog(@"[AgusMapsFlutter] comaps_set_map_style: style=%d", style);
    
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] comaps_set_map_style: Framework not initialized");
        return;
    }
    
    // Validate style value
    if (style < 0 || style >= MapStyleCount) {
        NSLog(@"[AgusMapsFlutter] comaps_set_map_style: Invalid style value %d", style);
        return;
    }
    
    MapStyle mapStyle = static_cast<MapStyle>(style);
    g_framework->SetMapStyle(mapStyle);
    
    // Force redraw to apply new style
    g_framework->InvalidateRendering();
    g_framework->InvalidateRect(g_framework->GetCurrentViewport());
    
    NSLog(@"[AgusMapsFlutter] comaps_set_map_style: Style changed to %d", style);
}

extern "C" FFI_PLUGIN_EXPORT int comaps_get_map_style(void) {
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] comaps_get_map_style: Framework not initialized");
        return 0; // Return DefaultLight as default
    }
    
    MapStyle currentStyle = g_framework->GetMapStyle();
    NSLog(@"[AgusMapsFlutter] comaps_get_map_style: Current style=%d", static_cast<int>(currentStyle));
    
    return static_cast<int>(currentStyle);
}

#pragma mark - Additional Native Functions for iOS Plugin Parity

// Map status check
extern "C" FFI_PLUGIN_EXPORT int32_t agus_native_check_map_status(double lat, double lon) {
    if (!g_framework) return 0; // Undefined
    
    m2::PointD const pt = mercator::FromLatLon(lat, lon);
    auto const & infoGetter = g_framework->GetCountryInfoGetter();
    storage::CountryId countryId = infoGetter.GetRegionCountryId(pt);
    
    if (countryId == storage::kInvalidCountryId) return 0; // Undefined/Ocean
    
    storage::Status status = g_framework->GetStorage().CountryStatusEx(countryId);
    return static_cast<int32_t>(status);
}

// PlacePage info
extern "C" FFI_PLUGIN_EXPORT const char* agus_native_get_place_page_info(void) {
    if (!g_framework || !g_framework->HasPlacePageInfo()) return nullptr;
    
    auto const & info = g_framework->GetCurrentPlacePageInfo();
    
    // Construct simple JSON string (static buffer for simplicity)
    static std::string jsonBuffer;
    jsonBuffer = "{";
    jsonBuffer += "\"title\":\"" + info.GetTitle() + "\",";
    jsonBuffer += "\"subtitle\":\"" + info.GetSubtitle() + "\",";
    
    auto mercator = info.GetMercator();
    auto latlon = mercator::ToLatLon(mercator);
    jsonBuffer += "\"lat\":" + std::to_string(latlon.m_lat) + ",";
    jsonBuffer += "\"lon\":" + std::to_string(latlon.m_lon);
    
    jsonBuffer += "}";
    
    return jsonBuffer.c_str();
}

// Routing functions
extern "C" FFI_PLUGIN_EXPORT void agus_native_build_route(double lat, double lon) {
    if (!g_framework) return;
    
    auto & rm = g_framework->GetRoutingManager();
    rm.RemoveRoute(true);
    
    // Set router type to Vehicle (car) for navigation with voice guidance
    rm.SetRouter(routing::RouterType::Vehicle);
    NSLog(@"[AgusMapsFlutter] Router type set to Vehicle");
    
    // Set Start (My Position)
    RouteMarkData startPt;
    startPt.m_isMyPosition = true;
    startPt.m_pointType = RouteMarkType::Start;
    rm.AddRoutePoint(std::move(startPt));
    
    // Set Finish
    RouteMarkData finishPt;
    finishPt.m_position = m2::PointD(mercator::FromLatLon(lat, lon));
    finishPt.m_pointType = RouteMarkType::Finish;
    rm.AddRoutePoint(std::move(finishPt));
    
    rm.BuildRoute();
    
    NSLog(@"[AgusMapsFlutter] agus_native_build_route: Route building initiated");
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_stop_routing(void) {
    if (!g_framework) return;
    g_framework->GetRoutingManager().CloseRouting(true);
    
    // Disable 3D perspective when stopping navigation
    g_framework->Allow3dMode(false, false);
    
    NSLog(@"[AgusMapsFlutter] agus_native_stop_routing: Navigation stopped");
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_follow_route(void) {
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] agus_native_follow_route: Framework not initialized");
        return;
    }
    
    auto & rm = g_framework->GetRoutingManager();
    rm.FollowRoute();
    
    // Enable 3D perspective for navigation
    g_framework->Allow3dMode(true, true);
    
    NSLog(@"[AgusMapsFlutter] agus_native_follow_route: Navigation mode activated with 3D perspective");
}

// My Position mode functions
extern "C" FFI_PLUGIN_EXPORT void agus_native_switch_my_position_mode(void) {
    if (!g_framework || !g_drapeEngineCreated) {
        NSLog(@"[AgusMapsFlutter] agus_native_switch_my_position_mode: Framework or DrapeEngine not ready");
        return;
    }
    
    auto currentMode = g_framework->GetMyPositionMode();
    NSLog(@"[AgusMapsFlutter] agus_native_switch_my_position_mode: current mode=%d", static_cast<int>(currentMode));
    
    g_framework->SwitchMyPositionNextMode();
    
    auto newMode = g_framework->GetMyPositionMode();
    NSLog(@"[AgusMapsFlutter] agus_native_switch_my_position_mode: new mode=%d", static_cast<int>(newMode));
}

extern "C" FFI_PLUGIN_EXPORT int32_t agus_native_get_my_position_mode(void) {
    if (!g_framework || !g_drapeEngineCreated) return 0; // PENDING_POSITION
    return static_cast<int32_t>(g_framework->GetMyPositionMode());
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_set_my_position_mode(int32_t mode) {
    if (!g_framework || !g_drapeEngineCreated) {
        NSLog(@"[AgusMapsFlutter] agus_native_set_my_position_mode: Framework or DrapeEngine not ready");
        return;
    }
    
    NSLog(@"[AgusMapsFlutter] agus_native_set_my_position_mode: setting mode to %d", mode);
    
    // Cycle through modes until we reach the desired one
    auto currentMode = g_framework->GetMyPositionMode();
    int attempts = 0;
    const int maxAttempts = 5;
    
    while (static_cast<int>(currentMode) != mode && attempts < maxAttempts) {
        g_framework->SwitchMyPositionNextMode();
        currentMode = g_framework->GetMyPositionMode();
        attempts++;
    }
    
    NSLog(@"[AgusMapsFlutter] agus_native_set_my_position_mode: final mode=%d after %d attempts", 
          static_cast<int>(currentMode), attempts);
}

// Scale function
extern "C" FFI_PLUGIN_EXPORT void agus_native_scale(double factor) {
    if (!g_framework) return;
    // Scale relative to center, animated
    g_framework->Scale(factor, true);
}

// Location and compass updates
extern "C" FFI_PLUGIN_EXPORT void agus_native_on_location_update(double lat, double lon, double accuracy, double bearing, double speed, int64_t time) {
    if (!g_framework) return;
    
    location::GpsInfo info;
    info.m_latitude = lat;
    info.m_longitude = lon;
    info.m_timestamp = static_cast<double>(time) / 1000.0;
    info.m_source = location::EAppleNative;
    
    // Always set accuracy (even if 0)
    info.m_horizontalAccuracy = accuracy;
    
    // Set bearing if valid
    if (bearing >= 0.0) {
        info.m_bearing = bearing;
    }
    
    // Set speed if valid
    if (speed >= 0.0) {
        info.m_speed = speed;
    }
    
    NSLog(@"[AgusMapsFlutter] agus_native_on_location_update: lat=%.6f, lon=%.6f, accuracy=%.2f, bearing=%.2f, speed=%.2f", 
          lat, lon, accuracy, bearing, speed);
    
    // Send location update to framework
    g_framework->OnLocationUpdate(info);
    
    // Ensure map redrawing is triggered
    if (g_drapeEngineCreated) {
        g_framework->InvalidateRendering();
        g_framework->MakeFrameActive();
    }
    
    // Update GPS tracker
    GpsTracker::Instance().OnLocationUpdated(info);
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_on_compass_update(double bearing) {
    if (!g_framework) return;
    
    location::CompassInfo info;
    info.m_bearing = bearing;
    
    NSLog(@"[AgusMapsFlutter] agus_native_on_compass_update: bearing=%.2f", bearing);
    
    g_framework->OnCompassUpdate(info);
    
    // Trigger map redraw
    if (g_drapeEngineCreated) {
        g_framework->InvalidateRendering();
        g_framework->MakeFrameActive();
    }
}

// Country name lookup
extern "C" FFI_PLUGIN_EXPORT const char* agus_native_get_country_name(double lat, double lon) {
    if (!g_framework) return nullptr;
    
    auto const & infoGetter = g_framework->GetCountryInfoGetter();
    m2::PointD const pt = mercator::FromLatLon(lat, lon);
    storage::CountryId countryId = infoGetter.GetRegionCountryId(pt);
    
    static std::string countryBuffer;
    countryBuffer = countryId;
    return countryBuffer.c_str();
}

// Route following info
extern "C" FFI_PLUGIN_EXPORT const char* agus_native_get_route_following_info(void) {
    NSLog(@"[AgusMapsFlutter] agus_native_get_route_following_info: Called");
    
    if (!g_framework) {
        NSLog(@"[AgusMapsFlutter] agus_native_get_route_following_info: Framework is null");
        return nullptr;
    }
    
    RoutingManager & rm = g_framework->GetRoutingManager();
    
    if (!rm.IsRoutingActive()) {
        NSLog(@"[AgusMapsFlutter] agus_native_get_route_following_info: Routing is not active");
        return nullptr;
    }
    
    routing::FollowingInfo info;
    rm.GetRouteFollowingInfo(info);
    
    // Create JSON string with routing info
    static std::string jsonBuffer;
    std::ostringstream json;
    json << "{";
    
    // Convert distances to meters
    auto distToTargetMeters = info.m_distToTarget.To(platform::Distance::Units::Meters);
    auto distToTurnMeters = info.m_distToTurn.To(platform::Distance::Units::Meters);
    json << "\"distanceToTarget\":" << distToTargetMeters.GetDistance() << ",";
    json << "\"distanceToTurn\":" << distToTurnMeters.GetDistance() << ",";
    json << "\"timeToTarget\":" << info.m_time << ",";
    json << "\"turn\":" << static_cast<int>(info.m_turn) << ",";
    json << "\"nextTurn\":" << static_cast<int>(info.m_nextTurn) << ",";
    json << "\"exitNum\":" << info.m_exitNum << ",";
    json << "\"completionPercent\":" << info.m_completionPercent << ",";
    json << "\"speedLimitMps\":" << (info.m_speedLimitMps > 0 ? info.m_speedLimitMps : 0) << ",";
    json << "\"currentStreetName\":\"" << info.m_currentStreetName << "\",";
    json << "\"nextStreetName\":\"" << info.m_nextStreetName << "\"";
    json << "}";
    
    jsonBuffer = json.str();
    return jsonBuffer.c_str();
}

// Navigation notifications
extern "C" FFI_PLUGIN_EXPORT const char** agus_native_generate_notifications(bool announceStreets, int32_t* count) {
    if (!g_framework) {
        *count = 0;
        return nullptr;
    }
    
    RoutingManager & rm = g_framework->GetRoutingManager();
    
    if (!rm.IsRoutingActive()) {
        *count = 0;
        return nullptr;
    }
    
    static std::vector<std::string> notifications;
    notifications.clear();
    rm.GenerateNotifications(notifications, announceStreets);
    
    if (notifications.empty()) {
        *count = 0;
        return nullptr;
    }
    
    // Create array of C strings
    static std::vector<const char*> cStrings;
    cStrings.clear();
    for (auto const & n : notifications) {
        cStrings.push_back(n.c_str());
    }
    
    *count = static_cast<int32_t>(cStrings.size());
    return cStrings.data();
}

extern "C" FFI_PLUGIN_EXPORT bool agus_native_is_route_finished(void) {
    if (!g_framework) return false;
    
    RoutingManager & rm = g_framework->GetRoutingManager();
    return rm.IsRouteFinished();
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_disable_following(void) {
    if (!g_framework) return;
    g_framework->GetRoutingManager().DisableFollowMode();
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_remove_route(void) {
    if (!g_framework) return;
    g_framework->GetRoutingManager().RemoveRoute(true /* deactivateFollowing */);
}

// Turn notifications
extern "C" FFI_PLUGIN_EXPORT void agus_native_set_turn_notifications_locale(const char* locale) {
    if (!g_framework || !locale) return;
    
    g_framework->GetRoutingManager().SetTurnNotificationsLocale(locale);
    NSLog(@"[AgusMapsFlutter] agus_native_set_turn_notifications_locale: %s", locale);
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_enable_turn_notifications(bool enable) {
    if (!g_framework) return;
    
    g_framework->GetRoutingManager().EnableTurnNotifications(enable);
    NSLog(@"[AgusMapsFlutter] agus_native_enable_turn_notifications: %d", enable);
}

extern "C" FFI_PLUGIN_EXPORT bool agus_native_are_turn_notifications_enabled(void) {
    if (!g_framework) return false;
    
    return g_framework->GetRoutingManager().AreTurnNotificationsEnabled();
}

extern "C" FFI_PLUGIN_EXPORT const char* agus_native_get_turn_notifications_locale(void) {
    if (!g_framework) return nullptr;
    
    static std::string localeBuffer;
    localeBuffer = g_framework->GetRoutingManager().GetTurnNotificationsLocale();
    return localeBuffer.c_str();
}

// Search functions
extern "C" FFI_PLUGIN_EXPORT void agus_native_search(const char* query, double lat, double lon) {
    if (!g_framework || !query) {
        NSLog(@"[AgusMapsFlutter] agus_native_search: Framework not initialized or query is null");
        return;
    }
    
    NSLog(@"[AgusMapsFlutter] agus_native_search: query='%s', lat=%f, lon=%f", query, lat, lon);
    
    // Create search params
    search::EverywhereSearchParams params;
    params.m_query = query;
    params.m_inputLocale = "en";
    
    // Create callback lambda for results
    params.m_onResults = [](search::Results results, std::vector<search::ProductInfo> productInfo) {
        NSLog(@"[AgusMapsFlutter] Search callback: Processing %zu results", results.GetCount());
        
        // TODO: Implement callback to Swift layer
        // For now, just log the results
        for (size_t i = 0; i < results.GetCount(); ++i) {
            auto const & r = results[i];
            auto const center = r.GetFeatureCenter();
            NSLog(@"[AgusMapsFlutter] Result %zu: %s at (%.6f, %.6f)", 
                  i, r.GetString().c_str(), center.x, center.y);
        }
        
        if (results.IsEndMarker()) {
            NSLog(@"[AgusMapsFlutter] Search completed");
        }
    };
    
    // Execute search
    g_framework->GetSearchAPI().SearchEverywhere(std::move(params));
    
    NSLog(@"[AgusMapsFlutter] agus_native_search: Search started");
}

extern "C" FFI_PLUGIN_EXPORT void agus_native_cancel_search(void) {
    if (!g_framework) return;
    
    g_framework->GetSearchAPI().CancelAllSearches();
    
    NSLog(@"[AgusMapsFlutter] agus_native_cancel_search: All searches cancelled");
}
