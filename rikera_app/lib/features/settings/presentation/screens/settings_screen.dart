import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_event.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_state.dart';
import 'package:rikera_app/features/map/presentation/screens/map_downloads_screen.dart';

/// Settings screen for configuring app preferences
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the existing SettingsBloc from the app-level context
    // instead of creating a new one
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SettingsLoaded) {
            return _buildSettingsList(context, state.settings);
          }

          // Initial or error state - show defaults
          return _buildSettingsList(context, AppSettings.defaults());
        },
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, AppSettings settings) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        // Theme Section
        _buildSectionHeader(context, 'Appearance'),
        _buildThemeModeTile(context, settings.themeMode),
        const Divider(height: 1),

        // Navigation Section
        _buildSectionHeader(context, 'Navigation'),
        _buildVoiceGuidanceTile(context, settings.voiceGuidanceEnabled),
        _buildSpeedUnitTile(context, settings.speedUnit),
        const Divider(height: 1),

        // Map Data Section
        _buildSectionHeader(context, 'Map Data'),
        _buildMapDataManagementTile(context),
        const Divider(height: 1),

        // About Section
        _buildSectionHeader(context, 'About'),
        _buildAboutTile(context),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeModeTile(BuildContext context, AppThemeMode currentMode) {
    return CarOptimizedListTile(
      leading: Icon(
        _getThemeIcon(currentMode),
        size: AppSizes.iconLarge,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: 'Theme',
      subtitle: currentMode.label,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, currentMode),
    );
  }

  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.wb_sunny;
      case AppThemeMode.dark:
        return Icons.nightlight_round;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  Widget _buildVoiceGuidanceTile(BuildContext context, bool enabled) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      child: SwitchListTile(
        secondary: Icon(
          enabled ? Icons.volume_up : Icons.volume_off,
          size: AppSizes.iconLarge,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'Voice Guidance',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          enabled ? 'Enabled' : 'Disabled',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        value: enabled,
        onChanged: (value) {
          context.read<SettingsBloc>().add(ToggleVoiceGuidance(value));
        },
      ),
    );
  }

  Widget _buildSpeedUnitTile(BuildContext context, SpeedUnit currentUnit) {
    return CarOptimizedListTile(
      leading: Icon(
        Icons.speed,
        size: AppSizes.iconLarge,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: 'Speed Units',
      subtitle: currentUnit.label,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSpeedUnitDialog(context, currentUnit),
    );
  }

  Widget _buildMapDataManagementTile(BuildContext context) {
    return CarOptimizedListTile(
      leading: Icon(
        Icons.map,
        size: AppSizes.iconLarge,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: 'Manage Map Downloads',
      subtitle: 'Download and delete offline maps',
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapDownloadsScreen()),
        );
      },
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return CarOptimizedListTile(
      leading: Icon(
        Icons.info_outline,
        size: AppSizes.iconLarge,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: 'About',
      subtitle: 'Rikera Car Navigation v1.0.0',
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showAboutDialog(context),
    );
  }

  void _showThemeModeDialog(BuildContext context, AppThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Select Theme',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return InkWell(
              onTap: () {
                context.read<SettingsBloc>().add(UpdateThemeMode(mode));
                Navigator.of(dialogContext).pop();
              },
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getThemeIcon(mode),
                      size: AppSizes.iconMedium,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        mode.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: AppSizes.iconMedium,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          CarOptimizedTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _showSpeedUnitDialog(BuildContext context, SpeedUnit currentUnit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Select Speed Unit',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SpeedUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return InkWell(
              onTap: () {
                context.read<SettingsBloc>().add(UpdateSpeedUnit(unit));
                Navigator.of(dialogContext).pop();
              },
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: AppSizes.iconMedium,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        unit.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: AppSizes.iconMedium,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          CarOptimizedTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Rikera',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.navigation,
        size: AppSizes.iconXLarge,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Car navigation app with offline maps',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Powered by CoMaps rendering engine',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
