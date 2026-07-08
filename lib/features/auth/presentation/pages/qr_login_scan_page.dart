import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../providers/qr_login_providers.dart';

class QrLoginScanPage extends ConsumerStatefulWidget {
  const QrLoginScanPage({super.key});

  @override
  ConsumerState<QrLoginScanPage> createState() => _QrLoginScanPageState();
}

class _QrLoginScanPageState extends ConsumerState<QrLoginScanPage> {
  bool _handlingDetection = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.t(config, 'auth.qr.scan_title')),
        leading: AppBackButton(onPressed: () => _handleBack(context)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue?.trim() ?? '';
              if (code.isEmpty || _handlingDetection) {
                return;
              }
              _handlingDetection = true;
              _handleScan(code);
            },
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Text(
                  AppI18n.t(config, 'auth.qr.scan_hint'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScan(String rawValue) async {
    try {
      await ref
          .read(qrLoginControllerProvider.notifier)
          .handleScannedContent(rawValue);
      if (!mounted) {
        return;
      }
      context.go(AppRoutes.loginQrConfirm);
    } catch (error) {
      _handlingDetection = false;
      if (!mounted) {
        return;
      }
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(ref.read(appConfigProvider), 'auth.qr.invalid'),
      );
    }
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.homeMy);
  }
}
