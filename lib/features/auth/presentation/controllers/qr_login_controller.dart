import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../core/device/device_info_provider.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/qr_login_state.dart';

class QrLoginController extends Notifier<QrLoginState> {
  @override
  QrLoginState build() {
    return QrLoginState.initial;
  }

  Future<void> createDesktopSession({
    required String clientType,
    required String clientName,
    required String scene,
  }) async {
    state = state.copyWith(
      status: QrLoginWorkflowStatus.creating,
      isBusy: true,
      clearErrorMessage: true,
      clearSuccessToken: true,
    );
    try {
      // 携带当前设备信息，后端会在扫码登录时注册该设备
      final deviceInfo = await ref.read(deviceInfoProvider.future);
      final result = await ref
          .read(onlineApiClientProvider)
          .createQrLoginSession(
            clientType: clientType,
            clientName: clientName,
            scene: scene,
            deviceInfo: deviceInfo.toApiMap(),
          );
      final parsed = _parseQrContent(result.qrContent);
      state = state.copyWith(
        status: _mapWorkflowStatus(result.status),
        isBusy: false,
        sessionId: result.sessionId,
        challenge: parsed.challenge,
        resultToken: result.resultToken,
        qrContent: result.qrContent,
        clientName: clientName,
        scene: scene,
        userHint: '',
        checkInterval: result.checkInterval,
        expiresAt: result.expiresAt,
      );
    } catch (error) {
      state = state.copyWith(
        status: QrLoginWorkflowStatus.failure,
        isBusy: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> pollDesktopSessionStatus() async {
    final sessionId = state.sessionId.trim();
    final resultToken = state.resultToken.trim();
    if (sessionId.isEmpty) {
      throw StateError('QR login session is missing.');
    }

    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .getQrLoginSessionStatus(sessionId: sessionId);
      state = state.copyWith(
        status: _mapWorkflowStatus(result.status),
        isBusy: false,
        clientName: result.clientName.isEmpty
            ? state.clientName
            : result.clientName,
        userHint: result.userHint,
        checkInterval: result.checkInterval,
        expiresAt: result.expiresAt,
      );
      if (result.status == 'confirmed' && resultToken.isNotEmpty) {
        await _exchangeDesktopResult();
      }
    } catch (error) {
      state = state.copyWith(
        status: QrLoginWorkflowStatus.failure,
        isBusy: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> handleScannedContent(String rawContent) async {
    final parsed = _parseQrContent(rawContent);
    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .scanQrLoginSession(
            sessionId: parsed.sessionId,
            challenge: parsed.challenge,
          );
      state = state.copyWith(
        status: _mapWorkflowStatus(result.status),
        isBusy: false,
        sessionId: result.sessionId,
        challenge: parsed.challenge,
        qrContent: rawContent,
        clientName: result.clientName,
        scene: result.scene,
        expiresAt: result.expiresAt,
      );
    } catch (error) {
      state = state.copyWith(
        status: QrLoginWorkflowStatus.failure,
        isBusy: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> confirmPendingSession() async {
    final token = ref.read(appConfigProvider).authToken?.trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Auth token is required before confirming QR login.');
    }
    final sessionId = state.sessionId.trim();
    final challenge = state.challenge.trim();
    if (sessionId.isEmpty || challenge.isEmpty) {
      throw StateError('Pending QR login session is missing.');
    }

    state = state.copyWith(isBusy: true, clearErrorMessage: true);
    try {
      final result = await ref
          .read(onlineApiClientProvider)
          .confirmQrLoginSession(sessionId: sessionId, challenge: challenge);
      state = state.copyWith(
        status: _mapWorkflowStatus(result.status),
        isBusy: false,
        expiresAt: result.expiresAt,
      );
    } catch (error) {
      state = state.copyWith(
        status: QrLoginWorkflowStatus.failure,
        isBusy: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> cancelPendingSession() async {
    final token = ref.read(appConfigProvider).authToken?.trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Auth token is required before cancelling QR login.');
    }
    final sessionId = state.sessionId.trim();
    final challenge = state.challenge.trim();
    if (sessionId.isEmpty || challenge.isEmpty) {
      throw StateError('Pending QR login session is missing.');
    }
    final result = await ref
        .read(onlineApiClientProvider)
        .cancelQrLoginSession(sessionId: sessionId, challenge: challenge);
    state = state.copyWith(
      status: _mapWorkflowStatus(result.status),
      isBusy: false,
    );
  }

  Future<void> _exchangeDesktopResult() async {
    final result = await ref
        .read(onlineApiClientProvider)
        .exchangeQrLoginResult(
          sessionId: state.sessionId,
          resultToken: state.resultToken,
        );
    state = state.copyWith(
      status: _mapWorkflowStatus(result.status),
      isBusy: false,
      successToken: result.accessToken,
      successRefreshToken: result.refreshToken,
      successExpiresAt: result.expiresAt,
    );
  }

  _ParsedQrContent _parseQrContent(String rawContent) {
    final uri = Uri.tryParse(rawContent.trim());
    if (uri == null) {
      throw StateError('Invalid QR login content.');
    }
    final sessionId = uri.queryParameters['sid']?.trim() ?? '';
    final challenge = uri.queryParameters['c']?.trim() ?? '';
    if (sessionId.isEmpty || challenge.isEmpty) {
      throw StateError('Invalid QR login content.');
    }
    return _ParsedQrContent(sessionId: sessionId, challenge: challenge);
  }

  QrLoginWorkflowStatus _mapWorkflowStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return QrLoginWorkflowStatus.pending;
      case 'scanned':
        return QrLoginWorkflowStatus.scanned;
      case 'confirmed':
        return QrLoginWorkflowStatus.confirmed;
      case 'success':
        return QrLoginWorkflowStatus.success;
      case 'expired':
        return QrLoginWorkflowStatus.expired;
      case 'cancelled':
        return QrLoginWorkflowStatus.cancelled;
      default:
        return QrLoginWorkflowStatus.failure;
    }
  }
}

class _ParsedQrContent {
  const _ParsedQrContent({required this.sessionId, required this.challenge});

  final String sessionId;
  final String challenge;
}
