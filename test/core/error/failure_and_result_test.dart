import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/core/error/failure.dart';
import 'package:he_music_flutter/core/result/result.dart';

void main() {
  group('Failure 子类型', () {
    test('NetworkFailure 保存 message', () {
      const failure = NetworkFailure('网络错误');
      expect(failure.message, '网络错误');
    });

    test('ValidationFailure 保存 message', () {
      const failure = ValidationFailure('参数无效');
      expect(failure.message, '参数无效');
    });

    test('StorageFailure 保存 message', () {
      const failure = StorageFailure('存储失败');
      expect(failure.message, '存储失败');
    });

    test('UnsupportedFailure 保存 message', () {
      const failure = UnsupportedFailure('不支持的操作');
      expect(failure.message, '不支持的操作');
    });

    test('LocalOnlyModeFailure 保存 message', () {
      const failure = LocalOnlyModeFailure('仅本地模式');
      expect(failure.message, '仅本地模式');
    });

    test('UnknownFailure 保存 message', () {
      const failure = UnknownFailure('未知错误');
      expect(failure.message, '未知错误');
    });

    test('所有 Failure 子类型均为 const 构造', () {
      // 编译期验证：如果 const 失败则无法编译
      const failures = <Failure>[
        NetworkFailure('a'),
        ValidationFailure('b'),
        StorageFailure('c'),
        UnsupportedFailure('d'),
        LocalOnlyModeFailure('e'),
        UnknownFailure('f'),
      ];
      expect(failures.length, 6);
    });
  });

  group('AppException', () {
    test('toString 包含 failure.message', () {
      const exception = AppException(NetworkFailure('网络超时'));
      expect(exception.toString(), 'AppException: 网络超时');
    });

    test('持有原始 Failure', () {
      const failure = ValidationFailure('无效输入');
      const exception = AppException(failure);
      expect(exception.failure, same(failure));
    });
  });

  group('Result', () {
    test('Success 持有 data', () {
      const result = Success<int>(42);
      expect(result, isA<Success<int>>());
      expect(result.data, 42);
    });

    test('FailureResult 持有 failure', () {
      const failure = StorageFailure('存储满');
      const result = FailureResult<String>(failure);
      expect(result, isA<FailureResult<String>>());
      expect(result.failure, same(failure));
    });

    test('sealed class 可通过 switch exhaustive 匹配', () {
      const Result<int> success = Success(1);
      const Result<int> failure = FailureResult<int>(UnknownFailure('x'));

      String describe(Result<int> r) {
        return switch (r) {
          Success(data: final d) => 'success:$d',
          FailureResult(failure: final f) => 'failure:${f.message}',
        };
      }

      expect(describe(success), 'success:1');
      expect(describe(failure), 'failure:x');
    });

    test('泛型类型参数正确传递', () {
      const stringResult = Success<String>('hello');
      const listResult = Success<List<int>>([1, 2, 3]);

      expect(stringResult.data, 'hello');
      expect(listResult.data, [1, 2, 3]);
    });
  });
}
