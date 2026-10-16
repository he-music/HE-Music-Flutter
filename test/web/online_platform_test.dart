// 纯模型的浏览器测试入口，避开 test/flutter_test_config.dart 的原生 SQLite 夹具。
// 与 VM 共用断言，确保 JSON 数字、字符串及高低组合位在 JavaScript 中保真。
import '../features/online/domain/entities/online_platform_test.dart' as suite;

void main() => suite.main();
