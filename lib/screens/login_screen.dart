import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/api_providers.dart';
import '../services/api_interceptors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  // 注册额外字段
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authApiServiceProvider);
      if (_isLogin) {
        final resp = await authService.login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        await ref.read(authStateProvider.notifier).updateTokens(
          accessToken: resp.accessToken,
          refreshToken: resp.refreshToken,
        );
        final currentUser = await authService.getCurrentUser();
        await ref.read(authStateProvider.notifier).login(
          userId: currentUser.id,
          username: currentUser.username,
          email: currentUser.email,
          fullName: currentUser.fullName,
          accessToken: resp.accessToken,
          refreshToken: resp.refreshToken,
        );
      } else {
        final resp = await authService.register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
          fullName: _usernameCtrl.text.trim(),
        );
        final loginResp = await authService.login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        await ref.read(authStateProvider.notifier).updateTokens(
          accessToken: loginResp.accessToken,
          refreshToken: loginResp.refreshToken,
        );
        final currentUser = await authService.getCurrentUser();
        await ref.read(authStateProvider.notifier).login(
          userId: currentUser.id.isNotEmpty ? currentUser.id : resp.userId,
          username: currentUser.username.isNotEmpty ? currentUser.username : resp.username,
          email: currentUser.email.isNotEmpty ? currentUser.email : resp.email,
          fullName: currentUser.fullName.isNotEmpty ? currentUser.fullName : resp.fullName,
          accessToken: loginResp.accessToken,
          refreshToken: loginResp.refreshToken,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          _isLogin ? '登录账号' : '注册账号',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingL,
            AppTheme.spacingM,
            AppTheme.spacingL,
            AppTheme.spacingXL,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.96),
                        const Color(0xFFB73A3A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.cloud_sync_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isLogin ? '连接你的云端账本' : '创建你的云端身份',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin
                            ? '登录后即可同步礼簿数据，换机也不怕丢失。'
                            : '注册后可开启云端同步，本地数据依然可独立使用。',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          label: '登录',
                          selected: _isLogin,
                          onTap: () => setState(() {
                            _isLogin = true;
                            _error = null;
                          }),
                        ),
                      ),
                      Expanded(
                        child: _buildModeButton(
                          label: '注册',
                          selected: !_isLogin,
                          onTap: () => setState(() {
                            _isLogin = false;
                            _error = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isLogin ? '欢迎回来' : '填写注册信息',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLogin
                            ? '输入邮箱和密码即可继续。'
                            : '用户名和邮箱都必须唯一，密码至少 6 位。',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: _inputDecoration('用户名', Icons.person_outline),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return '请输入用户名';
                            if (value.length < 2) return '用户名至少2个字符';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('邮箱', Icons.email_outlined),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return '请输入邮箱';
                          if (!value.contains('@')) return '请输入有效的邮箱地址';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          '密码',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return '请输入密码';
                          if (!_isLogin && v.length < 6) return '密码至少6位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? '立即登录' : '创建并登录',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '登录仅用于数据云端同步\n本地数据始终可用',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      labelStyle:
          const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
