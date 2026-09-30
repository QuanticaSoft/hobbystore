import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/otp_models.dart';
import '../otp_auth.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  final OtpAuth auth;

  const PhoneScreen({super.key, required this.auth});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  static const _countryCode = '+591'; // Bolivia / Entel

  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhone => '$_countryCode${_phoneController.text.trim()}';

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final result = await widget.auth.otpService.requestOtp(_fullPhone);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.status != OtpRequestStatus.sent) {
      setState(() => _errorMessage = result.message);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phone: _fullPhone,
          auth: widget.auth,
          initialExpiresAt: result.expiresAt,
          initialResendCooldownSeconds: result.resendCooldownSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar número')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ingresa tu número de celular para recibir un código de '
                  'verificación por SMS.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('phoneField'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    prefixText: '$_countryCode ',
                    border: OutlineInputBorder(),
                    hintText: '7XXXXXXX',
                  ),
                  validator: (value) {
                    final digits = value?.trim() ?? '';
                    if (digits.length != 8) {
                      return 'Ingresa un número de 8 dígitos';
                    }
                    return null;
                  },
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
                  onPressed: _isSending ? null : _sendCode,
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar código'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
