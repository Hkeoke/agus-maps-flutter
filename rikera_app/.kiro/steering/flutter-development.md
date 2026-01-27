---
inclusion: always
---

# Flutter BLoC Development Guidelines for Rikera App

This project MUST follow strict Flutter BLoC architecture patterns and clean architecture principles.

## Skill Activation

**CRITICAL**: Apply the `flutter-bloc-development` skill from `~/.kiro/skills/flutter-bloc-development/` for ALL development in this project.

## CRITICAL VIOLATIONS TO FIX

### ❌ StatefulWidget Usage

**VIOLATION**: Screens using StatefulWidget with internal state management instead of BLoC.

**Examples of violations**:

- `MapScreen` - Uses StatefulWidget with `_isMapReady`, `_hasCheckedMapDownload`, etc.
- `BookmarksScreen` - Uses StatefulWidget with `_selectedCategory`
- `SearchScreen` - Uses StatefulWidget with `_searchController`, `_selectedCategory`

**CORRECT APPROACH**:

```dart
// ❌ WRONG - StatefulWidget with internal state
class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isMapReady = false;  // ❌ State in widget!
  bool _hasCheckedMapDownload = false;  // ❌ State in widget!

  void _onMapReady() {
    setState(() {  // ❌ setState in widget!
      _isMapReady = true;
    });
  }
}

// ✅ CORRECT - StatelessWidget with BLoC
class MapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        if (state is MapInitial) {
          return CircularProgressIndicator();
        }
        if (state is MapReady) {
          return _buildMap(state);
        }
        return ErrorWidget();
      },
    );
  }
}
```

### ❌ Large Widget Methods

**VIOLATION**: Screens with dozens of private `_build*` methods creating unmaintainable code.

**Examples**:

- `MapScreen._buildFloatingActions()`, `_buildPlacePage()`, `_buildActionButton()`, etc.
- `BookmarksScreen._buildCategoryFilter()`, `_buildEmptyState()`, `_buildBookmarkListItem()`, etc.
- `SearchScreen._buildSearchInput()`, `_buildCategoryFilters()`, `_buildContent()`, etc.

**CORRECT APPROACH**:

```dart
// ❌ WRONG - All widgets in one file
class MapScreen extends StatefulWidget {
  Widget _buildFloatingActions() { ... }  // ❌ 50 lines
  Widget _buildPlacePage() { ... }  // ❌ 30 lines
  Widget _buildActionButton() { ... }  // ❌ 20 lines
  // ... 10 more methods
}

// ✅ CORRECT - Extract to separate widget files
// widgets/map_floating_actions.dart
class MapFloatingActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) { ... }
}

// widgets/place_page_sheet.dart
class PlacePageSheet extends StatelessWidget {
  final PlaceInfo info;
  @override
  Widget build(BuildContext context) { ... }
}

// screens/map_screen.dart
class MapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AgusMap(...),
        MapFloatingActions(),  // ✅ Clean, reusable
      ],
    );
  }
}
```

### ❌ Business Logic in Widgets

**VIOLATION**: Navigation logic, data transformation, and business rules in widget methods.

**Examples**:

- `MapScreen._checkMapDownload()` - Business logic for checking map status
- `MapScreen._handleMapSelection()` - Logic for processing selection
- `BookmarksScreen._showAddBookmarkDialog()` - Form validation and data creation
- `SearchScreen._performSearch()` - Search logic with location handling

**CORRECT APPROACH**:

```dart
// ❌ WRONG - Business logic in widget
class MapScreen extends StatefulWidget {
  Future<void> _checkMapDownload(Location loc) async {
    final status = await checkMapStatus(loc.latitude, loc.longitude);  // ❌ Direct API call
    if (status == 2) {  // ❌ Business logic
      final countryName = await getCountryName(loc.latitude, loc.longitude);  // ❌ Direct API call
      showDialog(...);  // ❌ UI logic mixed with business logic
    }
  }
}

// ✅ CORRECT - Business logic in BLoC
// Event
class CheckMapDownloadStatus extends MapEvent {
  final Location location;
}

// State
class MapDownloadRequired extends MapState {
  final String countryName;
}

// BLoC
class MapBloc extends Bloc<MapEvent, MapState> {
  on<CheckMapDownloadStatus>((event, emit) async {
    final status = await _mapRepository.checkMapStatus(event.location);
    if (status == MapStatus.notDownloaded) {
      final countryName = await _mapRepository.getCountryName(event.location);
      emit(MapDownloadRequired(countryName));
    }
  });
}

// Widget
class MapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<MapBloc, MapState>(
      listener: (context, state) {
        if (state is MapDownloadRequired) {
          _showDownloadDialog(context, state.countryName);  // ✅ Only UI logic
        }
      },
      child: ...,
    );
  }
}
```

## Architecture Requirements

### Layer Separation (MANDATORY)

```
lib/
├── features/[feature_name]/
│   ├── domain/
│   │   ├── entities/          # Pure Dart business objects
│   │   ├── repositories/      # Repository interfaces (contracts)
│   │   └── usecases/          # Business logic use cases
│   ├── data/
│   │   ├── models/            # DTOs, JSON serialization
│   │   ├── datasources/       # API/Database SDK calls
│   │   └── repositories/      # Repository implementations
│   └── presentation/
│       ├── bloc/              # Events, States, BLoC
│       ├── screens/           # Feature screens (STATELESS!)
│       └── widgets/           # Feature-specific widgets (STATELESS!)
├── core/
│   ├── theme/                 # AppColors, AppSpacing, AppTypography
│   ├── utils/                 # Helpers, extensions
│   └── constants/             # App-wide constants
└── app/
    └── app.dart               # App initialization
```

### Widget Rules (MANDATORY)

1. **Screens MUST be StatelessWidget**
   - Use BlocBuilder/BlocListener for state
   - NO setState() calls
   - NO internal state variables

2. **Extract widgets to separate files**
   - If a `_build*` method is >20 lines → Extract to widget file
   - If a screen has >3 `_build*` methods → Extract all to widgets
   - Widget files go in `presentation/widgets/`

3. **Widget files MUST be small**
   - Max 100 lines per widget file
   - One widget per file
   - Clear, descriptive names

### BLoC Pattern (MANDATORY)

Every feature MUST have:

1. **Events** - User actions (extend Equatable)
2. **States** - UI states (extend Equatable)
3. **BLoC** - Event handlers with Loading → Success/Error pattern

**ALWAYS emit Loading state before async operations!**

### Design System (NON-NEGOTIABLE)

❌ **NEVER** use hardcoded values:

- `Color(0xFF...)` → Use `AppColors.primary`, `AppColors.error`, etc.
- `EdgeInsets.all(16)` → Use `AppSpacing.md`, `AppSpacing.lg`, etc.
- `BorderRadius.circular(12)` → Use `AppRadius.md`, `AppRadius.lg`, etc.
- `TextStyle(fontSize: 16)` → Use `AppTypography.bodyMedium`, etc.

✅ **ALWAYS** use design system constants from `core/theme/`

### Data Flow (MANDATORY)

```
UI Event → BLoC (emit Loading) → UseCase → Repository → DataSource (SDK)
    ↓
Response → Repository (map to entity) → UseCase → BLoC (emit Success/Error) → UI
```

**Rules:**

- NO business logic in widgets
- NO direct SDK calls outside datasources
- NO skipping loading states
- ALL errors show SnackBar with `AppColors.error`

## Refactoring Priority for Rikera App

### High Priority (Fix Immediately)

1. **Convert StatefulWidget screens to StatelessWidget**
   - MapScreen → Extract state to MapBloc
   - BookmarksScreen → Extract state to BookmarkBloc
   - SearchScreen → Extract state to SearchBloc
   - MapDownloadsScreen → Extract state to MapDownloadBloc

2. **Extract large widget methods to separate files**
   - MapScreen: 10+ `_build*` methods → Extract to `widgets/`
   - BookmarksScreen: 8+ `_build*` methods → Extract to `widgets/`
   - SearchScreen: 12+ `_build*` methods → Extract to `widgets/`

3. **Move business logic from widgets to BLoCs**
   - `_checkMapDownload()` → MapBloc event
   - `_handleMapSelection()` → MapBloc event
   - `_performSearch()` → SearchBloc event
   - `_showAddBookmarkDialog()` → BookmarkBloc event

### Medium Priority

4. **Create missing BLoC states**
   - MapBloc needs: MapInitial, MapReady, MapDownloadRequired, etc.
   - SearchBloc needs proper state for search history
   - BookmarkBloc needs proper state for category filtering

5. **Extract reusable widgets**
   - Dialog widgets → `core/widgets/`
   - List item widgets → `presentation/widgets/`
   - Form widgets → `presentation/widgets/`

## Quality Checklist

Before considering any feature complete:

- [ ] ALL screens are StatelessWidget
- [ ] NO `_build*` methods in screens (extracted to widgets)
- [ ] Events/States/BLoC use Equatable
- [ ] All async operations: Loading → Success/Error
- [ ] Zero business logic in UI
- [ ] Zero SDK calls outside datasources
- [ ] Zero hardcoded colors/spacing/typography
- [ ] Error handling shows SnackBar with AppColors.error
- [ ] Proper layer separation (domain/data/presentation)
- [ ] Widget files are <100 lines each

## Reference

Full skill documentation: `~/.kiro/skills/flutter-bloc-development/SKILL.md`
