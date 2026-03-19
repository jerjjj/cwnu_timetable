import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_update_service.dart';
import '../services/session_store.dart';

class SettingsTabPage extends StatefulWidget {
  const SettingsTabPage({
    super.key,
    required this.onTermStartDateChanged,
    required this.onLogout,
  });

  final VoidCallback onTermStartDateChanged;
  final Future<void> Function() onLogout;

  @override
  State<SettingsTabPage> createState() => _SettingsTabPageState();
}

class _SettingsTabPageState extends State<SettingsTabPage> {
  static const _shareUrl = 'https://gitee.com/jerjjj_admin/xifankebiao/';
  DateTime? _termStartDate;
  bool _isSaving = false;
  bool _isLoggingOut = false;
  bool _isCheckingUpdate = false;
  ValueNotifier<double?>? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final date = await SessionStore.loadTermStartDate();
    if (!mounted) {
      return;
    }
    setState(() {
      _termStartDate = date;
    });
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final current = _termStartDate ?? SessionStore.defaultTermStartDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2, 1, 1),
      lastDate: DateTime(current.year + 2, 12, 31),
      helpText: '选择开学日期（第一周第一天）',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _termStartDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    final date = _termStartDate;
    if (date == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await SessionStore.saveTermStartDate(date);
    widget.onTermStartDateChanged();
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }
    setState(() {
      _isLoggingOut = true;
    });
    await widget.onLogout();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoggingOut = false;
    });
  }

  Future<void> _copyShareLink() async {
    await Clipboard.setData(const ClipboardData(text: _shareUrl));
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('分享链接已复制'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkUpdateManually() async {
    if (_isCheckingUpdate) {
      return;
    }
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final latest = await AppUpdateService.fetchLatestVersion();
      if (!mounted) {
        return;
      }
      if (latest == null || latest.trim().isEmpty) {
        await _showSimpleDialog(title: '检查失败', message: '无法获取最新版本号，请稍后重试。');
        return;
      }

      final current = await AppUpdateService.currentAppVersion();
      if (!mounted) {
        return;
      }

      if (!AppUpdateService.isNewerVersion(latest: latest, current: current)) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('当前已是最新版本'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await _showManualUpdateDialog(
        latestVersion: latest,
        currentVersion: current,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await _showSimpleDialog(title: '检查失败', message: '检查更新失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<void> _showManualUpdateDialog({
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('稍后提醒'),
            ),
            TextButton(
              onPressed: () async {
                await SessionStore.markUpdateVersionIgnored(latestVersion);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('不再提醒此版本'),
            ),
            FilledButton(
              onPressed: () async {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await _downloadAndInstall(latestVersion);
              },
              child: const Text('立即更新'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndInstall(String version) async {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    _downloadProgress?.dispose();
    _downloadProgress = ValueNotifier<double?>(null);
    _showDownloadProgressDialog(_downloadProgress!);

    try {
      final apkFile = await AppUpdateService.downloadApk(
        version: version,
        onProgress: (received, total) {
          if (!mounted || _downloadProgress == null) {
            return;
          }
          if (total > 0) {
            _downloadProgress!.value = received / total;
          } else {
            _downloadProgress!.value = null;
          }
        },
      );

      if (!mounted) {
        return;
      }
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('下载完成，正在启动安装器...'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      try {
        await AppUpdateService.installApk(apkFile);
      } catch (e) {
        if (!mounted) {
          return;
        }
        await _showSimpleDialog(
          title: '未能启动安装器',
          message: '安装包已下载，但未能自动拉起安装界面。\n\n请确认系统已允许本应用安装未知来源应用，然后重试。\n\n详情: $e',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await _showSimpleDialog(
        title: '下载失败',
        message: '更新安装包下载失败，请稍后重试。\n\n原因: $e',
      );
    } finally {
      _downloadProgress?.dispose();
      _downloadProgress = null;
    }
  }

  Future<void> _showDownloadProgressDialog(
    ValueNotifier<double?> progress,
  ) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('正在下载更新'),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, value, _) {
                final progressText = value == null
                    ? '正在准备下载...'
                    : '下载进度 ${(value * 100).clamp(0, 100).toStringAsFixed(0)}%';
                return SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(progressText),
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

  Future<void> _showSimpleDialog({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _termStartDate;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: date == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('开学日期'),
                    subtitle: Text('${_formatDate(date)}（第一周第一天）'),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '默认开学日期：3月2日。课表页会按该日期自动切换到当前周。',
                  style: TextStyle(color: Color(0xFF5F6B7A)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存设置'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingUpdate ? null : _checkUpdateManually,
                    icon: _isCheckingUpdate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_outlined),
                    label: const Text('检查更新'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyShareLink,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('分享该应用'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingOut ? null : _logout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: const Text('退出账号'),
                  ),
                ),
              ],
            ),
    );
  }
}
