import 'package:flutter/material.dart';

import '../../../../shared/constants/layout_tokens.dart';
import 'player_queue_panel_content.dart';

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height:
            MediaQuery.of(context).size.height *
            LayoutTokens.actionSheetMaxHeightFactor,
        child: PlayerQueuePanelContent(
          onRequestDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
