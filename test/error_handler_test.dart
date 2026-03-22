import 'package:flutter_test/flutter_test.dart';

import 'package:cwnu_demo/config/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    group('getFriendlyMessage', () {
      test('returns message for AppError', () {
        final error = AppError('自定义错误消息');
        expect(ErrorHandler.getFriendlyMessage(error), equals('自定义错误消息'));
      });

      test('handles network error', () {
        final error = Exception('SocketException: Failed host lookup');
        expect(
          ErrorHandler.getFriendlyMessage(error),
          equals('网络连接失败，请检查网络设置'),
        );
      });

      test('handles timeout error', () {
        final error = Exception('TimeoutException: Request timeout');
        expect(ErrorHandler.getFriendlyMessage(error), equals('请求超时，请稍后重试'));
      });

      test('handles format error', () {
        final error = FormatException('Invalid JSON');
        expect(ErrorHandler.getFriendlyMessage(error), equals('数据格式错误，请稍后重试'));
      });

      test('handles 401 error', () {
        final error = Exception('401 Unauthorized');
        expect(ErrorHandler.getFriendlyMessage(error), equals('登录已过期，请重新登录'));
      });

      test('handles 403 error', () {
        final error = Exception('403 Forbidden');
        expect(ErrorHandler.getFriendlyMessage(error), equals('没有访问权限'));
      });

      test('handles 404 error', () {
        final error = Exception('404 Not Found');
        expect(ErrorHandler.getFriendlyMessage(error), equals('请求的资源不存在'));
      });

      test('handles 500 error', () {
        final error = Exception('500 Internal Server Error');
        expect(
          ErrorHandler.getFriendlyMessage(error),
          equals('服务器暂时无法响应，请稍后重试'),
        );
      });

      test('handles unknown error', () {
        final error = Exception('Unknown error');
        expect(ErrorHandler.getFriendlyMessage(error), equals('操作失败，请稍后重试'));
      });
    });
  });

  group('AppError', () {
    test('stores message', () {
      final error = AppError('错误消息');
      expect(error.message, equals('错误消息'));
    });

    test('stores code', () {
      final error = AppError('错误消息', code: 'ERR_001');
      expect(error.code, equals('ERR_001'));
    });

    test('stores original error', () {
      final original = Exception('原始错误');
      final error = AppError('错误消息', originalError: original);
      expect(error.originalError, equals(original));
    });

    test('toString returns message', () {
      final error = AppError('错误消息');
      expect(error.toString(), equals('错误消息'));
    });
  });
}
