/// Represents the direction of a turn in navigation instructions.
enum TurnDirection {
  /// Continue straight ahead
  straight,

  /// Turn slightly to the left
  slightLeft,

  /// Turn left
  left,

  /// Turn sharply to the left
  sharpLeft,

  /// Make a U-turn to the left
  uTurnLeft,

  /// Turn slightly to the right
  slightRight,

  /// Turn right
  right,

  /// Turn sharply to the right
  sharpRight,

  /// Make a U-turn to the right
  uTurnRight,

  /// Enter a roundabout
  roundabout,

  /// Exit a roundabout
  exitRoundabout,

  /// Destination reached
  destination,
}
