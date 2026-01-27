import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';
import 'package:rikera_app/features/map/domain/usecases/usecases.dart';
import 'map_download_event.dart';
import 'map_download_state.dart';

/// Bloc for managing map downloads.
///
/// This bloc handles:
/// - Loading available map regions
/// - Downloading map regions with progress tracking
/// - Deleting downloaded regions
/// - Calculating storage usage
///
/// Requirements: 3.1, 3.2, 3.3, 3.7
class MapDownloadBloc extends Bloc<MapDownloadEvent, MapDownloadState> {
  final DownloadMapRegionUseCase _downloadMapRegionUseCase;
  final GetAvailableRegionsUseCase _getAvailableRegionsUseCase;
  final MapRepository _mapRepository;

  StreamSubscription<DownloadProgress>? _downloadSubscription;

  MapDownloadBloc({
    required DownloadMapRegionUseCase downloadMapRegionUseCase,
    required GetAvailableRegionsUseCase getAvailableRegionsUseCase,
    required MapRepository mapRepository,
  }) : _downloadMapRegionUseCase = downloadMapRegionUseCase,
       _getAvailableRegionsUseCase = getAvailableRegionsUseCase,
       _mapRepository = mapRepository,
       super(const MapDownloadInitial()) {
    on<LoadRegions>(_onLoadRegions);
    on<DownloadRegion>(_onDownloadRegion);
    on<DeleteRegion>(_onDeleteRegion);
    on<CancelDownload>(_onCancelDownload);
  }

  /// Handles the LoadRegions event.
  ///
  /// This fetches the list of available regions from the CDN and merges
  /// with locally downloaded regions to show download status.
  ///
  /// Requirements: 3.1
  Future<void> _onLoadRegions(
    LoadRegions event,
    Emitter<MapDownloadState> emit,
  ) async {
    emit(const MapDownloadLoading());

    try {
      // Fetch available regions
      final result = await _getAvailableRegionsUseCase.execute();

      if (result.isFailure) {
        emit(
          MapDownloadError(
            message: result.errorOrNull?.message ?? 'Unknown error',
            regions: const [],
            totalStorageUsed: 0,
          ),
        );
        return;
      }

      // Calculate total storage used
      final totalStorage = await _mapRepository.getTotalStorageUsed();

      // Emit loaded state
      emit(
        MapDownloadLoaded(
          regions: result.valueOrNull ?? [],
          totalStorageUsed: totalStorage,
        ),
      );
    } catch (e) {
      emit(
        MapDownloadError(
          message: 'Failed to load regions: $e',
          regions: const [],
          totalStorageUsed: 0,
        ),
      );
    }
  }

  /// Handles the DownloadRegion event.
  ///
  /// This initiates a download of the specified region and streams
  /// progress updates.
  ///
  /// Requirements: 3.2, 3.3
  Future<void> _onDownloadRegion(
    DownloadRegion event,
    Emitter<MapDownloadState> emit,
  ) async {
    // Get current regions list
    final currentRegions = _getCurrentRegions();
    final totalStorage = await _mapRepository.getTotalStorageUsed();

    try {
      // Cancel any existing download
      await _downloadSubscription?.cancel();

      // Start download and use emit.forEach to handle stream properly
      await emit.forEach<DownloadProgress>(
        _downloadMapRegionUseCase.execute(event.region),
        onData: (progress) {
          // Return downloading state with progress
          return MapDownloadDownloading(
            region: event.region,
            progress: progress,
            regions: currentRegions,
            totalStorageUsed: totalStorage,
          );
        },
        onError: (error, stackTrace) {
          // Return error state
          return MapDownloadError(
            message: 'Download failed: $error',
            regions: currentRegions,
            totalStorageUsed: totalStorage,
          );
        },
      );

      // After download completes, reload regions
      if (!emit.isDone) {
        add(const LoadRegions());
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(
          MapDownloadError(
            message: 'Failed to start download: $e',
            regions: currentRegions,
            totalStorageUsed: totalStorage,
          ),
        );
      }
    }
  }

  /// Handles the DeleteRegion event.
  ///
  /// This deletes the specified region's MWM file and metadata.
  ///
  /// Requirements: 3.7
  Future<void> _onDeleteRegion(
    DeleteRegion event,
    Emitter<MapDownloadState> emit,
  ) async {
    final currentRegions = _getCurrentRegions();
    final totalStorage = await _mapRepository.getTotalStorageUsed();

    try {
      // Delete the region
      final result = await _mapRepository.deleteRegion(event.regionId);

      if (result.isFailure) {
        emit(
          MapDownloadError(
            message: result.errorOrNull?.message ?? 'Unknown error',
            regions: currentRegions,
            totalStorageUsed: totalStorage,
          ),
        );
        return;
      }

      // Reload regions to reflect the deletion
      add(const LoadRegions());
    } catch (e) {
      emit(
        MapDownloadError(
          message: 'Failed to delete region: $e',
          regions: currentRegions,
          totalStorageUsed: totalStorage,
        ),
      );
    }
  }

  /// Handles the CancelDownload event.
  ///
  /// This cancels an ongoing download.
  Future<void> _onCancelDownload(
    CancelDownload event,
    Emitter<MapDownloadState> emit,
  ) async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;

    // Reload regions to show current state
    add(const LoadRegions());
  }

  /// Gets the current regions list from the current state.
  List<MapRegion> _getCurrentRegions() {
    final currentState = state;
    if (currentState is MapDownloadLoaded) {
      return currentState.regions;
    } else if (currentState is MapDownloadDownloading) {
      return currentState.regions;
    } else if (currentState is MapDownloadError) {
      return currentState.regions;
    }
    return const [];
  }

  @override
  Future<void> close() async {
    await _downloadSubscription?.cancel();
    return super.close();
  }
}
