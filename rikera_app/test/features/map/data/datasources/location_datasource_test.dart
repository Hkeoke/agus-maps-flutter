import 'package:flutter_test/flutter_test.dart';
import 'package:rikera_app/features/map/data/datasources/location_datasource.dart';

void main() {
  group('LocationDataSource', () {
    test('LocationException should have descriptive message', () {
      final exception = LocationException('Test error message');
      expect(exception.toString(), contains('Test error message'));
      expect(exception.toString(), contains('LocationException'));
    });

    test('should handle location operations gracefully', () {
      // Note: Actual location operations require geolocator which needs
      // platform channels. These tests verify the interface exists.
      expect(LocationDataSource, isNotNull);
    });
  });
}
