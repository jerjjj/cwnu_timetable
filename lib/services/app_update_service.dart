import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
  static String? _lastDownloadedApkPath;

  static String? get lastDownloadedApkPath => _lastDownloadedApkPath;

  static const _versionCandidates = <String>[
    'https://gitee.com/jerjjj_admin/xifankebiao/raw/master/Version',
  ];

  static Future<String?> fetchLatestVersion() async {
    for (final url in _versionCandidates) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final version = response.body
            .trim()
            .replaceAll('\n', '')
            .replaceAll('\r', '');
        if (version.isNotEmpty) {
          return version;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<String> currentAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version.trim();
  }

  static bool isNewerVersion({
    required String latest,
    required String current,
  }) {
    final latestParts = _normalizeParts(latest);
    final currentParts = _normalizeParts(current);
    final maxLen = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < maxLen; i++) {
      final a = i < latestParts.length ? latestParts[i] : 0;
      final b = i < currentParts.length ? currentParts[i] : 0;
      if (a > b) {
        return true;
      }
      if (a < b) {
        return false;
      }
    }
    return false;
  }

  static List<int> _normalizeParts(String raw) {
    final plain = raw
        .split('+')
        .first
        .trim()
        .replaceAll(RegExp(r'^[^0-9]+'), '');
    return plain
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  static String buildApkUrl(String version) {
    return 'https://gitee.com/jerjjj_admin/xifankebiao/releases/download/$version/app-arm64-v8a-release.apk';
  }

  static Future<File> downloadApk({
    required String version,
    void Function(int received, int total)? onProgress,
  }) async {
    final url = buildApkUrl(version);
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('下载安装包失败: HTTP ${response.statusCode}');
      }

      final bytes = <int>[];
      final total = response.contentLength ?? -1;
      var received = 0;
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }

      if (bytes.isEmpty) {
        throw Exception('下载安装包失败: 下载内容为空');
      }

      final dir = await _resolvePreferredDownloadDir();
      final file = File(
        '${dir.path}${Platform.pathSeparator}xifankebiao-$version.apk',
      );
      await file.writeAsBytes(bytes, flush: true);
      _lastDownloadedApkPath = file.path;
      return file;
    } finally {
      client.close();
    }
  }

  static Future<Directory> _resolvePreferredDownloadDir() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        await downloads.create(recursive: true);
        return downloads;
      }
    } catch (_) {
      // Ignore and fallback.
    }

    final temp = await getTemporaryDirectory();
    await temp.create(recursive: true);
    return temp;
  }

  static Future<void> installApk(File apkFile) async {
    final result = await OpenFilex.open(apkFile.path);
    if (result.type != ResultType.done) {
      throw Exception(
        '无法拉起安装器(${result.type.name}): ${result.message}\n安装包路径: ${apkFile.path}',
      );
    }
  }
}
