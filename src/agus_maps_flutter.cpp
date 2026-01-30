#include "agus_maps_flutter.h"

// A very short-lived native function.
//
// For very short-lived functions, it is fine to call them on the main isolate.
// They will block the Dart execution while running the native function, so
// only do this for native functions which are guaranteed to be short-lived.
FFI_PLUGIN_EXPORT int sum(int a, int b) { return a + b; }

// A longer-lived native function, which occupies the thread calling it.
//
// Do not call these kind of native functions in the main isolate. They will
// block Dart execution. This will cause dropped frames in Flutter applications.
// Instead, call these native functions on a separate isolate.
FFI_PLUGIN_EXPORT int sum_long_running(int a, int b) {
  // Simulate work.
#if _WIN32
  Sleep(5000);
#else
  usleep(5000 * 1000);
#endif
  return a + b;
}

#include <android/log.h>
#include <jni.h>
#include <android/native_window_jni.h>
#include <chrono>
#include <atomic>
#include <thread>

#include "base/file_name_utils.hpp"
#include "base/logging.hpp"
#include "map/framework.hpp"
#include "map/gps_tracker.hpp"
#include "platform/local_country_file.hpp"
#include "platform/location.hpp"
#include "drape/graphics_context_factory.hpp"
#include "drape_frontend/visual_params.hpp"
#include "drape_frontend/user_event_stream.hpp"
#include "drape_frontend/active_frame_callback.hpp"
#include "geometry/mercator.hpp"
#include "map/place_page_info.hpp"
#include "map/routing_manager.hpp"
#include "map/routing_mark.hpp"
#include "storage/country_info_getter.hpp"
#include "storage/storage.hpp"
#include "agus_ogl.hpp"

extern "C" void AgusPlatform_Init(const char* apkPath, const char* storagePath);
extern "C" void AgusPlatform_InitPaths(const char* resourcePath, const char* writablePath);

// Custom log handler that redirects to Android logcat without aborting on ERROR
static void AgusLogMessage(base::LogLevel level, base::SrcPoint const & src, std::string const & msg) {
    android_LogPriority pr = ANDROID_LOG_SILENT;
    
    switch (level) {
    case base::LDEBUG: pr = ANDROID_LOG_DEBUG; break;
    case base::LINFO: pr = ANDROID_LOG_INFO; break;
    case base::LWARNING: pr = ANDROID_LOG_WARN; break;
    case base::LERROR: pr = ANDROID_LOG_ERROR; break;
    case base::LCRITICAL: pr = ANDROID_LOG_FATAL; break;
    default: break;
    }
    
    std::string out = DebugPrint(src) + msg;
    __android_log_print(pr, "CoMaps", "%s", out.c_str());
    
    // Only abort on CRITICAL, not ERROR
    if (level >= base::LCRITICAL) {
        __android_log_print(ANDROID_LOG_FATAL, "CoMaps", "CRITICAL ERROR - Aborting");
        abort();
    }
}

// Globals
static std::unique_ptr<Framework> g_framework;
static drape_ptr<dp::ThreadSafeFactory> g_factory;
static std::string g_resourcePath;
static std::string g_writablePath;
static bool g_platformInitialized = false;

// Old init function for backwards compatibility (uses APK path)
FFI_PLUGIN_EXPORT void comaps_init(const char* apkPath, const char* storagePath) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_init: apk=%s, storage=%s", apkPath, storagePath);
    AgusPlatform_Init(apkPath, storagePath);
    
    // Note: Framework initialization requires many data files (categories.txt, etc.)
    // For now we just initialize the platform; full Framework will be created when surface is ready
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_init: Platform initialized, Framework deferred");
}

// New init function with explicit resource and writable paths
// NOTE: This just stores paths. Framework creation is deferred to nativeSetSurface
// to ensure Framework and CreateDrapeEngine happen on the same thread.
FFI_PLUGIN_EXPORT void comaps_init_paths(const char* resourcePath, const char* writablePath) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_init_paths: resource=%s, writable=%s", resourcePath, writablePath);
    
    // Set up our custom log handler before doing anything else
    base::SetLogMessageFn(&AgusLogMessage);
    // Set abort level to LCRITICAL so ERROR logs don't crash
    base::g_LogAbortLevel = base::LCRITICAL;
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_init_paths: Custom logging initialized");
    
    // Store paths for later use
    g_resourcePath = resourcePath;
    g_writablePath = writablePath;
    
    // Initialize platform now (sets up directories, thread infrastructure)
    AgusPlatform_InitPaths(resourcePath, writablePath);
    g_platformInitialized = true;
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_init_paths: Platform initialized, Framework deferred to render thread");
}

FFI_PLUGIN_EXPORT void comaps_load_map_path(const char* path) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_load_map_path: %s", path);
    
    if (g_framework) {
        // Register maps from the writable directory
        // The framework will scan the writable path for .mwm files
        g_framework->RegisterAllMaps();
        __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_load_map_path: Maps registered");
    } else {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", "comaps_load_map_path: Framework not yet initialized, maps will be loaded later");
    }
}

// Store current surface dimensions
static int g_surfaceWidth = 0;
static int g_surfaceHeight = 0;
static float g_density = 2.0f;
static bool g_drapeEngineCreated = false;

// Frame notification timing for 60fps rate limiting (Option 2)
static std::chrono::steady_clock::time_point g_lastFrameNotification;
static constexpr auto kMinFrameInterval = std::chrono::milliseconds(16); // ~60fps
static std::atomic<bool> g_frameNotificationPending{false};

// JNI global refs for frame notification callback
// g_javaVM is defined in agus_gui_thread.cpp and shared
extern JavaVM* g_javaVM;
static jobject g_pluginInstance = nullptr;
static jmethodID g_notifyFrameReadyMethod = nullptr;
static jmethodID g_onPlacePageEventMethod = nullptr;
static jmethodID g_onMyPositionModeChangedMethod = nullptr;
static jmethodID g_onRoutingEventMethod = nullptr;

/// Internal function to notify Android/Flutter about PlacePage event
/// type: 0 = Open, 1 = Close
static void notifyPlacePageEvent(int type) {
    if (g_javaVM && g_pluginInstance && g_onPlacePageEventMethod) {
        JNIEnv* env = nullptr;
        bool attached = false;
        
        int status = g_javaVM->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (status == JNI_EDETACHED) {
            if (g_javaVM->AttachCurrentThread(&env, nullptr) == JNI_OK) {
                attached = true;
            } else {
                return;
            }
        }
        
        if (env) {
            env->CallVoidMethod(g_pluginInstance, g_onPlacePageEventMethod, static_cast<jint>(type));
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            }
        }
        
        if (attached) {
            g_javaVM->DetachCurrentThread();
        }
    }
}

/// Internal function to notify Android/Flutter about My Position mode change
static void notifyMyPositionModeChanged(location::EMyPositionMode mode, bool routingActive) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "notifyMyPositionModeChanged: mode=%d, routingActive=%d", 
        static_cast<int>(mode), routingActive);
    
    if (g_javaVM && g_pluginInstance && g_onMyPositionModeChangedMethod) {
        JNIEnv* env = nullptr;
        bool attached = false;
        
        int status = g_javaVM->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (status == JNI_EDETACHED) {
            if (g_javaVM->AttachCurrentThread(&env, nullptr) == JNI_OK) {
                attached = true;
            } else {
                return;
            }
        }
        
        if (env) {
            env->CallVoidMethod(g_pluginInstance, g_onMyPositionModeChangedMethod, static_cast<jint>(mode));
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            }
        }
        
        if (attached) {
            g_javaVM->DetachCurrentThread();
        }
    }
}

/// Internal function to notify Android/Flutter about routing event
/// eventType: 0 = BuildStarted, 1 = BuildReady, 2 = BuildFailed, 3 = RebuildStarted
static void notifyRoutingEvent(int type, int code) {
    if (g_javaVM && g_pluginInstance && g_onRoutingEventMethod) {
        JNIEnv* env = nullptr;
        bool attached = false;
        
        int status = g_javaVM->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (status == JNI_EDETACHED) {
            if (g_javaVM->AttachCurrentThread(&env, nullptr) == JNI_OK) {
                attached = true;
            } else {
                return;
            }
        }
        
        if (env) {
            env->CallVoidMethod(g_pluginInstance, g_onRoutingEventMethod, static_cast<jint>(type), static_cast<jint>(code));
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            }
        }
        
        if (attached) {
            g_javaVM->DetachCurrentThread();
        }
    }
}

/// Internal function to notify Android/Flutter about a new frame
static void notifyFlutterFrameReady() {
    // Rate limiting (Option 2): Enforce 60fps max
    auto now = std::chrono::steady_clock::now();
    auto elapsed = now - g_lastFrameNotification;
    if (elapsed < kMinFrameInterval) {
        return;  // Too soon, skip this notification
    }
    
    // Throttle: if a notification is already pending, skip this one
    bool expected = false;
    if (!g_frameNotificationPending.compare_exchange_strong(expected, true)) {
        return;  // Already a notification pending, skip
    }
    
    g_lastFrameNotification = now;
    
    // Call back to Java/Flutter on the main thread
    if (g_javaVM && g_pluginInstance && g_notifyFrameReadyMethod) {
        JNIEnv* env = nullptr;
        bool attached = false;
        
        int status = g_javaVM->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (status == JNI_EDETACHED) {
            if (g_javaVM->AttachCurrentThread(&env, nullptr) == JNI_OK) {
                attached = true;
            } else {
                g_frameNotificationPending.store(false);
                return;
            }
        }
        
        if (env) {
            env->CallVoidMethod(g_pluginInstance, g_notifyFrameReadyMethod);
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            }
        }
        
        if (attached) {
            g_javaVM->DetachCurrentThread();
        }
    }
    
    g_frameNotificationPending.store(false);
}

static void createDrapeEngineIfNeeded(int width, int height, float density) {
    if (g_drapeEngineCreated || !g_framework) {
        return;
    }
    
    if (width <= 0 || height <= 0) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", "createDrapeEngine: Invalid dimensions %dx%d", width, height);
        return;
    }
    
    if (!g_factory) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", "createDrapeEngine: Factory not valid");
        return;
    }
    
    // Register active frame callback BEFORE creating DrapeEngine
    // This callback is invoked only when isActiveFrame is true (Option 3)
    df::SetActiveFrameCallback([]() {
        notifyFlutterFrameReady();
    });
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: Active frame callback registered");

    // Register PlacePage listeners to notify UI about selections
    g_framework->SetPlacePageListeners(
        []() { notifyPlacePageEvent(0); }, // OnOpen
        []() { notifyPlacePageEvent(1); }, // OnClose
        []() { }, // OnUpdate
        []() { }  // OnSwitchFullScreen
    );
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: PlacePage listeners registered");

    // Register My Position mode change listener to notify UI about mode changes
    g_framework->SetMyPositionModeListener(
        [](location::EMyPositionMode mode, bool routingActive) {
            notifyMyPositionModeChanged(mode, routingActive);
        }
    );
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: MyPositionMode listener registered");

    // Initialize RoutingManager listeners
    auto & rm = g_framework->GetRoutingManager();
    rm.SetRouteBuildingListener([](routing::RouterResultCode code, storage::CountriesSet const &) {
        __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", "Route building finished with code: %d", static_cast<int>(code));
        if (code == routing::RouterResultCode::NoError || code == routing::RouterResultCode::HasWarnings) {
            notifyRoutingEvent(1, static_cast<int>(code)); // BuildReady
        } else {
            notifyRoutingEvent(2, static_cast<int>(code)); // BuildFailed
        }
    });
    rm.SetRouteProgressListener([](float progress) {
        // Option to notify progress if needed
    });
    rm.SetRouteRecommendationListener([](RoutingManager::Recommendation recommend) {
        if (recommend == RoutingManager::Recommendation::RebuildAfterPointsLoading) {
            __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", "Route recommendation: RebuildAfterPointsLoading");
            notifyRoutingEvent(3, 0); // RebuildStarted
        }
    });
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: Routing listeners registered");
    
    Framework::DrapeCreationParams p;
    p.m_apiVersion = dp::ApiVersion::OpenGLES3;
    p.m_surfaceWidth = width;
    p.m_surfaceHeight = height;
    p.m_visualScale = density;
    
    // Enable Compass Widget
    gui::TWidgetsInitInfo & w = p.m_widgetsInitInfo;
    w[gui::WIDGET_COMPASS] = gui::Position(m2::PointF(20 * density, 100 * density), dp::Center); 
    
    // Disable all widgets for now (require symbols.sdf which needs Qt6 to generate)
    // TODO: Generate symbols.sdf and enable widgets
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: Creating with %dx%d, scale=%.2f", width, height, density);
    g_framework->CreateDrapeEngine(make_ref(g_factory), std::move(p));
    g_drapeEngineCreated = true;
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: Drape engine created successfully");
    
    // CRITICAL: Enable rendering after DrapeEngine creation!
    // Without this, the DrapeEngine is in a disabled state and won't render.
    g_framework->SetRenderingEnabled(make_ref(g_factory));
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: Rendering enabled");
    
    // Force initial render cycle like iOS does
    g_framework->InvalidateRendering();
    g_framework->InvalidateRect(g_framework->GetCurrentViewport());
    g_framework->MakeFrameActive();
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: Initial render invalidation posted");
    
    // Kick-start the render loop by posting initial MakeFrameActive calls.
    // Without this, the DrapeEngine may not start rendering until user interaction.
    // We post a few delayed calls to ensure initial tiles are requested and rendered.
    for (int i = 0; i < 5; ++i) {
        std::thread([delay = i * 100]() {
            usleep(delay * 1000);  // delay in milliseconds
            if (g_framework && g_drapeEngineCreated) {
                g_framework->MakeFrameActive();
            }
        }).detach();
    }
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "createDrapeEngine: Posted initial MakeFrameActive calls");
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeSetSurface(
    JNIEnv* env, jobject thiz, jlong textureId, jobject surface, jint width, jint height, jfloat density) {
    
    ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeSetSurface: textureId=%ld, window=%p, size=%dx%d, density=%.2f", 
        textureId, window, width, height, density);
    
    if (!g_platformInitialized) {
       __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", "Platform not initialized! Call comaps_init_paths first.");
       if (window) ANativeWindow_release(window);
       return;
    }
    
    g_surfaceWidth = width;
    g_surfaceHeight = height;
    g_density = density;

    // Create Framework on this thread if not already created
    // This ensures Framework and CreateDrapeEngine are on the same thread,
    // avoiding ThreadChecker assertion failures in BookmarkManager etc.
    if (!g_framework) {
        __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "nativeSetSurface: Creating Framework...");
        
        FrameworkParams params;
        params.m_enableDiffs = false;
        params.m_numSearchAPIThreads = 1;
        
        // Create framework, defer map loading
        g_framework = std::make_unique<Framework>(params, false /* loadMaps */);
        
        __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "nativeSetSurface: Framework created");
        
        // Now register maps
        g_framework->RegisterAllMaps();
        __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "nativeSetSurface: Maps registered");
    }

    // Create the OGL context factory with the native window
    auto oglFactory = new agus::AgusOGLContextFactory(window);
    if (!oglFactory->IsValid()) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", "nativeSetSurface: Invalid OGL context");
        delete oglFactory;
        return;
    }
    
    // Update surface size from what we received (ANativeWindow might report different size)
    oglFactory->UpdateSurfaceSize(width, height);
    
    // Wrap our context factory in ThreadSafeFactory for thread-safe context creation
    g_factory = make_unique_dp<dp::ThreadSafeFactory>(oglFactory);
    
    // Create DrapeEngine with proper dimensions
    createDrapeEngineIfNeeded(width, height, density);
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeOnSurfaceChanged(
    JNIEnv* env, jobject thiz, jlong textureId, jobject surface, jint width, jint height, jfloat density) {
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeOnSurfaceChanged: size=%dx%d", width, height);
    
    ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
    
    g_surfaceWidth = width;
    g_surfaceHeight = height;
    g_density = density;
    
    if (g_factory && g_framework) {
        // Re-enable rendering with new surface
        auto* rawFactory = static_cast<dp::ThreadSafeFactory*>(g_factory.get());
        if (rawFactory) {
            // Get the underlying factory and reset surface
            // Note: This is a simplified approach - may need more work for proper surface recreation
            g_framework->SetRenderingEnabled(make_ref(g_factory));
            g_framework->OnSize(width, height);
        }
    }
    
    if (window) ANativeWindow_release(window);
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeOnSurfaceDestroyed(JNIEnv* env, jobject thiz) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "nativeOnSurfaceDestroyed");
    
    if (g_framework) {
        g_framework->SetRenderingDisabled(true /* destroySurface */);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeOnSizeChanged(
    JNIEnv* env, jobject thiz, jint width, jint height) {
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeOnSizeChanged: %dx%d", width, height);
    
    g_surfaceWidth = width;
    g_surfaceHeight = height;
    
    if (g_framework && g_drapeEngineCreated) {
        g_framework->OnSize(width, height);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeSetVisualScale(
    JNIEnv* env, jobject thiz, jfloat density) {
    if (density <= 0) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative",
            "nativeSetVisualScale: invalid density %.2f", density);
        return;
    }

    g_density = density;

    if (g_framework && g_drapeEngineCreated) {
        df::VisualParams::Instance().SetVisualScale(static_cast<double>(density));
        g_framework->InvalidateRendering();
        __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative",
            "nativeSetVisualScale: Updated visual scale to %.2f", density);
    } else {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative",
            "nativeSetVisualScale: Framework not ready, stored density %.2f", density);
    }
}

FFI_PLUGIN_EXPORT void comaps_set_view(double lat, double lon, int zoom) {
     __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_set_view: lat=%f, lon=%f, zoom=%d", lat, lon, zoom);
     if (g_framework) {
         g_framework->SetViewportCenter(m2::PointD(mercator::FromLatLon(lat, lon)), zoom);
         // Force invalidate to ensure tiles reload
         g_framework->InvalidateRect(g_framework->GetCurrentViewport());
     }
}

FFI_PLUGIN_EXPORT void comaps_invalidate(void) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_invalidate");
    if (g_framework) {
        g_framework->InvalidateRect(g_framework->GetCurrentViewport());
    }
}

FFI_PLUGIN_EXPORT void comaps_force_redraw(void) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "comaps_force_redraw - triggering full tile reload");
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

// Touch event types matching df::TouchEvent::ETouchType
// 0 = TOUCH_NONE, 1 = TOUCH_DOWN, 2 = TOUCH_MOVE, 3 = TOUCH_UP, 4 = TOUCH_CANCEL
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
    // This is the preferred method for scroll wheel zoom on desktop platforms
    g_framework->Scale(factor, m2::PointD(pixelX, pixelY), animated != 0);
}

FFI_PLUGIN_EXPORT void comaps_scroll(double distanceX, double distanceY) {
    if (!g_framework || !g_drapeEngineCreated) {
        return;
    }
    
    // Scroll the map by the given distance
    g_framework->Scroll(distanceX, distanceY);
}

// Register a single MWM map file directly by full path.
// This bypasses the version folder scanning and registers the map file
// directly with the rendering engine using LocalCountryFile::MakeTemporary.
FFI_PLUGIN_EXPORT int comaps_register_single_map(const char* fullPath) {
    return comaps_register_single_map_with_version(fullPath, 0 /* version */);
}

FFI_PLUGIN_EXPORT int comaps_register_single_map_with_version(const char* fullPath, int64_t version) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative",
        "comaps_register_single_map_with_version: %s (version=%lld)",
        fullPath, static_cast<long long>(version));

    if (!g_framework) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative",
            "comaps_register_single_map_with_version: Framework not initialized");
        return -1;  // Error: Framework not ready
    }

    try {
        std::string path(fullPath ? fullPath : "");
        if (path.empty()) {
            __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative",
                "comaps_register_single_map_with_version: Empty path");
            return -2;
        }

        // Derive country name from filename (without extension), matching MakeTemporary().
        auto name = path;
        base::GetNameFromFullPath(name);
        base::GetNameWithoutExt(name);

        platform::LocalCountryFile file(base::GetDirectory(path), platform::CountryFile(std::move(name)), version);
        file.SyncWithDisk();

        auto result = g_framework->RegisterMap(file);
        if (result.second == MwmSet::RegResult::Success) {
            __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative",
                "comaps_register_single_map_with_version: Successfully registered %s", fullPath);
            return 0;  // Success
        } else {
            __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative",
                "comaps_register_single_map_with_version: Failed to register %s, result=%d",
                fullPath, static_cast<int>(result.second));
            return static_cast<int>(result.second);
        }
    } catch (std::exception const & e) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative",
            "comaps_register_single_map_with_version: Exception: %s", e.what());
        return -2;  // Error: Exception
    }
}

// Debug function to list all registered MWMs and their bounds
FFI_PLUGIN_EXPORT void comaps_debug_list_mwms() {
    __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
        "=== DEBUG: Listing all registered MWMs ===");
    
    if (!g_framework) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
            "comaps_debug_list_mwms: Framework not initialized");
        return;
    }
    
    auto const & dataSource = g_framework->GetDataSource();
    std::vector<std::shared_ptr<MwmInfo>> mwms;
    dataSource.GetMwmsInfo(mwms);
    
    __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
        "Total registered MWMs: %zu", mwms.size());
    
    for (auto const & info : mwms) {
        auto const & bounds = info->m_bordersRect;
        const char* typeStr = "UNKNOWN";
        switch (info->GetType()) {
            case MwmInfo::COUNTRY: typeStr = "COUNTRY"; break;
            case MwmInfo::COASTS: typeStr = "COASTS"; break;
            case MwmInfo::WORLD: typeStr = "WORLD"; break;
        }
        
        __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
            "  MWM: %s [%s] version=%lld scales=[%d-%d] bounds=[%.4f,%.4f - %.4f,%.4f] status=%d",
            info->GetCountryName().c_str(),
            typeStr,
            static_cast<long long>(info->GetVersion()),
            info->m_minScale,
            info->m_maxScale,
            bounds.minX(), bounds.minY(),
            bounds.maxX(), bounds.maxY(),
            static_cast<int>(info->GetStatus()));
    }
    
    __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
        "=== END MWM list ===");
}

// Debug function to check if a point is covered by any MWM
FFI_PLUGIN_EXPORT void comaps_debug_check_point(double lat, double lon) {
    __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
        "=== DEBUG: Checking point coverage lat=%.6f, lon=%.6f ===", lat, lon);
    
    if (!g_framework) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
            "comaps_debug_check_point: Framework not initialized");
        return;
    }
    
    // Convert to Mercator coordinates (what the engine uses internally)
    m2::PointD const pt = mercator::FromLatLon(lat, lon);
    __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
        "Mercator coords: x=%.6f, y=%.6f", pt.x, pt.y);
    
    auto const & dataSource = g_framework->GetDataSource();
    std::vector<std::shared_ptr<MwmInfo>> mwms;
    dataSource.GetMwmsInfo(mwms);
    
    int coveringCount = 0;
    for (auto const & info : mwms) {
        if (info->m_bordersRect.IsPointInside(pt)) {
            coveringCount++;
            __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
                "  COVERS: %s [scales %d-%d]",
                info->GetCountryName().c_str(),
                info->m_minScale, info->m_maxScale);
        }
    }
    
    if (coveringCount == 0) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", 
            "  NO MWM covers this point!");
    } else {
        __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
            "Point covered by %d MWMs", coveringCount);
    }
    
    __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
        "=== END point check ===");
}

FFI_PLUGIN_EXPORT void comaps_set_map_style(int style) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "comaps_set_map_style: style=%d", style);
    
    if (!g_framework) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", 
            "comaps_set_map_style: Framework not initialized");
        return;
    }
    
    // Validate style value
    if (style < 0 || style >= MapStyleCount) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
            "comaps_set_map_style: Invalid style value %d", style);
        return;
    }
    
    MapStyle mapStyle = static_cast<MapStyle>(style);
    g_framework->SetMapStyle(mapStyle);
    
    // Force redraw to apply new style
    g_framework->InvalidateRendering();
    g_framework->InvalidateRect(g_framework->GetCurrentViewport());
    
    __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
        "comaps_set_map_style: Style changed to %d", style);
}

FFI_PLUGIN_EXPORT int comaps_get_map_style(void) {
    if (!g_framework) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", 
            "comaps_get_map_style: Framework not initialized");
        return 0; // Return DefaultLight as default
    }
    
    MapStyle currentStyle = g_framework->GetMapStyle();
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "comaps_get_map_style: Current style=%d", static_cast<int>(currentStyle));
    
    return static_cast<int>(currentStyle);
}

// Initialize frame notification callback - called from Kotlin/Java plugin
extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeInitFrameCallback(
    JNIEnv* env, jobject thiz) {
    
    // Create global reference to plugin instance
    if (g_pluginInstance) {
        env->DeleteGlobalRef(g_pluginInstance);
    }
    g_pluginInstance = env->NewGlobalRef(thiz);
    
    // Get the method ID for onFrameReady callback
    jclass cls = env->GetObjectClass(thiz);
    g_notifyFrameReadyMethod = env->GetMethodID(cls, "onFrameReady", "()V");
    
    if (g_notifyFrameReadyMethod) {
        __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
            "nativeInitFrameCallback: Frame notification callback initialized");
    } else {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
            "nativeInitFrameCallback: Failed to find onFrameReady method");
    }

    g_onPlacePageEventMethod = env->GetMethodID(cls, "onPlacePageEvent", "(I)V");
    if (g_onPlacePageEventMethod) {
         __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
            "nativeInitFrameCallback: PlacePage event callback initialized");
    } else {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
            "nativeInitFrameCallback: Failed to find onPlacePageEvent method");
    }

    g_onMyPositionModeChangedMethod = env->GetMethodID(cls, "onMyPositionModeChanged", "(I)V");
    g_onRoutingEventMethod = env->GetMethodID(cls, "onRoutingEvent", "(II)V");
    if (g_onMyPositionModeChangedMethod) {
         __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
            "nativeInitFrameCallback: MyPositionMode change callback initialized");
    } else {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
            "nativeInitFrameCallback: Failed to find onMyPositionModeChanged method");
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeGetPlacePageInfo(
    JNIEnv* env, jobject thiz) {
    
    if (!g_framework || !g_framework->HasPlacePageInfo()) return nullptr;
    
    auto const & info = g_framework->GetCurrentPlacePageInfo();
    
    // Construct simple JSON string
    std::string json = "{";
    json += "\"title\":\"" + info.GetTitle() + "\",";
    json += "\"subtitle\":\"" + info.GetSubtitle() + "\",";
    
    auto mercator = info.GetMercator();
    auto latlon = mercator::ToLatLon(mercator);
    json += "\"lat\":" + std::to_string(latlon.m_lat) + ",";
    json += "\"lon\":" + std::to_string(latlon.m_lon);
    
    json += "}";
    
    return env->NewStringUTF(json.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeBuildRoute(
    JNIEnv* env, jobject thiz, jdouble lat, jdouble lon) {
    
    if (!g_framework) return;
    
    auto & rm = g_framework->GetRoutingManager();
    rm.RemoveRoute(true); 
    
    // Set router type to Vehicle (car) for navigation with voice guidance
    // Vehicle router has soundDirection=true in RoutingSettings
    rm.SetRouter(routing::RouterType::Vehicle);
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "Router type set to Vehicle");
    
    // Set up a one-time listener for route building completion
    rm.SetRouteBuildingListener([](routing::RouterResultCode code, storage::CountriesSet const &) {
        if (code == routing::RouterResultCode::NoError || code == routing::RouterResultCode::HasWarnings) {
            __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
                "Route built successfully, activating navigation mode");
            
            // Automatically activate navigation mode when route is ready
            if (g_framework) {
                g_framework->GetRoutingManager().FollowRoute();
                
                // Enable 3D perspective for navigation
                g_framework->Allow3dMode(true, true);
                
                // Explicitly notify Flutter about the mode change to FOLLOW_AND_ROTATE (mode 4)
                notifyMyPositionModeChanged(location::EMyPositionMode::FollowAndRotate, true);
                
                __android_log_print(ANDROID_LOG_INFO, "AgusMapsFlutterNative", 
                    "Navigation mode (FollowRoute) activated automatically with FOLLOW_AND_ROTATE mode");
            }
        } else {
            __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
                "Route building failed with code: %d", static_cast<int>(code));
        }
    });
    
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
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", "nativeBuildRoute: Route building initiated");
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeFollowRoute(
    JNIEnv* env, jobject thiz) {
    if (!g_framework) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", "nativeFollowRoute: Framework not initialized");
        return;
    }
    
    auto & rm = g_framework->GetRoutingManager();
    rm.FollowRoute();
    
    // Enable 3D perspective for navigation like in the Java app
    g_framework->Allow3dMode(true, true);
    
    // Explicitly notify Flutter about the mode change to FOLLOW_AND_ROTATE (mode 4)
    // The internal callback mechanism goes through Platform::Thread::Gui which may have
    // timing issues with Flutter's message passing. This ensures the UI updates correctly.
    // Note: FollowRoute() -> RoutingManager::FollowRoute() -> Framework::OnRouteFollow() 
    // -> DrapeEngine::FollowRoute() -> FrontendRenderer::FollowRoute() 
    // -> MyPositionController::ActivateRouting() which sets mode to FollowAndRotate
    notifyMyPositionModeChanged(location::EMyPositionMode::FollowAndRotate, true);
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeFollowRoute: Navigation mode activated with 3D perspective, notified FOLLOW_AND_ROTATE mode");
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeStopRouting(
    JNIEnv* env, jobject thiz) {
    if (!g_framework) return;
    g_framework->GetRoutingManager().CloseRouting(true);
    
    // Disable 3D perspective when stopping navigation
    g_framework->Allow3dMode(false, false);
    
    // Notify Flutter about mode change - routing deactivation transitions from
    // FollowAndRotate to Follow mode (see MyPositionController::DeactivateRouting)
    notifyMyPositionModeChanged(location::EMyPositionMode::Follow, false);
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeStopRouting: Navigation stopped, perspective reset, notified FOLLOW mode");
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeSwitchMyPositionMode(
    JNIEnv* env, jobject thiz) {
    if (!g_framework || !g_drapeEngineCreated) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", 
            "nativeSwitchMyPositionMode: Framework or DrapeEngine not ready");
        return;
    }
    
    auto currentMode = g_framework->GetMyPositionMode();
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeSwitchMyPositionMode: current mode=%d", static_cast<int>(currentMode));
    
    g_framework->SwitchMyPositionNextMode();
    
    auto newMode = g_framework->GetMyPositionMode();
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeSwitchMyPositionMode: new mode=%d", static_cast<int>(newMode));
}

extern "C" JNIEXPORT jint JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeGetMyPositionMode(
    JNIEnv* env, jobject thiz) {
    if (!g_framework || !g_drapeEngineCreated) return 0; // PENDING_POSITION
    return static_cast<jint>(g_framework->GetMyPositionMode());
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeSetMyPositionMode(
    JNIEnv* env, jobject thiz, jint mode) {
    if (!g_framework || !g_drapeEngineCreated) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", 
            "nativeSetMyPositionMode: Framework or DrapeEngine not ready");
        return;
    }
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeSetMyPositionMode: setting mode to %d", mode);
    
    // Cycle through modes until we reach the desired one
    // This is safer than directly setting the mode
    auto currentMode = g_framework->GetMyPositionMode();
    int attempts = 0;
    const int maxAttempts = 5; // Prevent infinite loop
    
    while (static_cast<int>(currentMode) != mode && attempts < maxAttempts) {
        g_framework->SwitchMyPositionNextMode();
        currentMode = g_framework->GetMyPositionMode();
        attempts++;
    }
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeSetMyPositionMode: final mode=%d after %d attempts", 
        static_cast<int>(currentMode), attempts);
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeScale(
    JNIEnv* env, jobject thiz, jdouble factor) {
    if (!g_framework) return;
    // Scale relative to center, animated
    g_framework->Scale(factor, true);
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeOnLocationUpdate(
    JNIEnv* env, jobject thiz, jdouble lat, jdouble lon, jdouble accuracy, jdouble bearing, jdouble speed, jlong time) {
    if (!g_framework) return;
    
    location::GpsInfo info;
    info.m_latitude = lat;
    info.m_longitude = lon;
    info.m_timestamp = static_cast<double>(time) / 1000.0;
    info.m_source = location::EAndroidNative;
    
    // Always set accuracy (even if 0)
    info.m_horizontalAccuracy = accuracy;
    
    // Set bearing if valid (bearing can be 0, which is valid - North)
    if (bearing >= 0.0) {
        info.m_bearing = bearing;
    }
    
    // Set speed if valid (speed can be 0, which is valid - stationary)
    if (speed >= 0.0) {
        info.m_speed = speed;
    }
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeOnLocationUpdate: lat=%.6f, lon=%.6f, accuracy=%.2f, bearing=%.2f, speed=%.2f, mode=%d", 
        lat, lon, accuracy, bearing, speed, 
        g_drapeEngineCreated ? static_cast<int>(g_framework->GetMyPositionMode()) : -1);
    
    // Send location update to framework (updates routing and visual position)
    g_framework->OnLocationUpdate(info);
    
    // Ensure the map redrawing is triggered for this location change
    if (g_drapeEngineCreated) {
        g_framework->InvalidateRendering();
        g_framework->MakeFrameActive();
    }
    
    // Also update GPS tracker (required for location tracking)
    GpsTracker::Instance().OnLocationUpdated(info);
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeOnCompassUpdate(
    JNIEnv* env, jobject thiz, jdouble bearing) {
    if (!g_framework) return;
    
    location::CompassInfo info;
    info.m_bearing = bearing;
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeOnCompassUpdate: bearing=%.2f", bearing);
    
    g_framework->OnCompassUpdate(info);
    
    // Trigger map redraw for compass update
    if (g_drapeEngineCreated) {
        g_framework->InvalidateRendering();
        g_framework->MakeFrameActive();
    }
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeSetMapStyle(
    JNIEnv* env, jobject thiz, jint styleIndex) {
    if (!g_framework) return;
    
    // 0 = Light, 1 = Dark
    MapStyle style = (styleIndex == 1) ? MapStyleDefaultDark : MapStyleDefaultLight;
    g_framework->SetMapStyle(style);
}

extern "C" JNIEXPORT jstring JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeGetCountryName(
    JNIEnv* env, jobject thiz, jdouble lat, jdouble lon) {
    if (!g_framework) return nullptr;

    auto const & infoGetter = g_framework->GetCountryInfoGetter();
    m2::PointD const pt = mercator::FromLatLon(lat, lon);
    storage::CountryId countryId = infoGetter.GetRegionCountryId(pt);
    
    return env->NewStringUTF(countryId.c_str());
}

extern "C" JNIEXPORT jint JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeCheckMapStatus(
    JNIEnv* env, jobject thiz, jdouble lat, jdouble lon) {
    
    if (!g_framework) return 0; // Undefined

    m2::PointD const pt = mercator::FromLatLon(lat, lon);
    auto const & infoGetter = g_framework->GetCountryInfoGetter();
    storage::CountryId countryId = infoGetter.GetRegionCountryId(pt);
    
    if (countryId == storage::kInvalidCountryId) return 0; // Undefined/Ocean

    storage::Status status = g_framework->GetStorage().CountryStatusEx(countryId);
    return static_cast<jint>(status);
}

// Cleanup frame notification callback
extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeCleanupFrameCallback(
    JNIEnv* env, jobject thiz) {
    
    if (g_pluginInstance) {
        env->DeleteGlobalRef(g_pluginInstance);
        g_pluginInstance = nullptr;
    }
    g_notifyFrameReadyMethod = nullptr;
    g_onPlacePageEventMethod = nullptr;
    g_onMyPositionModeChangedMethod = nullptr;
    
    // Clear the active frame callback
    df::SetActiveFrameCallback(nullptr);
    
    // Clear the mode change listener
    if (g_framework) {
        g_framework->SetMyPositionModeListener(location::TMyPositionModeChanged());
    }
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeCleanupFrameCallback: Frame notification callback cleaned up");
}

// Navigation functions

extern "C" JNIEXPORT jstring JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeGetRouteFollowingInfo(
    JNIEnv* env, jobject thiz) {
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeGetRouteFollowingInfo: Called");
    
    if (!g_framework) {
        __android_log_print(ANDROID_LOG_ERROR, "AgusMapsFlutterNative", 
            "nativeGetRouteFollowingInfo: g_framework is null");
        return nullptr;
    }
    
    RoutingManager & rm = g_framework->GetRoutingManager();
    
    if (!rm.IsRoutingActive()) {
        __android_log_print(ANDROID_LOG_WARN, "AgusMapsFlutterNative", 
            "nativeGetRouteFollowingInfo: Routing is not active");
        return nullptr;
    }
    
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeGetRouteFollowingInfo: Routing is active, getting info");
    
    routing::FollowingInfo info;
    rm.GetRouteFollowingInfo(info);
    
    // Log the raw info
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeGetRouteFollowingInfo: info.m_time=%d, info.m_speedLimitMps=%.2f, info.m_completionPercent=%.2f",
        info.m_time, info.m_speedLimitMps, info.m_completionPercent);
    
    // Create JSON string with routing info
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
    
    std::string jsonStr = json.str();
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeGetRouteFollowingInfo: JSON=%s", jsonStr.c_str());
    
    return env->NewStringUTF(jsonStr.c_str());
}

extern "C" JNIEXPORT jobjectArray JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeGenerateNotifications(
    JNIEnv* env, jobject thiz, jboolean announceStreets) {
    if (!g_framework) return nullptr;
    
    RoutingManager & rm = g_framework->GetRoutingManager();
    
    if (!rm.IsRoutingActive())
        return nullptr;
    
    std::vector<std::string> notifications;
    rm.GenerateNotifications(notifications, announceStreets);
    
    if (notifications.empty())
        return nullptr;
    
    jclass stringClass = env->FindClass("java/lang/String");
    jobjectArray result = env->NewObjectArray(notifications.size(), stringClass, nullptr);
    
    for (size_t i = 0; i < notifications.size(); ++i) {
        jstring str = env->NewStringUTF(notifications[i].c_str());
        env->SetObjectArrayElement(result, i, str);
        env->DeleteLocalRef(str);
    }
    
    return result;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeIsRouteFinished(
    JNIEnv* env, jobject thiz) {
    if (!g_framework) return JNI_FALSE;
    
    RoutingManager & rm = g_framework->GetRoutingManager();
    return rm.IsRouteFinished() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeDisableFollowing(
    JNIEnv* env, jobject thiz) {
    if (!g_framework) return;
    g_framework->GetRoutingManager().DisableFollowMode();
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeRemoveRoute(
    JNIEnv* env, jobject thiz) {
    if (!g_framework) return;
    g_framework->GetRoutingManager().RemoveRoute(true /* deactivateFollowing */);
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeSetTurnNotificationsLocale(
    JNIEnv* env, jobject thiz, jstring locale) {
    if (!g_framework) return;
    
    const char* localeStr = env->GetStringUTFChars(locale, nullptr);
    if (localeStr) {
        g_framework->GetRoutingManager().SetTurnNotificationsLocale(localeStr);
        __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
            "nativeSetTurnNotificationsLocale: %s", localeStr);
        env->ReleaseStringUTFChars(locale, localeStr);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeEnableTurnNotifications(
    JNIEnv* env, jobject thiz, jboolean enable) {
    if (!g_framework) return;
    
    g_framework->GetRoutingManager().EnableTurnNotifications(enable);
    __android_log_print(ANDROID_LOG_DEBUG, "AgusMapsFlutterNative", 
        "nativeEnableTurnNotifications: %d", enable);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeAreTurnNotificationsEnabled(
    JNIEnv* env, jobject thiz) {
    if (!g_framework) return JNI_FALSE;
    
    return g_framework->GetRoutingManager().AreTurnNotificationsEnabled() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_app_agus_maps_agus_1maps_1flutter_AgusMapsFlutterPlugin_nativeGetTurnNotificationsLocale(
    JNIEnv* env, jobject thiz) {
    if (!g_framework) return nullptr;
    
    std::string locale = g_framework->GetRoutingManager().GetTurnNotificationsLocale();
    return env->NewStringUTF(locale.c_str());
}
