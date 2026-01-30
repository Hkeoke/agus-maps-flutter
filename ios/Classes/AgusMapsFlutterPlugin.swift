import Flutter
import UIKit
import Metal
import CoreVideo

/// AgusMapsFlutterPlugin - Flutter plugin for CoMaps rendering on iOS
///
/// This plugin implements:
/// - FlutterPlugin for MethodChannel communication
/// - FlutterTexture for zero-copy GPU texture sharing via CVPixelBuffer
///
/// Architecture:
/// 1. Flutter requests a map surface via MethodChannel
/// 2. Plugin creates CVPixelBuffer backed by IOSurface (Metal-compatible)
/// 3. Native CoMaps engine renders to MTLTexture derived from CVPixelBuffer
/// 4. Flutter samples the texture directly (zero-copy via IOSurface)
///
/// Note: @objc(AgusMapsFlutterPlugin) gives this class a stable Objective-C name
/// that native code can use with NSClassFromString, avoiding Swift name mangling.
@objc(AgusMapsFlutterPlugin)
public class AgusMapsFlutterPlugin: NSObject, FlutterPlugin, FlutterTexture {
    
    // MARK: - Shared Instance for native callbacks
    
    /// Shared instance for native code to notify when frames are ready
    private static weak var sharedInstance: AgusMapsFlutterPlugin?
    
    // Debug: count static method calls
    private static var staticFrameCount: Int = 0
    
    /// Called by native code when a frame is ready
    @objc public static func notifyFrameReadyFromNative() {
        staticFrameCount += 1
        if staticFrameCount <= 5 || staticFrameCount % 60 == 0 {
            NSLog("[AgusMapsFlutter] Swift notifyFrameReadyFromNative called (count=%d, hasInstance=%@)", 
                  staticFrameCount, sharedInstance != nil ? "YES" : "NO")
        }
        DispatchQueue.main.async {
            sharedInstance?.notifyFrameReady()
        }
    }
    
    // MARK: - Properties
    
    private var channel: FlutterMethodChannel?
    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = -1
    
    // CVPixelBuffer for zero-copy texture sharing
    private var pixelBuffer: CVPixelBuffer?
    private var textureCache: CVMetalTextureCache?
    private var metalDevice: MTLDevice?
    
    // Surface dimensions
    private var surfaceWidth: Int = 0
    private var surfaceHeight: Int = 0
    private var density: CGFloat = 2.0
    
    // Rendering state
    private var isRenderingEnabled: Bool = false
    
    // MARK: - FlutterPlugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "agus_maps_flutter",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = AgusMapsFlutterPlugin()
        instance.channel = channel
        instance.textureRegistry = registrar.textures()
        instance.density = UIScreen.main.scale
        
        // Store shared instance for native callbacks
        AgusMapsFlutterPlugin.sharedInstance = instance
        
        // Initialize Metal device
        instance.metalDevice = MTLCreateSystemDefaultDevice()
        if instance.metalDevice == nil {
            NSLog("[AgusMapsFlutter] Warning: Metal device not available")
        }
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        NSLog("[AgusMapsFlutter] Plugin registered, density=%.2f", instance.density)
    }
    
    // MARK: - FlutterTexture Protocol
    
    /// Called by Flutter engine to get the current frame's pixel buffer
    /// This is the zero-copy path - Flutter samples directly from our CVPixelBuffer
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBuffer else {
            return nil
        }
        return Unmanaged.passRetained(buffer)
    }
    
    /// Called when texture is about to be rendered
    public func onTextureUnregistered(_ texture: FlutterTexture) {
        NSLog("[AgusMapsFlutter] Texture unregistered")
        cleanupTexture()
    }
    
    // MARK: - MethodChannel Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "extractMap":
            handleExtractMap(call: call, result: result)
            
        case "extractDataFiles":
            handleExtractDataFiles(result: result)
            
        case "getApkPath":
            // iOS equivalent: main bundle resource path
            result(Bundle.main.resourcePath)
            
        case "createMapSurface":
            handleCreateMapSurface(call: call, result: result)
            
        case "resizeMapSurface":
            handleResizeMapSurface(call: call, result: result)
            
        case "destroyMapSurface":
            handleDestroyMapSurface(result: result)
            
        case "checkMapStatus":
            handleCheckMapStatus(call: call, result: result)
            
        case "getPlacePageInfo":
            handleGetPlacePageInfo(result: result)
            
        case "buildRoute":
            handleBuildRoute(call: call, result: result)
            
        case "stopRouting":
            handleStopRouting(result: result)
            
        case "switchMyPositionMode":
            handleSwitchMyPositionMode(result: result)
            
        case "getMyPositionMode":
            handleGetMyPositionMode(result: result)
            
        case "setMyPositionMode":
            handleSetMyPositionMode(call: call, result: result)
            
        case "scale":
            handleScale(call: call, result: result)
            
        case "onLocationUpdate":
            handleOnLocationUpdate(call: call, result: result)
            
        case "onCompassUpdate":
            handleOnCompassUpdate(call: call, result: result)
            
        case "setMapStyle":
            handleSetMapStyle(call: call, result: result)
            
        case "getCountryName":
            handleGetCountryName(call: call, result: result)
            
        case "getRouteFollowingInfo":
            handleGetRouteFollowingInfo(result: result)
            
        case "generateNotifications":
            handleGenerateNotifications(call: call, result: result)
            
        case "isRouteFinished":
            handleIsRouteFinished(result: result)
            
        case "disableFollowing":
            handleDisableFollowing(result: result)
            
        case "removeRoute":
            handleRemoveRoute(result: result)
            
        case "followRoute":
            handleFollowRoute(result: result)
            
        case "setTurnNotificationsLocale":
            handleSetTurnNotificationsLocale(call: call, result: result)
            
        case "enableTurnNotifications":
            handleEnableTurnNotifications(call: call, result: result)
            
        case "areTurnNotificationsEnabled":
            handleAreTurnNotificationsEnabled(result: result)
            
        case "getTurnNotificationsLocale":
            handleGetTurnNotificationsLocale(result: result)
            
        case "search":
            handleSearch(call: call, result: result)
            
        case "cancelSearch":
            handleCancelSearch(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Map Asset Extraction
    
    private func handleExtractMap(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let assetPath = args["assetPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "assetPath is required", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let extractedPath = try self.extractMapAsset(assetPath: assetPath)
                DispatchQueue.main.async {
                    result(extractedPath)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "EXTRACTION_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func extractMapAsset(assetPath: String) throws -> String {
        NSLog("[AgusMapsFlutter] Extracting asset: %@", assetPath)
        
        // Get the Flutter asset path
        let flutterAssetPath = lookupKeyForAsset(assetPath)
        
        guard let bundlePath = Bundle.main.path(forResource: flutterAssetPath, ofType: nil) else {
            throw NSError(domain: "AgusMapsFlutter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Asset not found: \(assetPath)"
            ])
        }
        
        // Destination in Documents directory
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = (assetPath as NSString).lastPathComponent
        let destPath = documentsDir.appendingPathComponent(fileName)
        
        // Check if already extracted
        if FileManager.default.fileExists(atPath: destPath.path) {
            NSLog("[AgusMapsFlutter] Map already exists at: %@", destPath.path)
            return destPath.path
        }
        
        // Copy file
        try FileManager.default.copyItem(atPath: bundlePath, toPath: destPath.path)
        
        // Disable iCloud backup for map files
        var url = destPath
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)
        
        NSLog("[AgusMapsFlutter] Map extracted to: %@", destPath.path)
        return destPath.path
    }
    
    private func handleExtractDataFiles(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let dataPath = try self.extractDataFiles()
                DispatchQueue.main.async {
                    result(dataPath)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "EXTRACTION_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func extractDataFiles() throws -> String {
        NSLog("[AgusMapsFlutter] Extracting CoMaps data files...")
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let markerFile = documentsDir.appendingPathComponent(".comaps_data_extracted")
        
        // Essential files that must exist for CoMaps to work
        let essentialFiles = [
            "classificator.txt",
            "types.txt", 
            "categories.txt",
            "visibility.txt",
            "symbols/xxhdpi/light/symbols.sdf",  // Symbol textures required for rendering
            "symbols/xxhdpi/dark/symbols.sdf"
        ]
        
        // Check if already extracted AND essential files exist
        var needsExtraction = !FileManager.default.fileExists(atPath: markerFile.path)
        if !needsExtraction {
            // Verify essential files exist
            for file in essentialFiles {
                let filePath = documentsDir.appendingPathComponent(file).path
                if !FileManager.default.fileExists(atPath: filePath) {
                    NSLog("[AgusMapsFlutter] Essential file missing: %@, forcing re-extraction", file)
                    needsExtraction = true
                    // Remove marker to force full re-extraction
                    try? FileManager.default.removeItem(atPath: markerFile.path)
                    break
                }
            }
        }
        
        if !needsExtraction {
            NSLog("[AgusMapsFlutter] Data already extracted at: %@", documentsDir.path)
            return documentsDir.path
        }
        
        // Extract data files from bundle's comaps_data directory
        let dataAssetPath = lookupKeyForAsset("assets/comaps_data")
        if let bundleDataPath = Bundle.main.resourcePath?.appending("/\(dataAssetPath)"),
           FileManager.default.fileExists(atPath: bundleDataPath) {
            NSLog("[AgusMapsFlutter] Extracting from bundle path: %@", bundleDataPath)
            try extractDirectory(from: bundleDataPath, to: documentsDir.path)
        } else {
            NSLog("[AgusMapsFlutter] WARNING: Bundle data path not found!")
        }
        
        // Verify extraction was successful
        for file in essentialFiles {
            let filePath = documentsDir.appendingPathComponent(file).path
            if !FileManager.default.fileExists(atPath: filePath) {
                NSLog("[AgusMapsFlutter] WARNING: Essential file still missing after extraction: %@", file)
            } else {
                NSLog("[AgusMapsFlutter] Verified: %@", file)
            }
        }
        
        // Create marker file
        FileManager.default.createFile(atPath: markerFile.path, contents: nil, attributes: nil)
        
        NSLog("[AgusMapsFlutter] Data files extracted to: %@", documentsDir.path)
        return documentsDir.path
    }
    
    private func extractDirectory(from sourcePath: String, to destPath: String) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: sourcePath)
        
        for item in contents {
            let sourceItem = (sourcePath as NSString).appendingPathComponent(item)
            let destItem = (destPath as NSString).appendingPathComponent(item)
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: sourceItem, isDirectory: &isDir) {
                if isDir.boolValue {
                    try fileManager.createDirectory(atPath: destItem, withIntermediateDirectories: true)
                    try extractDirectory(from: sourceItem, to: destItem)
                } else {
                    if !fileManager.fileExists(atPath: destItem) {
                        try fileManager.copyItem(atPath: sourceItem, toPath: destItem)
                    }
                }
            }
        }
    }
    
    // MARK: - Map Surface Management
    
    private func handleCreateMapSurface(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        if let densityArg = args?["density"] as? Double, densityArg > 0 {
            density = CGFloat(densityArg)
        }
        
        // Get requested size or use screen size
        var width = args?["width"] as? Int ?? 0
        var height = args?["height"] as? Int ?? 0
        
        if width <= 0 || height <= 0 {
            let screenSize = UIScreen.main.bounds.size
            let screenScale = UIScreen.main.scale
            width = Int(screenSize.width * screenScale)
            height = Int(screenSize.height * screenScale)
        }
        
        surfaceWidth = width
        surfaceHeight = height
        
        NSLog("[AgusMapsFlutter] createMapSurface: %dx%d density=%.2f", width, height, density)
        
        // Create CVPixelBuffer for texture sharing
        do {
            try createPixelBuffer(width: width, height: height)
            
            // Register texture with Flutter
            guard let registry = textureRegistry else {
                result(FlutterError(code: "NO_REGISTRY", message: "Texture registry not available", details: nil))
                return
            }
            
            textureId = registry.register(self)
            isRenderingEnabled = true
            
            // Initialize native surface
            nativeSetSurface(textureId: textureId, width: Int32(width), height: Int32(height), density: Float(density))
            
            NSLog("[AgusMapsFlutter] Texture registered: id=%lld", textureId)
            result(textureId)
            
        } catch {
            result(FlutterError(code: "CREATE_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleResizeMapSurface(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              width > 0, height > 0 else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Valid width and height required", details: nil))
            return
        }

        let sizeUnchanged = width == surfaceWidth && height == surfaceHeight

        if let densityArg = args["density"] as? Double {
            let newDensity = CGFloat(densityArg)
            if newDensity > 0 && abs(newDensity - density) > .ulpOfOne {
                density = newDensity
                nativeSetVisualScale(density: Float(newDensity))
                NSLog("[AgusMapsFlutter] Updated visual scale: %.2f", newDensity)
            }
        }

        if sizeUnchanged {
            result(true)
            return
        }
        
        surfaceWidth = width
        surfaceHeight = height
        
        do {
            try createPixelBuffer(width: width, height: height)
            if let buffer = pixelBuffer {
                // Update native surface with the new CVPixelBuffer so Metal renders to the resized target
                nativeUpdateSurface(pixelBuffer: buffer, width: Int32(width), height: Int32(height))
            }
            
            // Notify Flutter of texture update
            textureRegistry?.textureFrameAvailable(textureId)
            
            result(true)
        } catch {
            result(FlutterError(code: "RESIZE_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleDestroyMapSurface(result: @escaping FlutterResult) {
        cleanupTexture()
        result(true)
    }
    
    // MARK: - CVPixelBuffer Creation (Zero-Copy)
    
    private func createPixelBuffer(width: Int, height: Int) throws {
        // Release existing buffer
        pixelBuffer = nil
        
        // Create CVPixelBuffer with Metal and IOSurface compatibility
        // This enables zero-copy texture sharing between CoMaps and Flutter
        let attrs: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        var newBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &newBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = newBuffer else {
            throw NSError(domain: "AgusMapsFlutter", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to create CVPixelBuffer: \(status)"
            ])
        }
        
        pixelBuffer = buffer
        
        // Create Metal texture cache if needed
        if textureCache == nil, let device = metalDevice {
            var cache: CVMetalTextureCache?
            let cacheStatus = CVMetalTextureCacheCreate(
                kCFAllocatorDefault,
                nil,
                device,
                nil,
                &cache
            )
            
            if cacheStatus == kCVReturnSuccess {
                textureCache = cache
            } else {
                NSLog("[AgusMapsFlutter] Warning: Failed to create Metal texture cache: %d", cacheStatus)
            }
        }
        
        NSLog("[AgusMapsFlutter] CVPixelBuffer created: %dx%d (Metal=%@, IOSurface=%@)",
              width, height,
              CVPixelBufferGetIOSurface(buffer) != nil ? "YES" : "NO",
              metalDevice != nil ? "YES" : "NO")
    }
    
    private func cleanupTexture() {
        isRenderingEnabled = false
        
        if textureId >= 0, let registry = textureRegistry {
            registry.unregisterTexture(textureId)
            textureId = -1
        }
        
        pixelBuffer = nil
        
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
        textureCache = nil
        
        nativeOnSurfaceDestroyed()
        
        NSLog("[AgusMapsFlutter] Texture cleaned up")
    }
    
    // MARK: - Rendering
    
    // Debug: count instance frame notifications
    private var instanceFrameCount: Int = 0
    
    /// Called by native code when a new frame is ready
    @objc public func notifyFrameReady() {
        instanceFrameCount += 1
        if instanceFrameCount <= 5 || instanceFrameCount % 60 == 0 {
            NSLog("[AgusMapsFlutter] Swift notifyFrameReady instance method (count=%d, enabled=%@, textureId=%lld)", 
                  instanceFrameCount, isRenderingEnabled ? "YES" : "NO", textureId)
        }
        guard isRenderingEnabled, textureId >= 0 else { return }
        textureRegistry?.textureFrameAvailable(textureId)
    }
    
    /// Get the Metal texture from current CVPixelBuffer (for native rendering)
    @objc public func getMetalTexture() -> MTLTexture? {
        guard let buffer = pixelBuffer,
              let cache = textureCache else {
            return nil
        }
        
        var cvMetalTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            buffer,
            nil,
            .bgra8Unorm,
            surfaceWidth,
            surfaceHeight,
            0,
            &cvMetalTexture
        )
        
        guard status == kCVReturnSuccess, let metalTexture = cvMetalTexture else {
            NSLog("[AgusMapsFlutter] Failed to create Metal texture: %d", status)
            return nil
        }
        
        return CVMetalTextureGetTexture(metalTexture)
    }
    
    // MARK: - Native Bridge (C FFI)
    
    private func nativeSetSurface(textureId: Int64, width: Int32, height: Int32, density: Float) {
        guard let buffer = pixelBuffer else {
            NSLog("[AgusMapsFlutter] nativeSetSurface: no pixel buffer available")
            return
        }
        
        // Call the native C function to set up the rendering surface
        agus_native_set_surface(textureId, buffer, width, height, density)
        
        NSLog("[AgusMapsFlutter] nativeSetSurface complete: texture=%lld, %dx%d, density=%.2f",
              textureId, width, height, density)
    }
    
    private func nativeOnSizeChanged(width: Int32, height: Int32) {
        agus_native_on_size_changed(width, height)
    }
    
    private func nativeOnSurfaceDestroyed() {
        agus_native_on_surface_destroyed()
    }

    private func nativeUpdateSurface(pixelBuffer: CVPixelBuffer, width: Int32, height: Int32) {
        agus_native_update_surface(pixelBuffer, width, height)
    }

    private func nativeSetVisualScale(density: Float) {
        agus_native_set_visual_scale(density)
    }
    
    // MARK: - Map Status & Info Methods
    
    private func handleCheckMapStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lat = args["lat"] as? Double,
              let lon = args["lon"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "lat/lon required", details: nil))
            return
        }
        
        let status = agus_native_check_map_status(lat, lon)
        result(Int(status))
    }
    
    private func handleGetPlacePageInfo(result: @escaping FlutterResult) {
        if let jsonString = agus_native_get_place_page_info() {
            result(String(cString: jsonString))
        } else {
            result(nil)
        }
    }
    
    private func handleGetCountryName(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lat = args["lat"] as? Double,
              let lon = args["lon"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "lat/lon required", details: nil))
            return
        }
        
        if let countryName = agus_native_get_country_name(lat, lon) {
            result(String(cString: countryName))
        } else {
            result(nil)
        }
    }
    
    // MARK: - Routing Methods
    
    private func handleBuildRoute(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lat = args["lat"] as? Double,
              let lon = args["lon"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "lat/lon required", details: nil))
            return
        }
        
        agus_native_build_route(lat, lon)
        result(nil)
    }
    
    private func handleStopRouting(result: @escaping FlutterResult) {
        agus_native_stop_routing()
        result(nil)
    }
    
    private func handleGetRouteFollowingInfo(result: @escaping FlutterResult) {
        if let jsonString = agus_native_get_route_following_info() {
            result(String(cString: jsonString))
        } else {
            result(nil)
        }
    }
    
    private func handleGenerateNotifications(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let announceStreets = args?["announceStreets"] as? Bool ?? true
        
        // Get notifications array from native
        var count: Int32 = 0
        if let notifications = agus_native_generate_notifications(announceStreets, &count) {
            var notificationArray: [String] = []
            for i in 0..<Int(count) {
                if let notification = notifications[i] {
                    notificationArray.append(String(cString: notification))
                }
            }
            result(notificationArray)
        } else {
            result([])
        }
    }
    
    private func handleIsRouteFinished(result: @escaping FlutterResult) {
        let finished = agus_native_is_route_finished()
        result(finished)
    }
    
    private func handleDisableFollowing(result: @escaping FlutterResult) {
        agus_native_disable_following()
        result(nil)
    }
    
    private func handleRemoveRoute(result: @escaping FlutterResult) {
        agus_native_remove_route()
        result(nil)
    }
    
    private func handleFollowRoute(result: @escaping FlutterResult) {
        agus_native_follow_route()
        result(nil)
    }
    
    private func handleSetTurnNotificationsLocale(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let locale = args["locale"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "locale required", details: nil))
            return
        }
        
        agus_native_set_turn_notifications_locale(locale)
        result(nil)
    }
    
    private func handleEnableTurnNotifications(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enable = args["enable"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "enable required", details: nil))
            return
        }
        
        agus_native_enable_turn_notifications(enable)
        result(nil)
    }
    
    private func handleAreTurnNotificationsEnabled(result: @escaping FlutterResult) {
        let enabled = agus_native_are_turn_notifications_enabled()
        result(enabled)
    }
    
    private func handleGetTurnNotificationsLocale(result: @escaping FlutterResult) {
        if let locale = agus_native_get_turn_notifications_locale() {
            result(String(cString: locale))
        } else {
            result(nil)
        }
    }
    
    // MARK: - Position & Location Methods
    
    private func handleSwitchMyPositionMode(result: @escaping FlutterResult) {
        agus_native_switch_my_position_mode()
        result(nil)
    }
    
    private func handleGetMyPositionMode(result: @escaping FlutterResult) {
        let mode = agus_native_get_my_position_mode()
        result(Int(mode))
    }
    
    private func handleSetMyPositionMode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let mode = args["mode"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "mode required", details: nil))
            return
        }
        
        agus_native_set_my_position_mode(Int32(mode))
        result(nil)
    }
    
    private func handleOnLocationUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lat = args["lat"] as? Double,
              let lon = args["lon"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "lat/lon required", details: nil))
            return
        }
        
        let accuracy = args["accuracy"] as? Double ?? 0.0
        let bearing = args["bearing"] as? Double ?? 0.0
        let speed = args["speed"] as? Double ?? 0.0
        let time = args["time"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        
        agus_native_on_location_update(lat, lon, accuracy, bearing, speed, time)
        result(nil)
    }
    
    private func handleOnCompassUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bearing = args["bearing"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "bearing required", details: nil))
            return
        }
        
        agus_native_on_compass_update(bearing)
        result(nil)
    }
    
    // MARK: - Map Control Methods
    
    private func handleScale(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let factor = args["factor"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "factor required", details: nil))
            return
        }
        
        agus_native_scale(factor)
        result(nil)
    }
    
    private func handleSetMapStyle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let style = args["style"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "style required", details: nil))
            return
        }
        
        agus_native_set_map_style(Int32(style))
        result(nil)
    }
    
    // MARK: - Search Methods
    
    private func handleSearch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let query = args["query"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "query required", details: nil))
            return
        }
        
        let lat = args["lat"] as? Double ?? 0.0
        let lon = args["lon"] as? Double ?? 0.0
        
        // Store result callback for async search results
        searchResultCallback = result
        
        // Execute search
        agus_native_search(query, lat, lon)
    }
    
    private func handleCancelSearch(result: @escaping FlutterResult) {
        agus_native_cancel_search()
        result(nil)
    }
    
    // Search result callback storage
    private var searchResultCallback: FlutterResult?
    
    /// Called by native code when search results are available
    @objc public func onSearchResults(_ results: [[String: Any]]) {
        DispatchQueue.main.async { [weak self] in
            guard let callback = self?.searchResultCallback else { return }
            callback(results)
            self?.searchResultCallback = nil
        }
    }
    
    /// Called by native code when PlacePage event occurs
    @objc public func onPlacePageEvent(_ eventType: Int32) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onPlacePageEvent", arguments: Int(eventType))
        }
    }
    
    /// Called by native code when My Position mode changes
    @objc public func onMyPositionModeChanged(_ mode: Int32) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onMyPositionModeChanged", arguments: Int(mode))
        }
    }
    
    /// Called by native code when routing event occurs
    @objc public func onRoutingEvent(_ eventType: Int32, code: Int32) {
        DispatchQueue.main.async { [weak self] in
            let args: [String: Int] = ["type": Int(eventType), "code": Int(code)]
            self?.channel?.invokeMethod("onRoutingEvent", arguments: args)
        }
    }
    
    // MARK: - Helpers
    
    private func lookupKeyForAsset(_ asset: String) -> String {
        // Use Flutter's built-in asset key lookup
        return FlutterDartProject.lookupKey(forAsset: asset)
    }
}

// MARK: - Native C Function Declarations

@_silgen_name("agus_native_check_map_status")
func agus_native_check_map_status(_ lat: Double, _ lon: Double) -> Int32

@_silgen_name("agus_native_get_place_page_info")
func agus_native_get_place_page_info() -> UnsafePointer<CChar>?

@_silgen_name("agus_native_build_route")
func agus_native_build_route(_ lat: Double, _ lon: Double)

@_silgen_name("agus_native_stop_routing")
func agus_native_stop_routing()

@_silgen_name("agus_native_switch_my_position_mode")
func agus_native_switch_my_position_mode()

@_silgen_name("agus_native_get_my_position_mode")
func agus_native_get_my_position_mode() -> Int32

@_silgen_name("agus_native_set_my_position_mode")
func agus_native_set_my_position_mode(_ mode: Int32)

@_silgen_name("agus_native_scale")
func agus_native_scale(_ factor: Double)

@_silgen_name("agus_native_on_location_update")
func agus_native_on_location_update(_ lat: Double, _ lon: Double, _ accuracy: Double, _ bearing: Double, _ speed: Double, _ time: Int64)

@_silgen_name("agus_native_on_compass_update")
func agus_native_on_compass_update(_ bearing: Double)

@_silgen_name("agus_native_set_map_style")
func agus_native_set_map_style(_ style: Int32)

@_silgen_name("agus_native_get_country_name")
func agus_native_get_country_name(_ lat: Double, _ lon: Double) -> UnsafePointer<CChar>?

@_silgen_name("agus_native_get_route_following_info")
func agus_native_get_route_following_info() -> UnsafePointer<CChar>?

@_silgen_name("agus_native_generate_notifications")
func agus_native_generate_notifications(_ announceStreets: Bool, _ count: UnsafeMutablePointer<Int32>) -> UnsafeMutablePointer<UnsafePointer<CChar>?>?

@_silgen_name("agus_native_is_route_finished")
func agus_native_is_route_finished() -> Bool

@_silgen_name("agus_native_disable_following")
func agus_native_disable_following()

@_silgen_name("agus_native_remove_route")
func agus_native_remove_route()

@_silgen_name("agus_native_follow_route")
func agus_native_follow_route()

@_silgen_name("agus_native_set_turn_notifications_locale")
func agus_native_set_turn_notifications_locale(_ locale: String)

@_silgen_name("agus_native_enable_turn_notifications")
func agus_native_enable_turn_notifications(_ enable: Bool)

@_silgen_name("agus_native_are_turn_notifications_enabled")
func agus_native_are_turn_notifications_enabled() -> Bool

@_silgen_name("agus_native_get_turn_notifications_locale")
func agus_native_get_turn_notifications_locale() -> UnsafePointer<CChar>?

@_silgen_name("agus_native_search")
func agus_native_search(_ query: String, _ lat: Double, _ lon: Double)

@_silgen_name("agus_native_cancel_search")
func agus_native_cancel_search()
