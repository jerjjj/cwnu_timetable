import 'package:flutter/material.dart';

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  static const _licenses = [
    _LicenseEntry(
      name: 'Flutter',
      description: 'Google UI toolkit',
      license: 'BSD 3-Clause',
      url: 'https://flutter.dev',
    ),
    _LicenseEntry(
      name: 'flutter_riverpod',
      description: '状态管理',
      license: 'MIT',
      url: 'https://riverpod.dev',
    ),
    _LicenseEntry(
      name: 'shared_preferences',
      description: '本地键值存储',
      license: 'BSD 3-Clause',
      url: 'https://pub.dev/packages/shared_preferences',
    ),
    _LicenseEntry(
      name: 'flutter_secure_storage',
      description: '安全存储',
      license: 'BSD 3-Clause',
      url: 'https://pub.dev/packages/flutter_secure_storage',
    ),
    _LicenseEntry(
      name: 'auto_size_text',
      description: '自适应文本',
      license: 'MIT',
      url: 'https://pub.dev/packages/auto_size_text',
    ),
    _LicenseEntry(
      name: 'flutter_rust_bridge',
      description: 'Flutter-Rust 桥接',
      license: 'MIT',
      url: 'https://github.com/fzyzcjy/flutter_rust_bridge',
    ),
    _LicenseEntry(
      name: 'url_launcher',
      description: 'URL 启动器',
      license: 'BSD 3-Clause',
      url: 'https://pub.dev/packages/url_launcher',
    ),
    _LicenseEntry(
      name: 'http',
      description: 'HTTP 客户端',
      license: 'BSD 3-Clause',
      url: 'https://pub.dev/packages/http',
    ),
    _LicenseEntry(
      name: 'package_info_plus',
      description: '应用包信息',
      license: 'BSD 3-Clause',
      url: 'https://pub.dev/packages/package_info_plus',
    ),
    _LicenseEntry(
      name: 'path_provider',
      description: '文件路径获取',
      license: 'BSD 3-Clause',
      url: 'https://pub.dev/packages/path_provider',
    ),
    _LicenseEntry(
      name: 'open_filex',
      description: '文件打开器',
      license: 'BSD 3-Clause',
      url: 'https://pub.dev/packages/open_filex',
    ),
    _LicenseEntry(
      name: 'flutter_launcher_icons',
      description: '应用图标生成',
      license: 'MIT',
      url: 'https://pub.dev/packages/flutter_launcher_icons',
    ),
    _LicenseEntry(
      name: 'cupertino_icons',
      description: 'iOS 风格图标',
      license: 'MIT',
      url: 'https://pub.dev/packages/cupertino_icons',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('开源依赖')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '本应用基于以下开源项目构建',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ..._licenses.map((entry) => _LicenseCard(entry: entry)),
          const SizedBox(height: 24),
          Text(
            '感谢所有开源项目的贡献者',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseEntry {
  const _LicenseEntry({
    required this.name,
    required this.description,
    required this.license,
    required this.url,
  });

  final String name;
  final String description;
  final String license;
  final String url;
}

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.entry});

  final _LicenseEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          entry.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(entry.description),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            entry.license,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
