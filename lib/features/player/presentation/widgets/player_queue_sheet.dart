import 'package:flutter/material.dart';

import 'player_queue_panel_content.dart';

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.60,
        child: PlayerQueuePanelContent(
          onRequestDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
