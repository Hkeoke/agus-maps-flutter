# Solución Crítica: Crash al Actualizar Mapas

Este documento detalla el arreglo manual necesario para evitar el bloqueo (`crash`) de la aplicación cuando se intenta actualizar un mapa preinstalado (como World.mwm).

## El Problema
El motor CoMaps intenta borrar el mapa "viejo" del disco al actualizar. Si el mapa viejo es interno (bundled), no tiene carpeta física, lo que provoca un error de `assertion "false" failed` en `JoinPath`.

## La Solución
Se debe modificar el código fuente C++ para omitir el borrado si el archivo es interno.

### Archivo a Modificar
**Ruta:** `thirdparty/comaps/libs/platform/local_country_file.cpp`

### Instrucciones
1. Abre el archivo mencionado.
2. Busca la función `void LocalCountryFile::DeleteFromDisk(MapFileType type) const` (aprox. línea 52).
3. Inserta el bloque de código marcado con `+` a continuación:

```cpp
void LocalCountryFile::DeleteFromDisk(MapFileType type) const
{
  ASSERT_LESS(base::Underlying(type), m_files.size(), ());

  // --- INICIO DEL ARREGLO ---
  // Cannot delete files from bundle (they don't exist on disk in a normal directory).
  // GetPath() would fail with an assertion because m_directory is empty for bundled files.
  if (m_directory.empty())
    return;
  // --- FIN DEL ARREGLO ---

  if (OnDisk(type) && !base::DeleteFileX(GetPath(type)))
    LOG(LERROR, (type, "from", *this, "wasn't deleted from disk."));
}
```

### Importante
Si ejecutas `dart run tool/build.dart`, este cambio **se perderá** (se sobrescribirá). Deberás volver a aplicarlo manualmente siguiendo estas instrucciones antes de compilar tu app.
