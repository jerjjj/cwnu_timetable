import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import '../services/session_store.dart';

class UpdateHelper {
  UpdateHelper._();

  static Future<void> checkAndPromptUpdate(BuildContext context) async {
    final latest = await AppUpdateService.fetchLatestVersion();
    if (!context.mounted) return;
    if (latest == null || latest.isEmpty) {
      await showSimpleDialog(
        context,
        title: '检查失败',
        message: '无法获取最新版本号，请稍后重试。',
      );
      return;
    }

    final current = await AppUpdateService.currentAppVersion();
    if (!context.mounted) return;

    if (!AppUpdateService.isNewerVersion(latest: latest, current: current)) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '当前已是最新版本',
            style: TextStyle(color: isDark ? Colors.white : null),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.inverseSurface,
        ),
      );
      return;
    }

    final ignored = await SessionStore.loadIgnoredUpdateVersion();
    if (!context.mounted || ignored == latest) return;

    await showUpdateDialog(
      context,
      latestVersion: latest,
      currentVersion: current,
    );
  }

  static Future<void> showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String currentVersion,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: Text(
            '当前版本: $currentVersion\n最新版本: $latestVersion\n\n是否立即更新？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('稍后提醒'),
            ),
            TextButton(
              onPressed: () async {
                await SessionStore.markUpdateVersionIgnored(latestVersion);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('不再提醒此版本'),
            ),
            FilledButton(
              onPressed: () async {
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                await _downloadAndInstall(context, latestVersion);
              },
              child: const Text('立即更新'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String version,
  ) async {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final progress = ValueNotifier<double?>(null);
    if (context.mounted) {
      _showDownloadProgress(context, progress);
    }

    try {
      final apkFile = await AppUpdateService.downloadApk(
        version: version,
        onProgress: (received, total) {
          if (total > 0) {
            progress.value = received / total;
          } else {
            progress.value = null;
          }
        },
      );

      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '下载完成，正在启动安装器...',
            style: TextStyle(color: isDark ? Colors.white : null),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.inverseSurface,
        ),
      );

      try {
        await AppUpdateService.installApk(apkFile);
      } catch (e) {
        if (!context.mounted) return;
        await showSimpleDialog(
          context,
          title: '未能启动安装器',
          message: '安装包已下载，但未能自动拉起安装界面。\n\n请确认系统已允许本应用安装未知来源应用，然后重试。\n\n详情: $e',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await showSimpleDialog(
        context,
        title: '下载失败',
        message: '更新安装包下载失败，请稍后重试。\n\n原因: $e',
      );
    } finally {
      progress.dispose();
    }
  }

  static Future<void> _showDownloadProgress(
    BuildContext context,
    ValueNotifier<double?> progress,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('正在下载更新'),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, value, _) {
                final text = value == null
                    ? '正在准备下载...'
                    : '下载进度 ${(value * 100).clamp(0, 100).toStringAsFixed(0)}%';
                return SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: value),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  static Future<void> showSimpleDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }
}
