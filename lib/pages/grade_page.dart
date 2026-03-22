import 'package:flutter/material.dart';

import '../config/error_handler.dart';
import '../models/auth_session.dart';
import '../services/grade_service.dart';
import '../services/session_store.dart';

class GradePage extends StatefulWidget {
  const GradePage({super.key, required this.session});

  final AuthSession session;

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  Map<String, dynamic>? _rawData;
  List<GradeItem> _grades = [];
  List<Map<String, dynamic>> _semesters = [];
  String? _selectedSemesterId;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Map<String, dynamic> _stats = {};

  static const _defaultSemesters = [
    {'id': 221, 'nameZh': '2025-2026-1'},
    {'id': 241, 'nameZh': '2025-2026-2'},
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final cached = await SessionStore.loadGrades();
    if (cached != null && mounted) {
      _processData(cached);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
    _refreshGrades(silent: true);
  }

  void _processData(Map<String, dynamic> rawData) {
    final semesterGrades =
        rawData['semesterId2studentGrades'] as Map<String, dynamic>? ?? {};

    final semesters = List<Map<String, dynamic>>.from(_defaultSemesters);
    for (final sem in GradeService.getSemesters(rawData)) {
      if (!semesters.any((s) => s['id'] == sem['id'])) {
        semesters.add(sem);
      }
    }

    String? selectedId = _selectedSemesterId;
    if (selectedId == null) {
      for (final sem in semesters.reversed) {
        final id = sem['id'].toString();
        if (semesterGrades.containsKey(id)) {
          selectedId = id;
          break;
        }
      }
      selectedId ??= semesters.isNotEmpty
          ? semesters.first['id'].toString()
          : null;
    }

    _rawData = rawData;
    _semesters = semesters;
    _selectedSemesterId = selectedId;
    _updateGrades();
  }

  Future<void> _refreshGrades({bool silent = false}) async {
    if (_refreshing) return;

    if (!silent) setState(() => _loading = true);
    setState(() => _refreshing = true);

    try {
      final rawData = await GradeService.fetchGradesJson(
        ssoUsername: widget.session.username,
        ssoPassword: widget.session.password,
        jwxtUsername: widget.session.username,
        jwxtPassword: widget.session.jwxtPassword,
      );

      if (!mounted) return;

      await SessionStore.saveGrades(rawData);

      setState(() {
        _processData(rawData);
        _loading = false;
        _refreshing = false;
      });

      if (silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('成绩更新成功'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (!silent) _error = ErrorHandler.getFriendlyMessage(e);
      });
    }
  }

  void _updateGrades() {
    if (_rawData == null || _selectedSemesterId == null) return;
    final grades = GradeService.getGradesBySemester(
      _rawData!,
      _selectedSemesterId!,
    );
    setState(() {
      _grades = grades;
      _stats = GradeService.calculateStats(grades);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩查询'),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshGrades(silent: true),
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '加载失败',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _refreshGrades(),
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 学期选择器
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSemesterId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: _semesters.map((sem) {
                    return DropdownMenuItem(
                      value: sem['id'].toString(),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(sem['nameZh'] ?? sem['name'] ?? ''),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSemesterId = value;
                      _updateGrades();
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        // 统计卡片
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '总学分',
                  value:
                      (_stats['total_credits'] as double?)?.toStringAsFixed(
                        1,
                      ) ??
                      '0',
                  icon: Icons.credit_score,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '平均成绩',
                  value:
                      (_stats['avg_score'] as double?)?.toStringAsFixed(2) ??
                      '0',
                  icon: Icons.assessment,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '课程数',
                  value: (_stats['course_count'] as int?)?.toString() ?? '0',
                  icon: Icons.book,
                ),
              ),
            ],
          ),
        ),
        // 成绩列表
        Expanded(child: _buildGradeList(theme)),
      ],
    );
  }

  Widget _buildGradeList(ThemeData theme) {
    if (_grades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '暂无成绩数据',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '可能是成绩还没有出来哦',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _grades.length,
      itemBuilder: (context, index) => _GradeCard(grade: _grades[index]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.grade});

  final GradeItem grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.courseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      grade.courseType,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${grade.credit}学分',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  grade.score,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '绩点 ${grade.gradePoint}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
