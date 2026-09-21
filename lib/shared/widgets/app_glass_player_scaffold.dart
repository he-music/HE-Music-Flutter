import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/player/presentation/providers/player_providers.dart';

/// Glass page composition shared by the tab shell and root content routes.
/// The caller retains routing and supplies the same mini-player instance.
class AppGlassPlayerScaffold extends ConsumerWidget {
  const AppGlassPlayerScaffold({
    required this.body,
    required this.miniPlayer,
    this.navigation,
    super.key,
  });

  final Widget body;
  final Widget miniPlayer;
  final Widget? navigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only mounting/unmounting the mini-player changes the layout, not progress,
    // play/pause, artwork, or the identity of an already visible track.
    final hasTrack = ref.watch(
      playerControllerProvider.select((state) => state.displayTrack != null),
    );
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom;
    final chromeHeight =
        (hasTrack ? 60.0 : 0.0) + (navigation != null ? 64.0 : 0.0);
    final hasChrome = chromeHeight > 0;
    final clearance = hasChrome ? chromeHeight + bottomInset : 0.0;
    final extendBody = hasChrome;
    // GlassScaffold adds Android bottom padding itself. Own it once here, using
    // viewPadding so the chrome remains fixed when the keyboard opens.
    return MediaQuery(
      data: media.copyWith(padding: media.padding.copyWith(bottom: 0)),
      child: Material(
        type: MaterialType.transparency,
        child: GlassScaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          edgeToEdge: true,
          resizeToAvoidBottomInset: false,
          extendBody: extendBody,
          bottomEdgeFade: extendBody,
          bottomBarHeight: clearance,
          body: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: hasChrome ? clearance : media.padding.bottom,
              ),
            ),
            child: body,
          ),
          bottomBar: !hasChrome
              ? null
              : Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [if (hasTrack) miniPlayer, ?navigation],
                  ),
                ),
        ),
      ),
    );
  }
}
