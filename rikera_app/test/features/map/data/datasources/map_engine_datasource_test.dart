import 'package:flutter_test/flutter_test.dart';
import 'package:rikera_app/features/map/data/datasources/map_engine_datasource.dart';
import 'package:rikera_app/features/map/data/datasources/map_engine_exception.dart';

void main() {
  group('MapEngineDataSource', () {
    late MapEngineDataSource dataSource;

    setUp(() {
      dataSource = MapEngineDataSource();
    });

    test('should throw MapEngineException when initialization fails', () async {
      // This test verifies error handling
      // Actual initialization requires platform channels which aren't available in unit tests
      expect(
        () => dataSource.initializeEngine('/invalid/path'),
        throwsA(isA<MapEngineException>()),
      );
    });

    test(
      'should throw MapEngineException when registering map without initialization',
      () async {
        // Attempting to register a map before initialization should fail
        expect(
          () => dataSource.registerMap('/path/to/map.mwm', 251209),
          throwsA(isA<MapEngineException>()),
        );
      },
    );

    test('MapEngineException should have descriptive message', () {
      final exception = MapEngineException('Test error message');
      expect(exception.toString(), contains('Test error message'));
      expect(exception.toString(), contains('MapEngineException'));
    });
  });
}
