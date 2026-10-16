import 'dart:async';

// 浏览器纯模型测试不需要上层的原生数据库夹具。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
