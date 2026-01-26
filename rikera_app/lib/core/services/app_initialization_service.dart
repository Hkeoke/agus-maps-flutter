import 'dart:io';
import 'package:agus_maps_flutter/agus_maps_flutter.dart' as agus;
import 'package:agus_maps_flutter/mwm_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/data/datasources/map_engine_datasource.dart';
import 'package:rikera_app/features/map/data/datasources/map_storage_datasource.dart';
import 'package:rikera_app/features/map/domain/repositories/location_repository.dart';
import 'package:rikera_app/core/constants/app_constants.dart';

/// Service responsible for initializing the application on startup.
///
/// This service handles:
/// - CoMaps engine initialization
/// - Extraction and registration of bundled map files
/// - Location permission requests
/// - Storage path setup
class AppInitializationService {
  final MapEngineDataSource _mapEngineDataSource;
  final MapStorageDataSource _mapStorageDataSource;
  final LocationRepository _locationRepository;
  final AppLogger _logger = const AppLogger('AppInitializationService');

  AppInitializationService({
    required MapEngineDataSource mapEngineDataSource,
    required MapStorageDataSource mapStorageDataSource,
    required LocationRepository locationRepository,
  }) : _mapEngineDataSource = mapEngineDataSource,
       _mapStorageDataSource = mapStorageDataSource,
       _locationRepository = locationRepository;

  /// Initialize the application.
  ///
  /// This method should be called once during app startup, before the UI is displayed.
  /// It performs the following steps:
  /// 1. Initialize CoMaps engine with storage paths
  /// 2. Extract bundled map files (World.mwm, WorldCoasts.mwm) - but DON'T register yet
  /// 3. Request location permissions
  ///
  /// Returns list of extracted map paths if successful, empty list otherwise.
  /// Maps should be registered AFTER the map surface is created.
  Future<List<String>> initialize() async {
    try {
      _logger.info('Starting app initialization...');

      // Step 1: Get storage paths
      final storagePath = await _getStoragePath();
      _logger.info('Storage path: $storagePath');

      // Step 2: Initialize CoMaps engine
      _logger.info('Initializing CoMaps engine...');
      await _mapEngineDataSource.initializeEngine(storagePath);
      _logger.info('CoMaps engine initialized successfully');

      // Step 3: Extract bundled maps (but DON'T register yet!)
      _logger.info('Extracting bundled map files...');
      final extractedPaths = await _extractBundledMaps();
      _logger.info('Bundled maps extracted: ${extractedPaths.length} files');
      _logger.info('Maps will be registered after surface creation');

      // Step 4: Request location permissions
      _logger.info('Requesting location permissions...');
      final hasPermissions = await _locationRepository.requestPermissions();
      if (hasPermissions) {
        _logger.info('Location permissions granted');
      } else {
        _logger.warning('Location permissions denied');
      }

      _logger.info('App initialization completed successfully');
      return extractedPaths;
    } catch (e, stackTrace) {
      _logger.error(
        'App initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get the writable storage path for map data.
  Future<String> _getStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final mapsDir = Directory('${directory.path}/maps');

    // Create maps directory if it doesn't exist
    if (!await mapsDir.exists()) {
      await mapsDir.create(recursive: true);
    }

    return mapsDir.path;
  }

  /// Extract bundled map files and STORE PATHS for later registration.
  /// Maps should NOT be registered here - they must be registered AFTER
  /// the map surface is created in MapScreen._onMapReady().
  Future<List<String>> _extractBundledMaps() async {
    final extractedPaths = <String>[];
    
    // Extract each bundled map file
    for (final mapFile in AppConstants.bundledMapFiles) {
      try {
        _logger.info('Extracting $mapFile...');
        final path = await agus.extractMap('assets/maps/$mapFile');
        _logger.info('Extracted $mapFile to $path');
        
        // Verify the file exists
        final file = File(path);
        if (!await file.exists()) {
          _logger.error('Extracted file does not exist: $path');
          continue;
        }
        
        extractedPaths.add(path);

        // Record in storage if not already there
        final regionName = mapFile.replaceAll('.mwm', '');
        if (!_mapStorageDataSource.isDownloaded(regionName)) {
          final fileSize = await file.length();

          await _mapStorageDataSource.saveMapMetadata(
            MwmMetadata(
              regionName: regionName,
              snapshotVersion: 'bundled',
              fileSize: fileSize,
              downloadDate: DateTime.now(),
              filePath: path,
              isBundled: true,
            ),
          );
          _logger.info('Recorded $regionName in storage');
        }
      } catch (e) {
        _logger.error('Failed to extract $mapFile', error: e);
        // Continue with other maps even if one fails
      }
    }

    _logger.info('Bundled maps extraction completed. Extracted ${extractedPaths.length} maps.');
    return extractedPaths;
  }
}
