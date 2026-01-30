import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';

class PinCodeDialog extends StatefulWidget {
  final bool isSettingPin; // 是否为设置模式
  final Function(String)? onPinSet; // 设置成功回调
  final String? title;

  const PinCodeDialog({
    super.key,
    this.isSettingPin = false,
    this.onPinSet,
    this.title,
  });

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PinCodeDialog(),
    );
    return result ?? false;
  }

  @override
  State<PinCodeDialog> createState() => _PinCodeDialogState();
}

enum _DialogMode {
  enterPin,        // 输入密码
  confirmPin,      // 确认密码（设置模式）
  setHint,         // 设置提示问题（设置模式）
  forgotPassword,  // 忘记密码 - 输入答案
  resetPin,        // 重置密码 - 输入新密码
  resetConfirm,    // 重置密码 - 确认新密码
}

class _PinCodeDialogState extends State<PinCodeDialog> with SingleTickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  String _pin = '';
  String? _firstPin; // 设置模式下，第一次输入的PIN
  _DialogMode _mode = _DialogMode.enterPin;

  // 提示问题相关
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  String? _securityQuestion; // 忘记密码时显示的问题

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // 锁定与次数相关状态
  int _remainingAttempts = 5;
  DateTime? _lockUntil;
  Timer? _countdownTimer;
  String _timerText = '';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    if (widget.isSettingPin) {
      _mode = _DialogMode.enterPin;
    }
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _countdownTimer?.cancel();
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    final lockUntil = await _securityService.getLockUntil();
    final remaining = await _securityService.getRemainingAttempts();

    if (mounted) {
      setState(() {
        _lockUntil = lockUntil;
        _remainingAttempts = remaining;
      });

      if (_lockUntil != null) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateTimerText();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockUntil == null || DateTime.now().isAfter(_lockUntil!)) {
        timer.cancel();
        setState(() {
          _lockUntil = null;
          _remainingAttempts = 5;
        });
      } else {
        _updateTimerText();
      }
    });
  }

  void _updateTimerText() {
    if (_lockUntil == null) return;
    final diff = _lockUntil!.difference(DateTime.now());
    final seconds = diff.inSeconds % 60;
    final minutes = diff.inMinutes;
    setState(() {
      _timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    });
  }

  void _onDigitPressed(String digit) {
    if (_lockUntil != null) return; // 锁定中禁止输入

    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
      });
      HapticFeedback.lightImpact();

      if (_pin.length == 6) {
        _handlePinComplete();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _handlePinComplete() async {
    // 延迟一点，让用户看到第6个点亮起
    await Future.delayed(const Duration(milliseconds: 100));

    switch (_mode) {
      case _DialogMode.enterPin:
        if (widget.isSettingPin) {
          // 设置模式：进入确认
          setState(() {
            _firstPin = _pin;
            _pin = '';
            _mode = _DialogMode.confirmPin;
          });
        } else {
          // 验证模式
          _handleVerifyLogic();
        }
        break;
      case _DialogMode.confirmPin:
        _handleConfirmLogic();
        break;
      case _DialogMode.resetPin:
        // 重置密码：进入确认
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _mode = _DialogMode.resetConfirm;
        });
        break;
      case _DialogMode.resetConfirm:
        _handleResetConfirmLogic();
        break;
      default:
        break;
    }
  }

  Future<void> _handleVerifyLogic() async {
    final isValid = await _securityService.verifyPin(_pin);
    if (isValid) {
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } else {
      await _checkLockoutStatus(); // 更新剩余次数和锁定状态
      _triggerError();
    }
  }

  void _handleConfirmLogic() {
    if (_pin == _firstPin) {
      // 两次一致，进入设置提示问题
      setState(() {
        _mode = _DialogMode.setHint;
      });
    } else {
      // 两次不一致
      CustomToast.show(context, '两次输入不一致，请重试', isError: true);
      setState(() {
        _pin = '';
        _firstPin = null;
        _mode = _DialogMode.enterPin;
      });
      _triggerError();
    }
  }

  Future<void> _handleResetConfirmLogic() async {
    if (_pin == _firstPin) {
      // 两次一致，保存新密码
      await _securityService.setPin(_pin);
      HapticFeedback.mediumImpact();
      if (mounted) {
        CustomToast.show(context, '密码重置成功');
        Navigator.pop(context, true);
      }
    } else {
      // 两次不一致
      CustomToast.show(context, '两次输入不一致，请重试', isError: true);
      setState(() {
        _pin = '';
        _firstPin = null;
        _mode = _DialogMode.resetPin;
      });
      _triggerError();
    }
  }

  Future<void> _savePasswordWithHint() async {
    final question = _questionController.text.trim();
    final answer = _answerController.text.trim();

    // 验证问题和答案必填
    if (question.isEmpty) {
      CustomToast.show(context, '请输入提示问题', isError: true);
      return;
    }
    if (answer.isEmpty) {
      CustomToast.show(context, '请输入答案', isError: true);
      return;
    }

    // 保存密码
    if (widget.onPinSet != null) {
      widget.onPinSet!(_firstPin!);
    }

    // 保存提示问题和答案
    await _securityService.setSecurityHint(question, answer);

    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _showForgotPassword() async {
    // 检查是否设置了提示问题
    final hasHint = await _securityService.hasSecurityHint();
    if (!hasHint) {
      if (mounted) {
        CustomToast.show(context, '未设置密码提示，无法找回', isError: true);
      }
      return;
    }

    final question = await _securityService.getSecurityQuestion();
    setState(() {
      _securityQuestion = question;
      _mode = _DialogMode.forgotPassword;
      _pin = '';
      _answerController.clear();
    });
  }

  Future<void> _verifySecurityAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      CustomToast.show(context, '请输入答案', isError: true);
      return;
    }

    final isValid = await _securityService.verifySecurityAnswer(answer);
    if (isValid) {
      // 答案正确，重置密码
      await _securityService.resetPassword();
      // 清除本地锁定状态和倒计时
      _countdownTimer?.cancel();
      if (mounted) {
        CustomToast.show(context, '验证成功，请设置新密码');
        setState(() {
          _mode = _DialogMode.resetPin;
          _pin = '';
          _firstPin = null;
          _answerController.clear();
          _lockUntil = null;
          _remainingAttempts = 5;
        });
      }
    } else {
      CustomToast.show(context, '答案错误', isError: true);
      _triggerError();
    }
  }

  void _triggerError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reset());
    if (_mode == _DialogMode.enterPin && !widget.isSettingPin) {
      CustomToast.show(context, '密码错误', isError: true);
    }
    setState(() {
      _pin = '';
    });
  }

  String get _displayTitle {
    if (widget.title != null && _mode == _DialogMode.enterPin) return widget.title!;

    switch (_mode) {
      case _DialogMode.enterPin:
        return widget.isSettingPin ? '请设置6位安全密码' : '请输入安全密码';
      case _DialogMode.confirmPin:
        return '请再次确认密码';
      case _DialogMode.setHint:
        return '设置密码提示';
      case _DialogMode.forgotPassword:
        return '验证密码提示';
      case _DialogMode.resetPin:
        return '请设置新密码';
      case _DialogMode.resetConfirm:
        return '请再次确认新密码';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final needsScroll = _mode == _DialogMode.setHint || _mode == _DialogMode.forgotPassword;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: needsScroll ? bottomInset : 0),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              // 拖动条
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              // 标题
              Text(
                _displayTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // 根据模式显示不同内容
              if (_mode == _DialogMode.setHint)
                _buildHintForm()
              else if (_mode == _DialogMode.forgotPassword)
                _buildForgotPasswordForm()
              else
                _buildPinInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinInput() {
    return Column(
      children: [
        // 动态提示语（剩余次数或锁定倒计时）
        if (_lockUntil != null)
          Text(
            '锁定中，请在 $_timerText 后重试',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          )
        else if (!widget.isSettingPin && _mode == _DialogMode.enterPin && _remainingAttempts < 5)
          Text(
            '密码错误，还剩 $_remainingAttempts 次机会',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
          )
        else
          const SizedBox(height: 18), // 占位保持高度一致
        const SizedBox(height: 32),
        // 密码点
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset = _shakeAnimation.value * 10 * (
              (_shakeController.value * 3).toInt().isEven ? 1 : -1
            );
            return Transform.translate(
              offset: Offset(offset, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isFilled ? AppTheme.primaryColor : AppTheme.backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFilled ? AppTheme.primaryColor : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
        // 忘记密码按钮（仅在验证模式下显示）
        if (!widget.isSettingPin && _mode == _DialogMode.enterPin) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _showForgotPassword,
            child: Text(
              '忘记密码？',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ] else
          const SizedBox(height: 40),
        // 数字键盘
        _buildNumpad(),
      ],
    );
  }

  Widget _buildHintForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            '设置提示问题可在忘记密码时找回',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          // 问题输入框
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              labelText: '提示问题 *',
              hintText: '例如：我的宠物叫什么？',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          // 答案输入框
          TextField(
            controller: _answerController,
            decoration: InputDecoration(
              labelText: '答案 *',
              hintText: '请输入答案（不区分大小写）',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _savePasswordWithHint(),
          ),
          const SizedBox(height: 32),
          // 完成按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savePasswordWithHint,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '完成',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // 显示提示问题
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '提示问题',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _securityQuestion ?? '',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 答案输入框
          TextField(
            controller: _answerController,
            decoration: InputDecoration(
              labelText: '请输入答案',
              hintText: '答案不区分大小写',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifySecurityAnswer(),
          ),
          const SizedBox(height: 32),
          // 按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _mode = _DialogMode.enterPin;
                      _answerController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
                  ),
                  child: Text(
                    '返回',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _verifySecurityAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '验证',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    return Opacity(
      opacity: _lockUntil != null ? 0.3 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            _buildRow(['1', '2', '3']),
            const SizedBox(height: 24),
            _buildRow(['4', '5', '6']),
            const SizedBox(height: 24),
            _buildRow(['7', '8', '9']),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 80), // 占位
                _buildDigitButton('0'),
                _buildActionButton(
                  icon: Icons.backspace_rounded,
                  onPressed: _onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: Icon(icon, size: 32, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
