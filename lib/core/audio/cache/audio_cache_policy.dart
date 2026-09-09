import '../../network/network_status_port.dart';

final class AudioCachePolicy {
  const AudioCachePolicy({
    this.enabled = true,
    this.allowCellular = false,
    this.limitBytes = defaultLimitBytes,
  });

  static const mebibyte = 1024 * 1024;
  static const defaultLimitBytes = 2 * 1024 * mebibyte;
  static const physicalFloorBytes = 512 * mebibyte;
  static const limits = <int>[
    500 * mebibyte,
    1024 * mebibyte,
    defaultLimitBytes,
    5 * 1024 * mebibyte,
  ];

  final bool enabled;
  final bool allowCellular;
  final int limitBytes;

  bool allowsWrite(NetworkConnectionType network) =>
      enabled &&
      (network == NetworkConnectionType.wifi ||
          (network == NetworkConnectionType.cellular && allowCellular));
}
