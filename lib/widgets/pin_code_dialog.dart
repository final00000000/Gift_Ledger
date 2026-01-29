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

class _PinCodeDialogState extends State<PinCodeDialog> with SingleTickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  String _pin = '';
  String? _firstPin; // 设置模式下，第一次输入的PIN
  bool _isConfirming = false; // 设置模式下，是否正在确认
  
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
    
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _countdownTimer?.cancel();
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

    if (widget.isSettingPin) {
      _handleSettingLogic();
    } else {
      _handleVerifyLogic();
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

  void _handleSettingLogic() {
    if (!_isConfirming) {
      // 第一次输入完成
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _isConfirming = true;
      });
    } else {
      // 确认输入完成
      if (_pin == _firstPin) {
        // 两次一致
        if (widget.onPinSet != null) {
          widget.onPinSet!(_pin);
        }
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      } else {
        // 两次不一致
        CustomToast.show(context, '两次输入不一致，请重试', isError: true);
        setState(() {
          _pin = '';
          _firstPin = null;
          _isConfirming = false;
        });
        _triggerError();
      }
    }
  }

  void _triggerError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reset());
    if (!widget.isSettingPin) {
      CustomToast.show(context, '密码错误', isError: true);
    }
    setState(() {
      _pin = '';
    });
  }

  String get _displayTitle {
    if (widget.title != null) return widget.title!;
    if (widget.isSettingPin) {
      return _isConfirming ? '请再次确认密码' : '请设置6位安全密码';
    }
    return '请输入安全密码';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
          // 动态提示语（剩余次数或锁定倒计时）
          if (_lockUntil != null)
            Text(
              '锁定中，请在 $_timerText 后重试',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            )
          else if (!widget.isSettingPin && _remainingAttempts < 5)
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
          const SizedBox(height: 40),
          // 数字键盘
          _buildNumpad(),
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
