import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/qr_login_state.dart';
import '../controllers/qr_login_controller.dart';

final qrLoginControllerProvider =
    NotifierProvider<QrLoginController, QrLoginState>(QrLoginController.new);
