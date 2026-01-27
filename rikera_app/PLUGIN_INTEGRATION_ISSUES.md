# Plugin Integration Issues - Diagnóstico y Soluciones

## Problemas Identificados

### 1. Mapas descargados no se detectan

**Síntoma**: La aplicación no detecta los mapas que ya están descargados.

**Causa Raíz**:

- Los mapas se registran correctamente durante la descarga
- Pero `checkMapStatus()` puede estar devolviendo estado incorrecto
- El motor CoMaps necesita que los mapas estén registrados ANTES de verificar el estado

**Solución**:

```dart
// En MapScreen._onMapReady(), después de registrar los mapas bundled:
context.read<MapCubit>().registerBundledMaps();

// Luego registrar TODOS los mapas descargados (no solo bundled):
final downloadedMaps = await context.read<MapRepository>().getDownloadedRegions();
for (final map in downloadedMaps.valueOrNull ?? []) {
  if (!map.isBundled) {
    await context.read<MapRepository>().registerMapFile(map.filePath);
  }
}

// DESPUÉS verificar el estado del mapa
await _checkMapDownload(currentLocation);
```

### 2. Círculo en vez de marcador de destino

**Síntoma**: Al tocar el mapa aparece un círculo en vez de un marcador apropiado.

**Causa Raíz**:
El círculo es el "selection circle" por defecto de CoMaps cuando:

1. No hay datos de POI (Points of Interest) en esa ubicación
2. El motor no tiene información detallada del lugar
3. Los archivos de datos (classificator.txt, types.txt) no están cargados correctamente

**Diagnóstico**:

```dart
// Agregar logs en MapScreen._handleMapSelection():
Future<void> _handleMapSelection() async {
  final info = await _mapController.getSelectionInfo();
  debugPrint('[MapScreen] Selection info: $info');

  if (info != null && mounted) {
    // Verificar qué información está disponible
    debugPrint('[MapScreen] Title: ${info['title']}');
    debugPrint('[MapScreen] Subtitle: ${info['subtitle']}');
    debugPrint('[MapScreen] Type: ${info['type']}');

    showModalBottomSheet(
      context: context,
      builder: (context) => _buildPlacePage(info),
    );
  }
}
```

**Soluciones Posibles**:

#### Opción A: Verificar extracción de archivos de datos

```dart
// En AppInitializationService.initialize():
_logger.info('Extracting CoMaps data files...');
final resourcePath = await agus.extractDataFiles();
_logger.info('Resource path: $resourcePath');

// Verificar que los archivos existen:
final dataDir = Directory(resourcePath);
final files = await dataDir.list().toList();
_logger.info('Data files extracted: ${files.length}');
for (final file in files) {
  _logger.info('  - ${file.path}');
}
```

#### Opción B: Agregar marcador personalizado

Si el motor no tiene datos del lugar, puedes agregar un marcador personalizado:

```dart
// En MapScreen, agregar un método para colocar un marcador temporal:
void _addTemporaryMarker(double lat, double lon) {
  // Crear un marcador visual en la UI de Flutter
  // (overlay sobre el mapa)
  setState(() {
    _temporaryMarker = Location(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
    );
  });
}

// En el build del AgusMap, agregar un Stack:
Stack(
  children: [
    AgusMap(...),
    if (_temporaryMarker != null)
      Positioned(
        // Calcular posición del marcador basado en lat/lon
        child: Icon(
          Icons.place,
          color: Colors.red,
          size: 48,
        ),
      ),
  ],
)
```

#### Opción C: Usar el sistema de routing para mostrar destino

```dart
// En _buildPlacePage, agregar botón para crear ruta:
ElevatedButton.icon(
  icon: const Icon(Icons.directions),
  label: const Text('Ir aquí'),
  onPressed: () {
    Navigator.pop(context);
    if (lat != null && lon != null) {
      final dLat = lat is String ? double.parse(lat) : (lat as num).toDouble();
      final dLon = lon is String ? double.parse(lon) : (lon as num).toDouble();

      // Esto debería mostrar la ruta en el mapa
      _mapController.buildRoute(dLat, dLon);
    }
  },
)
```

## Pasos de Diagnóstico Recomendados

### 1. Verificar registro de mapas

```bash
# Ejecutar la app y buscar en los logs:
flutter run --verbose 2>&1 | grep -E "(Registering|registered|CheckMapStatus)"
```

Deberías ver:

```
[MapCubit] Registering bundled maps with CoMaps engine...
[MapCubit] Registering World...
[MapCubit] Successfully registered World
[MapCubit] Registering WorldCoasts...
[MapCubit] Successfully registered WorldCoasts
[MapScreen] CheckMapStatus: lat=14.5995 lon=120.9842 -> Status 1
```

Si ves `Status 2` (NotDownloaded) después de registrar, hay un problema.

### 2. Verificar archivos de datos

```dart
// Agregar en MapEngineDataSource.initializeEngine():
final resourcePath = await agus.extractDataFiles();
debugPrint('[MapEngine] Resource path: $resourcePath');

// Verificar archivos críticos:
final classificator = File('$resourcePath/classificator.txt');
final types = File('$resourcePath/types.txt');
debugPrint('[MapEngine] classificator.txt exists: ${await classificator.exists()}');
debugPrint('[MapEngine] types.txt exists: ${await types.exists()}');
```

### 3. Usar funciones de debug del plugin

```dart
// En MapScreen._onMapReady(), después de registrar mapas:
_mapController.debugListMwms(); // Lista todos los MWMs registrados
_mapController.debugCheckPoint(14.5995, 120.9842); // Verifica si Manila está cubierta
```

## Solución Temporal: Forzar re-registro de mapas descargados

Agregar en `MapScreen._onMapReady()`:

```dart
void _onMapReady() async {
  _isMapReady = true;

  // ... código existente ...

  // NUEVO: Re-registrar TODOS los mapas descargados
  final mapRepo = context.read<MapRepository>();
  final downloadedResult = await mapRepo.getDownloadedRegions();

  if (downloadedResult.isSuccess) {
    final maps = downloadedResult.valueOrNull ?? [];
    debugPrint('[MapScreen] Re-registering ${maps.length} downloaded maps');

    for (final map in maps) {
      try {
        await mapRepo.registerMapFile(map.filePath);
        debugPrint('[MapScreen] Re-registered: ${map.name}');
      } catch (e) {
        debugPrint('[MapScreen] Failed to re-register ${map.name}: $e');
      }
    }

    // Forzar redibujado después de registrar todos
    _mapController.invalidateMap();
    _mapController.forceRedraw();
  }
}
```

## Próximos Pasos

1. **Agregar logs detallados** en los puntos críticos
2. **Ejecutar con logs** y capturar la salida
3. **Verificar el estado** de checkMapStatus antes y después de registrar
4. **Probar con un mapa descargado** (ej: Philippines.mwm)
5. **Verificar la información** que devuelve getSelectionInfo()

## Referencias

- Plugin API: `lib/agus_maps_flutter.dart`
- Registro de mapas: `rikera_app/lib/features/map/data/repositories/map_repository_impl.dart`
- Inicialización: `rikera_app/lib/core/services/app_initialization_service.dart`
