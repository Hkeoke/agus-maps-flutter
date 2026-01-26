import 'dart:async';
import 'dart:io';
import 'package:agus_maps_flutter/agus_maps_flutter.dart' as agus;
import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/map_repository.dart'
    as domain;
import 'package:rikera_app/features/map/data/datasources/map_engine_datasource.dart';
import 'package:rikera_app/features/map/data/datasources/map_storage_datasource.dart';
import 'package:rikera_app/features/map/data/datasources/map_download_datasource.dart'
    as datasource;
import 'package:path_provider/path_provider.dart';

/// Implementation of [domain.MapRepository] using CoMaps engine and storage.
///
/// This repository manages map regions, including downloading, storing,
/// registering with the engine, and validating map files.
///
/// Requirements: 3.2, 3.4, 3.6, 3.7, 11.4, 13.5
class MapRepositoryImpl implements domain.MapRepository {
  final MapEngineDataSource _engineDataSource;
  final MapStorageDataSource _storageDataSource;
  final datasource.MapDownloadDataSource _downloadDataSource;
  final AppLogger _logger = const AppLogger('MapRepository');

  MapRepositoryImpl({
    required MapEngineDataSource engineDataSource,
    required MapStorageDataSource storageDataSource,
    required datasource.MapDownloadDataSource downloadDataSource,
  }) : _engineDataSource = engineDataSource,
       _storageDataSource = storageDataSource,
       _downloadDataSource = downloadDataSource;

  @override
  Future<Result<List<MapRegion>>> getAvailableRegions() async {
    try {
      _logger.debug('Fetching available map regions');
      final mwmRegions = await _downloadDataSource.getAvailableRegions();
      _logger.info('Fetched ${mwmRegions.length} available regions');

      // Convert MwmRegion to MapRegion entities
      final regions = mwmRegions.map((mwm) {
        return MapRegion(
          id: mwm.name,
          name: mwm.name,
          fileName: mwm.fileName,
          sizeBytes: mwm.sizeBytes,
          snapshotVersion: _downloadDataSource.currentSnapshotVersion ?? '',
          bounds: RegionBounds(
            minLatitude: 0, // MwmRegion doesn't have bounds
            maxLatitude: 0,
            minLongitude: 0,
            maxLongitude: 0,
          ),
          isDownloaded: _storageDataSource.isDownloaded(mwm.name),
        );
      }).toList();

      return Result.success(regions);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch available regions',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(
        NetworkError.unknown('Failed to fetch available regions: $e'),
      );
    }
  }

  @override
  Future<Result<List<MapRegion>>> getDownloadedRegions() async {
    try {
      _logger.debug('Fetching downloaded map regions');
      final metadata = _storageDataSource.getDownloadedMaps();
      _logger.info('Found ${metadata.length} downloaded regions');

      // Convert metadata to MapRegion entities
      final regions = metadata.map((meta) {
        return MapRegion(
          id: meta.regionName,
          name: meta.regionName,
          fileName: '${meta.regionName}.mwm',
          sizeBytes: meta.fileSize,
          snapshotVersion: meta.snapshotVersion,
          bounds: RegionBounds(
            minLatitude: 0, // Bounds not stored in metadata
            maxLatitude: 0,
            minLongitude: 0,
            maxLongitude: 0,
          ),
          isDownloaded: true,
          isBundled: meta.isBundled,
          filePath: meta.filePath,
        );
      }).toList();

      return Result.success(regions);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch downloaded regions',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.readFailure());
    }
  }

  @override
  Stream<domain.DownloadProgress> downloadRegion(MapRegion region) async* {
    try {
      _logger.info('Starting download for region: ${region.name}');

      // Get the destination file path
      final appDir = await getApplicationDocumentsDirectory();
      final mapsDir = Directory('${appDir.path}/maps');
      await mapsDir.create(recursive: true);

      final destinationPath = '${mapsDir.path}/${region.fileName}';
      final destinationFile = File(destinationPath);

      // Get the MwmRegion for download
      final mwmRegions = await _downloadDataSource.getAvailableRegions();
      final mwmRegion = mwmRegions.firstWhere(
        (r) => r.name == region.id,
        orElse: () => throw Exception('Region not found: ${region.id}'),
      );

      // Stream download progress with direct-to-disk writing
      await for (final progress in _downloadDataSource.downloadRegion(
        mwmRegion,
        destinationFile,
      )) {
        // Emit progress
        yield domain.DownloadProgress(
          bytesReceived: progress.bytesReceived,
          totalBytes: progress.totalBytes,
          status: domain.DownloadStatus.downloading,
        );

        // When download completes, validate and register the map
        if (progress.bytesReceived >= progress.totalBytes &&
            progress.totalBytes > 0) {
          _logger.info('Download completed for region: ${region.name}');

          // Validate the downloaded file
          final validationResult = await _validateMapFile(
            destinationFile,
            region.sizeBytes,
          );

          if (!validationResult.isSuccess) {
            _logger.error(
              'Map file validation failed for region: ${region.name}',
            );
            // Delete the invalid file
            if (await destinationFile.exists()) {
              await destinationFile.delete();
            }

            yield domain.DownloadProgress(
              bytesReceived: 0,
              totalBytes: region.sizeBytes,
              status: domain.DownloadStatus.failed,
            );
            return;
          }

          // Save metadata
          final metadata = agus.MwmMetadata(
            regionName: region.id,
            fileSize: region.sizeBytes,
            snapshotVersion: region.snapshotVersion,
            downloadDate: DateTime.now(),
            filePath: destinationPath,
            isBundled: false,
          );

          await _storageDataSource.saveMapMetadata(metadata);
          _logger.debug('Saved metadata for region: ${region.name}');

          // Register with the engine
          final registerResult = await registerMapFile(destinationPath);
          if (!registerResult.isSuccess) {
            _logger.error(
              'Failed to register map file for region: ${region.name}',
            );
            // Registration failed, clean up
            await destinationFile.delete();
            await _storageDataSource.deleteMapMetadata(region.id);

            yield domain.DownloadProgress(
              bytesReceived: 0,
              totalBytes: region.sizeBytes,
              status: domain.DownloadStatus.failed,
            );
            return;
          }

          _logger.info(
            'Successfully downloaded and registered region: ${region.name}',
          );

          // Emit completion
          yield domain.DownloadProgress(
            bytesReceived: progress.totalBytes,
            totalBytes: progress.totalBytes,
            status: domain.DownloadStatus.completed,
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Download failed for region: ${region.name}',
        error: e,
        stackTrace: stackTrace,
      );
      yield domain.DownloadProgress(
        bytesReceived: 0,
        totalBytes: region.sizeBytes,
        status: domain.DownloadStatus.failed,
      );
    }
  }

  @override
  Future<Result<void>> deleteRegion(String regionId) async {
    try {
      _logger.info('Deleting region: $regionId');
      // Delete using the storage data source which handles both file and metadata
      final result = await _storageDataSource.deleteMapAndFile(regionId);

      if (result.success) {
        _logger.info('Successfully deleted region: $regionId');
        return Result.success(null);
      } else {
        _logger.warning('Failed to delete region: $regionId');
        return Result.failure(StorageError.writeFailure());
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error deleting region: $regionId',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.writeFailure());
    }
  }

  @override
  Future<Result<void>> registerMapFile(String filePath) async {
    try {
      // Extract version from file path or use default
      // Version format is typically YYMMDD (e.g., 251209 for Dec 9, 2025)
      final now = DateTime.now();
      final version = int.parse(
        '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
      );

      final success = await _engineDataSource.registerMap(filePath, version);

      if (success) {
        return Result.success(null);
      } else {
        return Result.failure(MapEngineError.registrationFailed(filePath));
      }
    } on MapEngineException catch (e) {
      return Result.failure(
        MapEngineError.registrationFailed('$filePath: ${e.message}'),
      );
    } catch (e) {
      return Result.failure(MapEngineError.registrationFailed('$filePath: $e'));
    }
  }

  @override
  Future<int> getTotalStorageUsed() async {
    try {
      final total = _storageDataSource.getTotalStorageUsed();
      _logger.debug('Total storage used: $total bytes');
      return total;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to calculate total storage used',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Validates a downloaded map file.
  ///
  /// Checks:
  /// 1. File exists
  /// 2. File size matches expected size
  /// 3. File can be opened (basic integrity check)
  ///
  /// Requirements: 13.5
  Future<Result<void>> _validateMapFile(
    File file,
    int expectedSizeBytes,
  ) async {
    try {
      _logger.debug('Validating map file: ${file.path}');

      // Check file exists
      if (!await file.exists()) {
        _logger.error('Map file does not exist: ${file.path}');
        return Result.failure(StorageError.fileNotFound(file.path));
      }

      // Check file size
      final actualSize = await file.length();
      if (actualSize != expectedSizeBytes) {
        _logger.error(
          'Map file size mismatch: expected $expectedSizeBytes, got $actualSize',
        );
        return Result.failure(
          StorageError.corruptedFile(
            '${file.path}: size mismatch (expected $expectedSizeBytes, got $actualSize)',
          ),
        );
      }

      // Basic integrity check: try to open the file
      try {
        final randomAccess = await file.open(mode: FileMode.read);
        await randomAccess.close();
        _logger.debug('Map file validation successful: ${file.path}');
      } catch (e, stackTrace) {
        _logger.error(
          'Map file cannot be opened: ${file.path}',
          error: e,
          stackTrace: stackTrace,
        );
        return Result.failure(StorageError.corruptedFile('${file.path}: $e'));
      }

      return Result.success(null);
    } catch (e, stackTrace) {
      _logger.error(
        'Error validating map file: ${file.path}',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.readFailure());
    }
  }
}
