---
description: Verify Route Recalculation Fix
---

# Verifying Route Recalculation

1.  **Run the App**: Start the `rikera_app` on an Android emulator or device.
2.  **Select a Destination**: Tap on a generic place on the map or search for one.
3.  **Start Navigation**: Click "IR AQUI (RUTA)" or "Navigate" to enter navigation mode.
4.  **Simulate Off-Route**:
    *   If using an emulator with GPS simulation, change the location to deviate from the calculated route.
    *   Or use the `AgusMapController` debug methods if available (there are no explicit debug methods exposed for forcing off-route in `AgusMapController` dart side readily available, but changing location via emulator is standard).
5.  **Observe Logs**:
    *   Watch `adb logcat` for "Received route rebuild recommendation from native engine".
    *   Watch for "Rebuilding route to destination...".
6.  **Verify Behavior**:
    *   The route line on the map should update to start from the new location and go to the destination.
    *   Navigation instructions should update.

## expected logs
Look for:
```
I/NavigationRepository( ...): Received route rebuild recommendation from native engine (off-route detected)
I/NavigationRepository( ...): Rebuilding route to destination: ...
```
