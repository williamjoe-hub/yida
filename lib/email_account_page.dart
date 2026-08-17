import 'package:flutter/material.dart';

import 'app_theme.dart';

class EmailAccountPage extends StatefulWidget {
  const EmailAccountPage({super.key});

  @override
  State<EmailAccountPage> createState() => _EmailAccountPageState();
}

class _EmailAccountPageState extends State<EmailAccountPage> {
  static const authApiUrl = String.fromEnvironment('AUTH_API_URL');
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool registering = false;
  bool obscurePassword = true;

  bool get configured => authApiUrl.isNotEmpty;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('邮箱账号')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const Text(
            '保存你的衣橱',
            style: TextStyle(
              fontSize: 30,
              height: 1.08,
              letterSpacing: -.7,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '登录后可为跨设备同步和恢复数据做好准备。',
            style: TextStyle(fontSize: 14, color: AppTheme.inkSoft),
          ),
          if (!configured) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEDC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFB46D3D),
                    size: 21,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '账号服务器尚未连接。为保护密码，现在不会在手机本地伪造注册。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF8D5835),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('登录')),
                ButtonSegment(value: true, label: Text('注册')),
              ],
              selected: {registering},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => registering = value.first),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            autofillHints: registering
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => obscurePassword = !obscurePassword),
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: configured ? _submit : null,
            child: Text(configured ? (registering ? '创建账号' : '登录') : '等待账号服务'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('先在本机使用'),
          ),
        ],
      ),
    ),
  );

  void _submit() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('账号接口已配置，但认证实现仍需服务端协议。')));
  }
}
