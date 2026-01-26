# Rikera - Car Navigation App

A Flutter-based car navigation application using the CoMaps rendering engine via the agus_maps_flutter plugin.

## Project Structure

```
lib/
├── app/              # Application-level configuration
│   └── app.dart      # Main app widget with theme configuration
├── core/             # Core utilities and infrastructure
│   ├── constants/    # Application constants and enums
│   ├── di/           # Dependency injection setup
│   ├── errors/       # Error classes
│   └── utils/        # Utility classes (Result type, etc.)
├── features/         # Feature modules (to be implemented)
└── main.dart         # Application entry point
```

## Architecture

The application follows Clean Architecture principles with three distinct layers:

- **Presentation Layer**: UI screens, widgets, and state management (Blocs/Cubits)
- **Domain Layer**: Business entities, use cases, and repository interfaces
- **Data Layer**: Repository implementations, data sources, and models

## Dependencies

- **agus_maps_flutter**: Map rendering engine (CoMaps)
- **get_it**: Dependency injection
- **flutter_bloc**: State management
- **geolocator**: Location services
- **shared_preferences**: Local storage for preferences
- **path_provider**: File system paths
- **http**: HTTP client for map downloads

## Setup

1. Ensure Flutter is installed and configured
2. Run `flutter pub get` to install dependencies
3. Run `flutter analyze` to check for issues
4. Run `flutter test` to run tests

## Android Permissions

The following permissions are configured in `android/app/src/main/AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION`: For precise GPS location
- `ACCESS_COARSE_LOCATION`: For approximate location
- `INTERNET`: For map downloads
- `WRITE_EXTERNAL_STORAGE`: For saving map files (Android 12 and below)
- `READ_EXTERNAL_STORAGE`: For reading map files (Android 12 and below)
- `WAKE_LOCK`: For keeping screen on during navigation

## Running the App

```bash
# Run on connected device/emulator
flutter run

# Run in release mode
flutter run --release

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Development Status

✅ Task 1: Project Setup and Core Infrastructure - COMPLETE

- Created Flutter project with proper folder structure
- Added all required dependencies
- Set up dependency injection container
- Configured Android permissions
- Created core utilities (Result type, error classes, constants)

## Next Steps

- Implement domain layer entities and use cases
- Implement data layer repositories and data sources
- Implement presentation layer screens and state management
- Integrate agus_maps_flutter for map rendering
- Implement navigation features

## License

See LICENSE file in the root directory.
