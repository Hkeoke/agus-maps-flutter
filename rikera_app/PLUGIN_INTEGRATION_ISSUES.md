# Problemas de Integración del Plugin Agus Maps

## Fecha: 2026-01-25

## Resumen

La aplicación `rikera_app` NO está configurada correctamente para usar el plugin `agus_maps_flutter`. Faltan componentes críticos necesarios para que el mapa funcione.

## Problemas Críticos Identificados

### 1. ❌ FALTA CONFIGURACIÓN DE ASSETS EN pubspec.yaml

**Problema**: El archivo `rikera_app/pubspec.yaml` NO tiene la sección `flutter.assets` configurada.

**Ubicación**: `rikera_app/pubspec.yaml`

**Estado Actual**:

```yaml
flutter:
  uses-material-design: true
  # NO HAY ASSETS CONFIGURADOS
```

**Debe ser** (según ejemplo y documentación):

```yaml
flutter:
  uses-material-design: true

  assets:
    # Mapas bundled mínimos requeridos
    - assets/maps/World.mwm
    - assets/maps/WorldCoasts.mwm
    - assets/maps/icudt75l.dat

    # Datos de CoMaps (REQUERIDOS)
    - assets/comaps_data/
    - assets/comaps_data/fonts/

    # Strings de categorías (REQUERIDOS)
    - assets/comaps_data/categories-strings/ar.json/
    - assets/comaps_data/categories-strings/be.json/
    # ... (ver example/pubspec.yaml para lista completa)

    # Strings de países (REQUERIDOS)
    - assets/comaps_data/countries-strings/ar.json/
    - assets/comaps_data/countries-strings/be.json/
    # ... (ver example/pubspec.yaml para lista completa)

    # Símbolos del mapa (REQUERIDOS)
    - assets/comaps_data/symbols/
    - assets/comaps_data/symbols/6plus/
    # ... (ver example/pubspec.yaml para lista completa)

    # Estilos del mapa (REQUERIDOS)
    - assets/comaps_data/styles/
    - assets/comaps_data/styles/default/
    # ... (ver example/pubspec.yaml para lista completa)
```

### 2. ❌ FALTA CARPETA DE ASSETS

**Problema**: No existe la carpeta `rikera_app/assets/` con los archivos necesarios.

**Archivos Faltantes**:

- `rikera_app/assets/maps/World.mwm` - Mapa mundial de baja resolución (REQUERIDO)
- `rikera_app/assets/maps/WorldCoasts.mwm` - Costas mundiales (REQUERIDO)
- `rikera_app/assets/maps/icudt75l.dat` - Datos ICU para transliteración (REQUERIDO)
- `rikera_app/assets/comaps_data/` - Directorio completo con datos del motor CoMaps (REQUERIDO)

**Solución**: Copiar la carpeta `assets/` desde el SDK de agus_maps_flutter o desde `example/assets/`

### 3. ⚠️ INICIALIZACIÓN INCORRECTA

**Problema**: El servicio `AppInitializationService` intenta extraer mapas que no existen.

**Ubicación**: `rikera_app/lib/core/services/app_initialization_service.dart`

**Código Problemático**:

```dart
// Línea ~70
final path = await agus.extractMap('assets/maps/$mapFile');
```

**Error**: Esto fallará porque:

1. Los assets no están declarados en pubspec.yaml
2. Los archivos no existen en la carpeta assets/

### 4. ⚠️ CONSTANTES INCORRECTAS

**Problema**: Las constantes definen mapas bundled que no existen.

**Ubicación**: `rikera_app/lib/core/constants/app_constants.dart`

**Código**:

```dart
static const List<String> bundledMapFiles = ['World.mwm', 'WorldCoasts.mwm'];
```

**Nota**: Esto está correcto según la documentación, pero los archivos no existen en assets.

### 5. ⚠️ FALTA REGISTRO DE MAPAS DESPUÉS DE CREAR SUPERFICIE

**Problema**: El código intenta registrar mapas en `MapCubit.registerBundledMaps()` pero esto ocurre DESPUÉS de que el motor ya está inicializado.

**Ubicación**: `rikera_app/lib/features/map/presentation/blocs/map/map_cubit.dart`

**Flujo Actual**:

1. `main.dart` → `AppInitializationService.initialize()` → Extrae e intenta registrar mapas
2. `MapScreen._onMapReady()` → `MapCubit.registerBundledMaps()` → Intenta registrar de nuevo

**Problema**: Según el ejemplo, los mapas deben:

1. Extraerse durante la inicialización
2. Guardarse las rutas
3. Registrarse DESPUÉS de que la superficie del mapa esté lista
4. Llamar a `invalidateMap()` y `forceRedraw()` después del registro

## Comparación con el Ejemplo Funcional

### Ejemplo (example/lib/main.dart) - ✅ CORRECTO

```dart
// 1. Extrae mapas y guarda rutas
final worldPath = await agus_maps_flutter.extractMap('assets/maps/World.mwm');
_mapPathsToRegister.add(worldPath);

// 2. Inicializa el motor
agus_maps_flutter.initWithPaths(dataPath, dataPath);

// 3. Espera a que el mapa esté listo
void _onMapReady() {
  // 4. Registra mapas DESPUÉS de crear superficie
  for (final path in _mapPathsToRegister) {
    final result = agus_maps_flutter.registerSingleMapWithVersion(path, version);
  }

  // 5. Fuerza recarga de tiles
  agus_maps_flutter.invalidateMap();
  agus_maps_flutter.forceRedraw();
}
```

### rikera_app - ❌ INCORRECTO

```dart
// AppInitializationService.initialize()
// Intenta extraer y registrar inmediatamente (ANTES de crear superficie)
final path = await agus.extractMap('assets/maps/$mapFile');
// NO guarda las rutas para registro posterior
// NO llama a invalidateMap() ni forceRedraw()

// MapCubit.registerBundledMaps()
// Intenta registrar de nuevo pero usa getDownloadedRegions()
// que depende de MapStorageDataSource
```

## Solución Recomendada

### Paso 1: Copiar Assets

```bash
# Desde la raíz del proyecto
cp -r example/assets rikera_app/
```

### Paso 2: Actualizar pubspec.yaml

Copiar la sección completa de `flutter.assets` desde `example/pubspec.yaml` a `rikera_app/pubspec.yaml`.

### Paso 3: Refactorizar AppInitializationService

Cambiar el flujo para que:

1. Solo extraiga los mapas y devuelva las rutas
2. NO intente registrarlos inmediatamente
3. Guarde las rutas en un lugar accesible (por ejemplo, en el servicio de DI)

### Paso 4: Actualizar MapScreen

Modificar `_onMapReady()` para:

1. Obtener las rutas de mapas extraídos
2. Registrar cada mapa con `registerSingleMapWithVersion()`
3. Llamar a `invalidateMap()` y `forceRedraw()`

### Paso 5: Verificar Versión de MWM

Leer la versión desde `countries.txt` como lo hace el ejemplo:

```dart
final file = File('$dataPath/countries.txt');
final contents = await file.readAsString();
final match = RegExp(r'"v"\s*:\s*(\d+)').firstMatch(contents);
final version = int.tryParse(match.group(1)!);
```

## Referencias

- **Documentación del Plugin**: `README.md` - Sección "Quick Start"
- **Ejemplo Funcional**: `example/lib/main.dart` - Método `_initData()` y `_onMapReadyAsync()`
- **API Reference**: `doc/API.md` - Sección "Map File Registration"
- **Guía de Arquitectura**: `GUIDE.md` - Sección "SDK Distribution Model"

## Prioridad

🔴 **CRÍTICO** - La aplicación NO funcionará sin estos cambios. El mapa no se renderizará correctamente.

## ✅ Soluciones Aplicadas

### 1. Assets Copiados

```bash
cp -r example/assets rikera_app/
```

✅ Completado - Los assets ahora existen en `rikera_app/assets/`

### 2. pubspec.yaml Actualizado

✅ Completado - Se agregó la configuración completa de assets al `rikera_app/pubspec.yaml`

## 🔧 Próximos Pasos Pendientes

### 3. Refactorizar AppInitializationService

El flujo actual intenta registrar mapas inmediatamente después de extraerlos, pero según el ejemplo, los mapas deben registrarse DESPUÉS de que la superficie del mapa esté lista.

**Cambios necesarios**:

1. Modificar `AppInitializationService` para que solo extraiga y guarde rutas
2. Crear un servicio o variable global para almacenar las rutas de mapas extraídos
3. Actualizar `MapScreen._onMapReady()` para registrar los mapas correctamente

### 4. Actualizar MapScreen.\_onMapReady()

Debe seguir el patrón del ejemplo:

```dart
void _onMapReady() {
  // 1. Obtener rutas de mapas extraídos
  final mapPaths = /* obtener del servicio */;

  // 2. Leer versión de MWM desde countries.txt
  final version = /* leer versión */;

  // 3. Registrar cada mapa
  for (final path in mapPaths) {
    final result = agus_maps_flutter.registerSingleMapWithVersion(path, version);
    debugPrint('Registered $path: result=$result');
  }

  // 4. Forzar recarga de tiles
  agus_maps_flutter.invalidateMap();
  agus_maps_flutter.forceRedraw();

  // 5. Debug
  agus_maps_flutter.debugListMwms();
}
```

### 5. Probar la Aplicación

Una vez completados los pasos 3 y 4:

```bash
cd rikera_app
flutter clean
flutter pub get
flutter run
```
