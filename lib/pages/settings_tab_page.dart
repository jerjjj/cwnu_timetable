import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/update_helper.dart';
import 'licenses_page.dart';

class SettingsTabPage extends ConsumerStatefulWidget {
  const SettingsTabPage({
    super.key,
    required this.onTermStartDateChanged,
    required this.onLogout,
  });

  final VoidCallback onTermStartDateChanged;
  final Future<void> Function() onLogout;

  @override
  ConsumerState<SettingsTabPage> createState() => _SettingsTabPageState();
}

class _SettingsTabPageState extends ConsumerState<SettingsTabPage> {
  static const _shareUrl = 'https://gitee.com/jerjjj_admin/xifankebiao/';
  DateTime? _termStartDate;
  bool _isSaving = false;
  bool _isLoggingOut = false;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final date = ref.read(termStartDateProvider);
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

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统设置';
      case ThemeMode.light:
        return '始终使用浅色';
      case ThemeMode.dark:
        return '始终使用深色';
    }
  }

  Future<void> _pickDate() async {
    final current =
        (_termStartDate ?? ref.read(termStartDateProvider)) as DateTime;
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

    await ref.read(termStartDateProvider.notifier).update(date);
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
      await UpdateHelper.checkAndPromptUpdate(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      await UpdateHelper.showSimpleDialog(
        context,
        title: '检查失败',
        message: '检查更新失败：$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _termStartDate;
    final themeMode = ref.watch(themeModeProvider);

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
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('外观模式'),
                        subtitle: Text(_themeModeLabel(themeMode)),
                        trailing: const Icon(Icons.palette_outlined),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto),
                              label: Text('跟随系统'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode),
                              label: Text('浅色'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode),
                              label: Text('深色'),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (selected) {
                            ref
                                .read(themeModeProvider.notifier)
                                .update(selected.first);
                          },
                          showSelectedIcon: false,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '默认开学日期：3月2日。课表页会按该日期自动切换到当前周。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LicensesPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('开源依赖'),
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
