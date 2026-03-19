import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_session.dart';
import '../providers/app_providers.dart';
import '../services/timetable_api.dart';
import 'home_dock_page.dart';
import 'dart:typed_data';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static final Uri _jwxtHelpUri = Uri.parse(
    'https://www.kdocs.cn/l/clr9aN3uXwoF',
  );
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jwxtPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _jwxtPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final session = AuthSession(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      jwxtPassword: _jwxtPasswordController.text,
    );

    await _loginAndEnter(session: session);
  }

  Future<void> _openJwxtHelp() async {
    await launchUrl(_jwxtHelpUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _loginAndEnter({required AuthSession session}) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // 第一阶段：检查验证码
      final captchaBytes = await TimetableApi.checkSsoCaptcha(
        ssoUsername: session.username,
        ssoPassword: session.password,
      );

      String captchaText = '';
      if (captchaBytes != null && mounted) {
        // 弹出验证码输入窗口
        captchaText = await _showCaptchaDialog(captchaBytes) ?? '';
        if (captchaText.isEmpty) {
          // 用户取消
          setState(() {
            _isLoading = false;
            _errorText = '已取消登录';
          });
          return;
        }
      }

      // 第二阶段：完成登录 + 拉取课表
      final records = await TimetableApi.fetchReadableTimetableWithCaptcha(
        jwxtUsername: session.username,
        jwxtPassword: session.jwxtPassword,
        captcha: captchaText,
      );
      await ref.read(authSessionProvider.notifier).login(session);
      await ref.read(coursesProvider.notifier).refresh(records);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              HomeDockPage(session: session, initialRecords: records),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 显示验证码输入对话框，返回用户输入的文本；取消时返回 null。
  Future<String?> _showCaptchaDialog(Uint8List imageBytes) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('请输入验证码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                imageBytes,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  '验证码图片加载失败',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '验证码',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FB), Color(0xFFD4E8F8), Color(0xFFEAF6FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/cwnu_badge_red.png',
                              height: 88,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              '登录',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('首次登录后会保存登录信息，后续进入应用将自动刷新课表。'),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: '信息门户账号',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? '请输入账号'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '信息门户密码',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? '请输入密码'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _jwxtPasswordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: '教务系统密码',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                      ? '请输入教务系统密码'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _openJwxtHelp,
                                tooltip: '查看教务系统密码说明',
                                icon: const Icon(Icons.help_outline),
                              ),
                            ],
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _errorText!,
                              style: const TextStyle(color: Color(0xFFB3261E)),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('登录并获取课表'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
