import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import '../services/session_store.dart';
import 'home_dock_page.dart';
import 'login_page.dart';
import 'welcome_page.dart';
import 'warning_page.dart';

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  Widget? _nextPage;
  bool _updateDialogShown = false;
  ValueNotifier<double?>? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _resolveInitialPage();
  }

  Future<void> _resolveInitialPage() async {
    final showWelcome = await SessionStore.shouldShowWelcome();
    if (showWelcome) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nextPage = WelcomePage(
          onStart: () async {
            if (!mounted) {
              return;
            }
            setState(() {
              _nextPage = WarningPage(
                onAcknowledge: () async {
                  await SessionStore.markWelcomeCompleted();
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _nextPage = const LoginPage();
                  });
                },
              );
            });
          },
        );
      });
      _triggerUpdateCheckIfNeeded();
      return;
    }

    final session = await SessionStore.load();
    if (session == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nextPage = const LoginPage();
      });
      _triggerUpdateCheckIfNeeded();
      return;
    }

    final cachedRecords = await SessionStore.loadCachedRecords();
    if (!mounted) {
      return;
    }
    setState(() {
      _nextPage = HomeDockPage(session: session, initialRecords: cachedRecords);
    });

    _triggerUpdateCheckIfNeeded();
  }

  void _triggerUpdateCheckIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkForUpdate();
      }
    });
  }

  Future<void> _checkForUpdate() async {
    if (_updateDialogShown || !mounted) {
      return;
    }

    final latest = await AppUpdateService.fetchLatestVersion();
    if (!mounted || latest == null || latest.isEmpty) {
      return;
    }

    final current = await AppUpdateService.currentAppVersion();
    if (!mounted) {
      return;
    }
    if (!AppUpdateService.isNewerVersion(latest: latest, current: current)) {
      return;
    }

    final ignored = await SessionStore.loadIgnoredUpdateVersion();
    if (!mounted) {
      return;
    }
    if (ignored == latest) {
      return;
    }

    _updateDialogShown = true;
    await _showUpdateDialog(latestVersion: latest, currentVersion: current);
    _updateDialogShown = false;
  }

  Future<void> _showUpdateDialog({
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
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('下载完成，正在启动安装器...')));
      try {
        await AppUpdateService.installApk(apkFile);
      } catch (e) {
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('未能启动安装器'),
              content: Text(
                '安装包已下载，但未能自动拉起安装界面。\n\n'
                '请确认系统已允许本应用安装未知来源应用，然后重试。\n\n'
                '详情: $e',
              ),
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
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      messenger.hideCurrentSnackBar();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('下载失败'),
            content: Text('更新安装包下载失败，请稍后重试。\n\n原因: $e'),
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

  @override
  Widget build(BuildContext context) {
    if (_nextPage != null) {
      return _nextPage!;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FB), Color(0xFFD4E8F8), Color(0xFFEAF6FF)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image(image: AssetImage('assets/cwnu_badge_red.png'), height: 96),
              SizedBox(height: 14),
              Text(
                '稀饭课表',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 18),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
