import 'package:flutter_test/flutter_test.dart';
import 'package:rikera_app/features/map/data/datasources/map_download_datasource.dart';

void main() {
  group('MapDownloadDataSource', () {
    test('DownloadProgress should calculate progress correctly', () {
      final progress = DownloadProgress(bytesReceived: 50, totalBytes: 100);

      expect(progress.progress, equals(0.5));
      expect(progress.bytesReceived, equals(50));
      expect(progress.totalBytes, equals(100));
    });

    test('DownloadProgress should handle zero total bytes', () {
      final progress = DownloadProgress(bytesReceived: 0, totalBytes: 0);

      expect(progress.progress, equals(0.0));
    });

    test('DownloadProgress should format toString correctly', () {
      final progress = DownloadProgress(bytesReceived: 75, totalBytes: 100);

      final str = progress.toString();
      expect(str, contains('75.0%'));
      expect(str, contains('75/100'));
    });

    test('MapDownloadException should have descriptive message', () {
      final exception = MapDownloadException('Test error message');
      expect(exception.toString(), contains('Test error message'));
      expect(exception.toString(), contains('MapDownloadException'));
    });
  });
}
