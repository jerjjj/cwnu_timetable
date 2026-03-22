import 'package:flutter/material.dart';

class AppError implements Exception {
  const AppError(this.message, {this.code, this.originalError});

  final String message;
  final String? code;
  final Object? originalError;

  @override
  String toString() => message;
}

class ErrorHandler {
  ErrorHandler._();

  static String getFriendlyMessage(Object error) {
    if (error is AppError) {
      return error.message;
    }

    final errorString = error.toString();

    if (errorString.contains('SocketException') ||
        errorString.contains('NetworkException')) {
      return '网络连接失败，请检查网络设置';
    }

    if (errorString.contains('TimeoutException') ||
        errorString.contains('Connection timed out')) {
      return '请求超时，请稍后重试';
    }

    if (errorString.contains('FormatException')) {
      return '数据格式错误，请稍后重试';
    }

    if (errorString.contains('HandshakeException') ||
        errorString.contains('CertificateException')) {
      return '安全连接失败，请检查网络设置';
    }

    if (errorString.contains('HttpException')) {
      return '服务器连接失败，请稍后重试';
    }

    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return '登录已过期，请重新登录';
    }

    if (errorString.contains('403') || errorString.contains('Forbidden')) {
      return '没有访问权限';
    }

    if (errorString.contains('404') || errorString.contains('Not Found')) {
      return '请求的资源不存在';
    }

    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return '服务器暂时无法响应，请稍后重试';
    }

    return '操作失败，请稍后重试';
  }

  static void showSnackBar(
    dynamic messenger,
    String message, {
    bool isError = true,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
