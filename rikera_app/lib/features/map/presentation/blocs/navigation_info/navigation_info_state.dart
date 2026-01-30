import 'package:equatable/equatable.dart';

/// States for navigation info display
abstract class NavigationInfoState extends Equatable {
  const NavigationInfoState();

  @override
  List<Object?> get props => [];
}

/// No navigation active
class NavigationInfoIdle extends NavigationInfoState {
  const NavigationInfoIdle();
}

/// Navigation active with real-time info from motor
class NavigationInfoActive extends NavigationInfoState {
  final Map<String, dynamic> info;

  const NavigationInfoActive(this.info);

  @override
  List<Object?> get props => [info];

  // Helper getters for easy access
  double get distanceToTarget => (info['distanceToTarget'] as num?)?.toDouble() ?? 0.0;
  int get timeToTarget => (info['timeToTarget'] as num?)?.toInt() ?? 0;
  double get speedMps => (info['speedMps'] as num?)?.toDouble() ?? 0.0;
  double get distanceToTurn => (info['distanceToTurn'] as num?)?.toDouble() ?? 0.0;
  String? get currentStreet => info['currentStreetName'] as String?;
  String? get nextStreet => info['nextStreetName'] as String?;
}
