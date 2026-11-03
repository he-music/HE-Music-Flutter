import 'package:flutter/material.dart';

import 'player_queue_panel_content.dart';

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // The panel estimates its content height inside the route's upper bound.
      child: PlayerQueuePanelContent(
        onRequestDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }
}
