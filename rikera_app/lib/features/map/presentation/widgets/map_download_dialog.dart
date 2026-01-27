import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import '../screens/map_downloads_screen.dart';

/// Dialog prompting user to download map for current location.
///
/// Requirements: 2.6
class MapDownloadDialog extends StatelessWidget {
  final String countryName;

  const MapDownloadDialog({
    super.key,
    required this.countryName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Download $countryName?'),
      content: Text(
        'The map for $countryName is not downloaded. '
        'Download it now to see details and navigate.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.read<MapCubit>().add(const DismissMapDownloadCheck());
            Navigator.pop(context);
          },
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () {
            context.read<MapCubit>().add(const DismissMapDownloadCheck());
            Navigator.pop(context);
            _handleDownload(context);
          },
          child: const Text('Download'),
        ),
      ],
    );
  }

  void _handleDownload(BuildContext context) {
    // Try to find region in MapDownloadBloc and start download
    final state = context.read<MapDownloadBloc>().state;
    if (state is MapDownloadLoaded) {
      try {
        final region = state.regions.firstWhere(
          (r) => r.id == countryName || r.name == countryName,
          orElse: () => throw Exception('Not found'),
        );
        context.read<MapDownloadBloc>().add(DownloadRegion(region));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading $countryName...')),
        );
        return;
      } catch (_) {}
    }

    // Fallback: Navigate to downloads screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MapDownloadsScreen(),
      ),
    );
  }
}
