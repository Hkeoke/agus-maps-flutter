import 'package:get_it/get_it.dart';
import 'package:rikera_app/core/services/app_initialization_service.dart';
import 'package:rikera_app/core/services/haptic_feedback_service.dart';
import 'package:rikera_app/core/services/memory_management_service.dart';
import 'package:rikera_app/core/services/voice_guidance_service.dart';
import 'package:rikera_app/features/map/data/datasources/datasources.dart';
import 'package:rikera_app/features/map/data/repositories/repositories.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart'
    as domain_repos;
import 'package:rikera_app/features/map/domain/usecases/usecases.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/blocs/navigation_info/navigation_info_cubit.dart';
import 'package:rikera_app/features/settings/data/datasources/settings_data_source.dart';
import 'package:rikera_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:rikera_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:rikera_app/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:rikera_app/features/settings/domain/usecases/update_settings_usecase.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_bloc.dart';

/// Global service locator instance
final sl = GetIt.instance;

/// Initializes all dependencies for the application.
///
/// This should be called once at app startup before running the app.
/// Dependencies are registered in the following order:
/// 1. External services (plugins, packages)
/// 2. Data sources
/// 3. Repositories
/// 4. Use cases
/// 5. Blocs/Cubits
Future<void> initializeDependencies() async {
  // ============================================================================
  // External Services
  // ============================================================================
  // External services are initialized directly in data sources

  // Voice guidance service
  sl.registerLazySingleton<VoiceGuidanceService>(() => VoiceGuidanceService());

  // Haptic feedback service
  sl.registerLazySingleton<HapticFeedbackService>(
    () => HapticFeedbackService(),
  );

  // Memory management service
  sl.registerLazySingleton<MemoryManagementService>(
    () => MemoryManagementService(),
  );

  // ============================================================================
  // Data Sources
  // ============================================================================
  sl.registerLazySingleton<MapEngineDataSource>(() => MapEngineDataSource());

  sl.registerLazySingleton<MapDownloadDataSource>(
    () => MapDownloadDataSource(),
  );

  // MapStorageDataSource requires async initialization
  final mapStorage = await MapStorageDataSource.create();
  sl.registerLazySingleton<MapStorageDataSource>(() => mapStorage);

  sl.registerLazySingleton<LocationDataSource>(() => LocationDataSource());

  // BookmarkDataSource requires async initialization
  final bookmarkDataSource = await BookmarkDataSource.create();
  sl.registerLazySingleton<BookmarkDataSource>(() => bookmarkDataSource);

  // SettingsDataSource requires async initialization
  final settingsDataSource = await SettingsDataSource.create();
  sl.registerLazySingleton<SettingsDataSource>(() => settingsDataSource);

  // MapViewStateDataSource requires async initialization
  final mapViewStateDataSource = await MapViewStateDataSource.create();
  sl.registerLazySingleton<MapViewStateDataSource>(
    () => mapViewStateDataSource,
  );

  // SearchHistoryDataSource requires async initialization
  final searchHistoryDataSource = await SearchHistoryDataSource.create();
  sl.registerLazySingleton<SearchHistoryDataSource>(
    () => searchHistoryDataSource,
  );

  // ============================================================================
  // Repositories
  // ============================================================================
  sl.registerLazySingleton<domain_repos.RouteRepository>(
    () => RouteRepositoryImpl(mapEngineDataSource: sl()),
  );

  sl.registerLazySingleton<domain_repos.MapRepository>(
    () => MapRepositoryImpl(
      engineDataSource: sl(),
      storageDataSource: sl(),
      downloadDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<domain_repos.LocationRepository>(
    () => LocationRepositoryImpl(locationDataSource: sl()),
  );

  sl.registerLazySingleton<domain_repos.SearchRepository>(
    () => SearchRepositoryImpl(),
  );

  sl.registerLazySingleton<domain_repos.BookmarkRepository>(
    () => BookmarkRepositoryImpl(bookmarkDataSource: sl()),
  );

  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(dataSource: sl()),
  );

  sl.registerLazySingleton<domain_repos.MapViewStateRepository>(
    () => MapViewStateRepositoryImpl(sl()),
  );

  // ============================================================================
  // Use Cases
  // ============================================================================
  sl.registerLazySingleton(() => CalculateRouteUseCase(sl()));

  sl.registerLazySingleton(() => DownloadMapRegionUseCase(sl()));

  sl.registerLazySingleton(() => SearchPlacesUseCase(sl()));

  sl.registerLazySingleton(() => GetAvailableRegionsUseCase(sl()));

  sl.registerLazySingleton(() => TrackLocationUseCase(sl()));

  sl.registerLazySingleton(() => SaveBookmarkUseCase(sl()));

  sl.registerLazySingleton(() => GetBookmarksUseCase(sl()));

  sl.registerLazySingleton(() => DeleteBookmarkUseCase(sl()));

  sl.registerLazySingleton(() => GetSettingsUseCase(sl()));

  sl.registerLazySingleton(() => UpdateSettingsUseCase(sl()));

  sl.registerLazySingleton(() => SaveMapViewStateUseCase(sl()));

  sl.registerLazySingleton(() => LoadMapViewStateUseCase(sl()));

  // ============================================================================
  // Blocs/Cubits
  // ============================================================================
  sl.registerFactory(
    () => MapCubit(
      saveMapViewStateUseCase: sl(),
      loadMapViewStateUseCase: sl(),
      mapRepository: sl(),
    ),
  );

  // Simple cubit for navigation info polling - reads directly from motor
  sl.registerFactory(() => NavigationInfoCubit());

  sl.registerFactory(() => RouteBloc(calculateRouteUseCase: sl()));

  sl.registerFactory(
    () => MapDownloadBloc(
      downloadMapRegionUseCase: sl(),
      getAvailableRegionsUseCase: sl(),
      mapRepository: sl(),
    ),
  );

  sl.registerFactory(
    () => SearchBloc(searchPlacesUseCase: sl(), searchHistoryDataSource: sl()),
  );

  sl.registerFactory(() => LocationBloc(trackLocationUseCase: sl()));

  sl.registerFactory(
    () => BookmarkBloc(
      getBookmarksUseCase: sl(),
      saveBookmarkUseCase: sl(),
      deleteBookmarkUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => SettingsBloc(getSettingsUseCase: sl(), updateSettingsUseCase: sl()),
  );

  // ============================================================================
  // App Initialization Service
  // ============================================================================
  sl.registerLazySingleton<AppInitializationService>(
    () => AppInitializationService(
      mapEngineDataSource: sl(),
      mapStorageDataSource: sl(),
      locationRepository: sl(),
    ),
  );
}

/// Resets all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await sl.reset();
}
