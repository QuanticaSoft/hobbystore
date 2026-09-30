import 'dart:async';

import 'package:flutter/material.dart';

import '../models/otp_models.dart';
import '../otp_auth.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final OtpAuth auth;
  final DateTime? initialExpiresAt;
  final int initialResendCooldownSeconds;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.auth,
    this.initialExpiresAt,
    this.initialResendCooldownSeconds = 60,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  DateTime? _expiresAt;
  Timer? _ticker;
  int _resendSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _expiresAt = widget.initialExpiresAt;
    _resendSecondsLeft = widget.initialResendCooldownSeconds;
    _startTicker();
  }

  // Un solo timer de 1s repinta tanto la cuenta regresiva de expiración
  // como el cooldown de reenvío; evita manejar dos Timers en paralelo.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_resendSecondsLeft > 0) _resendSecondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Duration get _timeLeft {
    if (_expiresAt == null) return Duration.zero;
    final diff = _expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get _isExpired => _expiresAt != null && _timeLeft == Duration.zero;

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await widget.auth.otpService.verifyOtp(
      widget.phone,
      _codeController.text.trim(),
    );

    if (result.status == OtpVerifyStatus.verified &&
        result.sessionToken != null) {
      await widget.auth.sessionStore.save(result.sessionToken!);
    }

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.status == OtpVerifyStatus.verified) {
      // Se descarta todo el historial para que "atrás" no vuelva al OTP.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => widget.auth.homeBuilder(
            context,
            widget.auth,
            widget.phone,
            result.isNewUser,
          ),
        ),
        (_) => false,
      );
      return;
    }

    setState(() => _errorMessage = result.message);
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final result = await widget.auth.otpService.requestOtp(widget.phone);

    if (!mounted) return;
    setState(() {
      _isResending = false;
      if (result.status == OtpRequestStatus.sent) {
        _expiresAt = result.expiresAt;
        _codeController.clear();
      }
      _resendSecondsLeft = result.resendCooldownSeconds;
      _errorMessage = result.status == OtpRequestStatus.sent
          ? null
          : result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _timeLeft.inMinutes;
    final seconds = _timeLeft.inSeconds % 60;
    final canResend = _resendSecondsLeft <= 0 && !_isResending;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar código')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ingresa el código de 6 dígitos enviado a ${widget.phone}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('codeField'),
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(),
                    hintText: '••••••',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length != 6) {
                      return 'Ingresa los 6 dígitos del código';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (!_isExpired && _expiresAt != null)
                  Text(
                    'Expira en '
                    '${minutes.toString().padLeft(2, '0')}:'
                    '${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.grey),
                  )
                else if (_isExpired)
                  const Text(
                    'El código expiró.',
                    style: TextStyle(color: Colors.red),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (_isVerifying || _isExpired) ? null : _verify,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    canResend
                        ? 'Reenviar código'
                        : 'Reenviar código (${_resendSecondsLeft}s)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
