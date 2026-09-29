import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import 'captcha_challenge.dart';

class CaptchaCoordinator {
  CaptchaCoordinator(this._router);

  final GoRouter _router;
  Future<String?>? _activeChallenge;

  Future<String?> open(CaptchaChallenge challenge) {
    final active = _activeChallenge;
    if (active != null) {
      return active;
    }
    final future = _router
        .push<String>(
          Uri(
            path: AppRoutes.captcha,
            queryParameters: <String, String>{
              'scene': challenge.scene,
              'meta': challenge.meta,
            },
          ).toString(),
        )
        .then((value) => value);
    _activeChallenge = future;
    future.whenComplete(() {
      if (identical(_activeChallenge, future)) {
        _activeChallenge = null;
      }
    });
    return future;
  }
}
