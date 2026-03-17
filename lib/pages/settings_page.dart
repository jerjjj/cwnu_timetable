import 'package:flutter/material.dart';

import '../services/session_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DateTime? _termStartDate;
  bool _isSaving = false;

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
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
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
                  '说明：课表页会根据该日期自动推断当前教学周。默认值为每年3月2日。',
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
                        : const Text('保存'),
                  ),
                ),
              ],
            ),
    );
  }
}
