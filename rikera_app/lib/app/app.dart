import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/di/injection_container.dart';
import 'package:rikera_app/core/services/memory_management_service.dart';
import 'package:rikera_app/core/theme/app_theme.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/screens/screens.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_event.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_state.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart'
    as settings_entities;

/// The root widget of the Rikera application.
///
/// This widget sets up the MaterialApp with theme configuration,
/// routing, and other app-wide settings. It also handles app lifecycle
/// events to manage location tracking and navigation appropriately.
///
/// Requirements: 6.1
class RikeraApp extends StatefulWidget {
  final List<String> bundledMapPaths;
  
  const RikeraApp({
    super.key,
    required this.bundledMapPaths,
  });

  @override
  State<RikeraApp> createState() => _RikeraAppState();
}

class _RikeraAppState extends State<RikeraApp> with WidgetsBindingObserver {
  late final MemoryManagementService _memoryManagementService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _memoryManagementService = sl<MemoryManagementService>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground - resume location tracking if needed
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        // App moved to background - pause location tracking if not navigating
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No action needed for these states
        break;
    }
  }

  /// Handles app resuming from background.
  ///
  /// Resumes location tracking if it was active before backgrounding.
  ///
  /// Requirements: 6.1
  void _handleAppResumed() {
    debugPrint('[RikeraApp] App resumed - checking location tracking state');
    // Location tracking will automatically resume through the LocationBloc
    // No explicit action needed as the bloc maintains its state
  }

  /// Handles app moving to background.
  ///
  /// Pauses location tracking if not actively navigating.
  /// Navigation continues in background with reduced update frequency.
  /// Releases non-essential resources to free memory.
  ///
  /// Requirements: 6.1, 11.1, 11.2, 11.3
  void _handleAppPaused() {
    debugPrint('[RikeraApp] App paused - managing location tracking');

    // Release non-essential resources to free memory
    _memoryManagementService.releaseResources();

    // Note: For now, we keep location tracking active even in background
    // In a production app, you would:
    // 1. Check if navigation is active
    // 2. If navigating, continue with background location updates
    // 3. If not navigating, pause location tracking to save battery
    // This requires platform-specific background location permissions
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<SettingsBloc>()..add(const LoadSettings()),
        ),
        BlocProvider(create: (_) => sl<MapCubit>()),
        BlocProvider(create: (_) => sl<LocationBloc>()),
        BlocProvider(create: (_) => sl<RouteBloc>()),
        BlocProvider(create: (_) => sl<SearchBloc>()),
        BlocProvider(create: (_) => sl<MapDownloadBloc>()),
        BlocProvider(create: (_) => sl<BookmarkBloc>()),
        BlocProvider(create: (_) => sl<CompassBloc>()),
        // Simple cubit for navigation info - reads directly from motor
        BlocProvider(create: (_) => sl<NavigationInfoCubit>()),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final themeMode = state is SettingsLoaded
              ? _convertThemeMode(state.settings.themeMode)
              : ThemeMode.system;

          return MaterialApp(
            title: 'Rikera',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: _ThemeAwareMapScreen(bundledMapPaths: widget.bundledMapPaths),
          );
        },
      ),
    );
  }

  /// Convert app ThemeMode to Flutter ThemeMode
  ThemeMode _convertThemeMode(settings_entities.AppThemeMode mode) {
    switch (mode) {
      case settings_entities.AppThemeMode.light:
        return ThemeMode.light;
      case settings_entities.AppThemeMode.dark:
        return ThemeMode.dark;
      case settings_entities.AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// Wrapper widget that syncs map style with theme changes
class _ThemeAwareMapScreen extends StatefulWidget {
  final List<String> bundledMapPaths;
  
  const _ThemeAwareMapScreen({required this.bundledMapPaths});

  @override
  State<_ThemeAwareMapScreen> createState() => _ThemeAwareMapScreenState();
}

class _ThemeAwareMapScreenState extends State<_ThemeAwareMapScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sync map style with initial theme and start location tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMapStyle();
      // Start location tracking
      context.read<LocationBloc>().add(const StartTracking());
      // Inject map controller into NavigationInfoCubit
      final mapCubit = context.read<MapCubit>();
      final navInfoCubit = context.read<NavigationInfoCubit>();
      navInfoCubit.setMapController(mapCubit.mapController);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Sync map style when system theme changes
    _syncMapStyle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync map style when theme changes
    _syncMapStyle();
  }

  void _syncMapStyle() {
    final brightness = Theme.of(context).brightness;
    context.read<MapCubit>().syncMapStyle(brightness);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes to sync map style immediately
    return BlocListener<SettingsBloc, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoaded) {
          // When settings change, sync map style immediately
          _syncMapStyle();
        }
      },
      child: const MapScreen(),
    );
  }
}
