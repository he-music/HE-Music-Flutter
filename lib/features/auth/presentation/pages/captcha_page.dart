import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:go_captcha_flutter/go_captcha_flutter.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../data/providers/captcha_providers.dart';

class CaptchaPage extends ConsumerStatefulWidget {
  const CaptchaPage({required this.scene, required this.meta, super.key});

  final String scene;
  final String meta;

  @override
  ConsumerState<CaptchaPage> createState() => _CaptchaPageState();
}

class _CaptchaPageState extends ConsumerState<CaptchaPage> {
  bool _loading = true;
  String? _errorMessage;
  String? _unsupportedMessage;
  CaptchaData? _captchaData;
  String? _sessionId;
  bool _mustRestart = false;
  int? _currentType;
  bool _verifying = false;

  CaptchaApiClient get _client => ref.read(captchaApiClientProvider);

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.t(config, 'captcha.title')),
        actions: <Widget>[
          IconButton(
            onPressed: _loading || _verifying ? null : _resetCaptcha,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: AppI18n.t(config, 'captcha.refresh'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.read(appConfigProvider);
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _StatusPanel(
        title: AppI18n.t(config, 'captcha.load_failed'),
        message: errorMessage,
        primaryLabel: AppI18n.t(config, 'captcha.reload'),
        cancelLabel: AppI18n.t(config, 'common.cancel'),
        onPrimaryTap: _mustRestart ? _restartCaptcha : _resetCaptcha,
      );
    }
    final unsupportedMessage = _unsupportedMessage;
    if (unsupportedMessage != null) {
      return _StatusPanel(
        title: AppI18n.t(config, 'captcha.unsupported'),
        message: unsupportedMessage,
        primaryLabel: AppI18n.t(config, 'captcha.refetch'),
        cancelLabel: AppI18n.t(config, 'common.cancel'),
        onPrimaryTap: _resetCaptcha,
      );
    }
    final data = _captchaData;
    if (data == null) {
      return _StatusPanel(
        title: AppI18n.t(config, 'captcha.empty'),
        message: AppI18n.t(config, 'captcha.empty_reload'),
        primaryLabel: AppI18n.t(config, 'captcha.reload'),
        cancelLabel: AppI18n.t(config, 'common.cancel'),
        onPrimaryTap: _resetCaptcha,
      );
    }
    return _buildCaptchaWidget(data);
  }

  Widget _buildCaptchaWidget(CaptchaData data) {
    switch (data.type) {
      case 1:
      case 2:
        return _buildClickCaptcha(data);
      case 3:
        return _buildSlideRegionCaptcha(data);
      case 4:
        return _buildSlideCaptcha(data);
      case 5:
        return _buildRotateCaptcha(data);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildClickCaptcha(CaptchaData data) {
    final config = ref.read(appConfigProvider);
    return ClickCaptcha(
      config: ClickConfig(
        showTheme: false,
        title: AppI18n.t(config, 'captcha.widget.click_title'),
        buttonText: AppI18n.t(config, 'captcha.widget.click_verify'),
      ),
      image: data.image,
      thumb: data.thumb,
      onConfirm: (dots, reset) => _verifyClick(dots, reset),
      onRefresh: _resetCaptcha,
      onClose: () => context.pop(false),
    );
  }

  Widget _buildSlideCaptcha(CaptchaData data) {
    final config = ref.read(appConfigProvider);
    return SlideCaptcha(
      config: SlideConfig(
        showTheme: false,
        title: AppI18n.t(config, 'captcha.widget.slide_title'),
        helperText: AppI18n.t(config, 'captcha.widget.slide_helper'),
      ),
      image: data.image,
      thumb: data.thumb,
      thumbX: data.thumbX.toDouble(),
      thumbY: data.thumbY.toDouble(),
      thumbWidth: data.thumbWidth.toDouble(),
      thumbHeight: data.thumbHeight.toDouble(),
      onConfirm: (position, reset) => _verifySlide(position, reset),
      onRefresh: _resetCaptcha,
      onClose: () => context.pop(false),
    );
  }

  Widget _buildSlideRegionCaptcha(CaptchaData data) {
    final config = ref.read(appConfigProvider);
    return SlideRegionCaptcha(
      config: SlideRegionConfig(
        showTheme: false,
        title: AppI18n.t(config, 'captcha.widget.slide_region_title'),
        idleText: AppI18n.t(config, 'captcha.widget.slide_region_idle'),
        draggingText: AppI18n.t(config, 'captcha.widget.slide_region_dragging'),
        loadingText: AppI18n.t(config, 'captcha.widget.slide_region_loading'),
      ),
      image: data.image,
      thumb: data.thumb,
      thumbX: data.thumbX.toDouble(),
      thumbY: data.thumbY.toDouble(),
      thumbWidth: data.thumbWidth.toDouble(),
      thumbHeight: data.thumbHeight.toDouble(),
      onConfirm: (position, reset) => _verifySlide(position, reset),
      onRefresh: _resetCaptcha,
      onClose: () => context.pop(false),
    );
  }

  Widget _buildRotateCaptcha(CaptchaData data) {
    final config = ref.read(appConfigProvider);
    return RotateCaptcha(
      config: RotateConfig(
        showTheme: false,
        title: AppI18n.t(config, 'captcha.widget.rotate_title'),
        helperText: AppI18n.t(config, 'captcha.widget.rotate_helper'),
        thumbSize: data.thumbSize.toDouble(),
      ),
      image: data.image,
      thumb: data.thumb,
      angle: data.angle.toDouble(),
      onConfirm: (angle, reset) => _verifyRotate(angle, reset),
      onRefresh: _resetCaptcha,
      onClose: () => context.pop(false),
    );
  }

  Future<void> _loadCaptcha({bool restart = false}) async {
    if (restart) {
      _sessionId = null;
      _currentType = null;
      _mustRestart = false;
    }
    if (_mustRestart) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _captchaData = null;
        _errorMessage = null;
        _unsupportedMessage = null;
      });
    }
    try {
      final data = await _client.fetchCaptcha(
        scene: widget.scene,
        meta: widget.meta,
        type: _currentType,
        sessionId: _sessionId,
      );
      _sessionId = data.sessionId;
      if (data.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        _requireRestart();
        return;
      }
      if (!data.isSupported) {
        if (!mounted) return;
        setState(() {
          _captchaData = null;
          _loading = false;
          _unsupportedMessage = AppI18n.format(
            ref.read(appConfigProvider),
            'captcha.unsupported_type',
            <String, String>{'type': '${data.type}'},
          );
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _captchaData = data;
        _currentType = data.type;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_isSessionExpired(error)) {
        _requireRestart();
        return;
      }
      setState(() {
        _captchaData = null;
        _loading = false;
        _errorMessage = _normalizeError(error);
      });
    }
  }

  Future<void> _verifyClick(List<ClickDot> dots, VoidCallback reset) async {
    await _verify(
      dots: dots
          .map((d) => <String, dynamic>{'x': d.x.round(), 'y': d.y.round()})
          .toList(),
      reset: reset,
    );
  }

  Future<void> _verifySlide(Position position, VoidCallback reset) async {
    await _verify(
      point: <String, dynamic>{
        'x': position.x.round(),
        'y': position.y.round(),
      },
      reset: reset,
    );
  }

  Future<void> _verifyRotate(double angle, VoidCallback reset) async {
    await _verify(angle: angle.round(), reset: reset);
  }

  Future<void> _verify({
    int angle = 0,
    Map<String, dynamic> point = const <String, dynamic>{},
    List<Map<String, dynamic>> dots = const <Map<String, dynamic>>[],
    required VoidCallback reset,
  }) async {
    if (_verifying) return;
    _verifying = true;
    try {
      final data = _captchaData;
      if (data == null ||
          data.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        _requireRestart();
        return;
      }
      CaptchaVerification result;
      try {
        result = await _client.verifyCaptcha(
          scene: widget.scene,
          meta: widget.meta,
          sessionId: data.sessionId,
          challengeId: data.challengeId,
          angle: angle,
          point: point,
          dots: dots,
        );
      } on DioException catch (error) {
        if (error.response != null) rethrow;
        result = await _recoverResult(data.sessionId);
      }
      if (result.isExpired) {
        _requireRestart();
        return;
      }
      if (!result.isSuccess || result.ticket.isEmpty) {
        _showMessage(
          AppI18n.t(ref.read(appConfigProvider), 'captcha.verify_failed'),
        );
        reset();
        await _loadCaptcha();
        return;
      }
      if (mounted) {
        context.pop(result.ticket);
      }
    } catch (error) {
      if (_isSessionExpired(error)) {
        _requireRestart();
      } else if (_isProofInvalid(error)) {
        _showMessage(
          AppI18n.t(ref.read(appConfigProvider), 'captcha.verify_failed'),
        );
        reset();
        await _loadCaptcha();
      } else if (error is DioException && error.response == null) {
        _requireRestart(messageKey: 'captcha.recovery_failed');
      } else {
        _showMessage(_normalizeError(error));
        _requireRestart(messageKey: 'captcha.recovery_failed');
      }
    } finally {
      _verifying = false;
    }
  }

  Future<CaptchaVerification> _recoverResult(String sessionId) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      try {
        return await _client.getResult(sessionId);
      } on DioException catch (error) {
        if (_reason(error) != 'CAPTCHA_RESULT_PENDING') rethrow;
      }
    }
    throw StateError('CAPTCHA_RESULT_PENDING');
  }

  String? _reason(Object error) {
    if (error is! DioException) return null;
    final body = error.response?.data;
    return body is Map ? '${body['reason']}' : null;
  }

  bool _isSessionExpired(Object error) =>
      _reason(error) == 'CAPTCHA_SESSION_EXPIRED';
  bool _isProofInvalid(Object error) => _reason(error) == 'CAPTCHA_INVALID';

  void _requireRestart({String messageKey = 'captcha.session_expired'}) {
    if (!mounted) return;
    setState(() {
      _mustRestart = true;
      _captchaData = null;
      _loading = false;
      _errorMessage = AppI18n.t(ref.read(appConfigProvider), messageKey);
    });
  }

  void _restartCaptcha() => _loadCaptcha(restart: true);

  void _resetCaptcha() {
    if (_verifying || _loading) return;
    final data = _captchaData;
    if (data != null &&
        data.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      _requireRestart();
      return;
    }
    _loadCaptcha();
  }

  void _showMessage(String message) {
    AppMessageService.showError(message);
  }

  String _normalizeError(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return '$error';
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.cancelLabel,
    required this.onPrimaryTap,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final String cancelLabel;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimaryTap,
              child: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.pop(false),
              child: Text(cancelLabel),
            ),
          ),
        ],
      ),
    );
  }
}
