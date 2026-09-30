import 'package:flutter/material.dart';

import '../models/otp_models.dart';
import '../otp_auth.dart';
import 'phone_screen.dart';

/// Decide la pantalla inicial: si hay una sesión guardada y el servidor la
/// acepta, entra directo sin pedir otro OTP.
class StartupScreen extends StatefulWidget {
  final OtpAuth auth;

  const StartupScreen({super.key, required this.auth});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    setState(() => _errorMessage = null);

    final token = await widget.auth.sessionStore.read();
    if (token == null) {
      _goTo((_) => PhoneScreen(auth: widget.auth));
      return;
    }

    final result = await widget.auth.otpService.checkSession(token);
    if (!mounted) return;

    switch (result.status) {
      case SessionCheckStatus.valid:
        _goTo(
          (context) => widget.auth.homeBuilder(
            context,
            widget.auth,
            result.phone ?? '',
            false,
          ),
        );
      case SessionCheckStatus.invalid:
        await widget.auth.sessionStore.clear();
        _goTo((_) => PhoneScreen(auth: widget.auth));
      case SessionCheckStatus.error:
        // Sin red no se borra el token: la sesión puede seguir siendo válida.
        setState(() => _errorMessage = result.message);
    }
  }

  void _goTo(WidgetBuilder builder) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _errorMessage == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _checkSession,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
