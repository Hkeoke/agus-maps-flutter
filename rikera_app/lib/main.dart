import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'core/di/injection_container.dart';
import 'core/services/app_initialization_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (portrait and landscape for car use)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize dependency injection
  await initializeDependencies();

  // Initialize the app (CoMaps engine, bundled maps, permissions)
  final initService = sl<AppInitializationService>();
  final extractedMapPaths = await initService.initialize();

  if (extractedMapPaths.isEmpty) {
    debugPrint('Warning: No maps were extracted. Map may not display correctly.');
  } else {
    debugPrint('Extracted ${extractedMapPaths.length} bundled maps');
  }

  // Run the app with extracted map paths
  runApp(RikeraApp(bundledMapPaths: extractedMapPaths));
}
