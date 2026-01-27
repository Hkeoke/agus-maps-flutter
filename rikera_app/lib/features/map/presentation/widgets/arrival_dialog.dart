import 'package:flutter/material.dart';

/// Dialog shown when user arrives at destination.
///
/// Requirements: 6.7
class ArrivalDialog extends StatelessWidget {
  const ArrivalDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Arrived'),
      content: const Text('You have reached your destination.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Return to map screen
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
