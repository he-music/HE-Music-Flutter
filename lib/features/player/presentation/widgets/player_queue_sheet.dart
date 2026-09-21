import 'package:flutter/material.dart';

import 'player_queue_panel_content.dart';

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // The route owns height so the list fills both glass and solid sheets.
      child: PlayerQueuePanelContent(
        onRequestDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }
}
