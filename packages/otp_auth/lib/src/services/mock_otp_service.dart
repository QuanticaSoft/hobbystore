import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../models/otp_models.dart';
import 'otp_service.dart';

class _PendingOtp {
  final String code;
  final DateTime expiresAt;
  final DateTime lastSentAt;
  int attempts = 0;
  bool used = false;

  _PendingOtp({
    required this.code,
    required this.expiresAt,
    required this.lastSentAt,
  });
}

/// Simula el gateway OTP real (Fases 2/3) para poder probar la UI ya.
///
/// Replica las mismas reglas que tendrá el backend real (TTL, un solo uso,
/// máximo de intentos, cooldown de reenvío) para que el flujo se sienta
/// idéntico al final y no haya sorpresas al conectar el backend de verdad.
class MockOtpService implements OtpService {
  static const _ttl = Duration(minutes: 5);
  static const _maxAttempts = 5;

  // Configurable solo para los tests: el mock mide el cooldown con el reloj
  // real, que el reloj virtual de los widget tests no adelanta.
  MockOtpService({this.resendCooldown = const Duration(seconds: 60)});

  final Duration resendCooldown;

  /// Código fijo para poder probar la app manualmente sin leer logs. En el
  /// backend real (Fase 2/3) el código sí será aleatorio.
  static const testCode = '123456';

  final Map<String, _PendingOtp> _byPhone = {};
  final Set<String> _verifiedPhones = {};
  final Map<String, String> _phoneBySessionToken = {};
  final Random _random = Random.secure();

  @override
  Future<OtpRequestResult> requestOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final existing = _byPhone[phone];
    if (existing != null) {
      final sinceLastSend = DateTime.now().difference(existing.lastSentAt);
      if (sinceLastSend < resendCooldown) {
        final wait = resendCooldown - sinceLastSend;
        return OtpRequestResult(
          status: OtpRequestStatus.rateLimited,
          message: 'Espera ${wait.inSeconds}s antes de pedir otro código.',
          resendCooldownSeconds: wait.inSeconds,
        );
      }
    }

    final now = DateTime.now();
    _byPhone[phone] = _PendingOtp(
      code: testCode,
      expiresAt: now.add(_ttl),
      lastSentAt: now,
    );

    return OtpRequestResult(
      status: OtpRequestStatus.sent,
      message: 'Código enviado por SMS.',
      expiresAt: now.add(_ttl),
      resendCooldownSeconds: resendCooldown.inSeconds,
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp(String phone, String code) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final pending = _byPhone[phone];
    if (pending == null) {
      return const OtpVerifyResult(
        status: OtpVerifyStatus.error,
        message: 'No hay un código pendiente para este número.',
      );
    }

    if (pending.used) {
      return const OtpVerifyResult(
        status: OtpVerifyStatus.invalidCode,
        message: 'Este código ya fue usado. Pide uno nuevo.',
      );
    }

    if (DateTime.now().isAfter(pending.expiresAt)) {
      return const OtpVerifyResult(
        status: OtpVerifyStatus.expired,
        message: 'El código expiró. Pide uno nuevo.',
      );
    }

    if (pending.attempts >= _maxAttempts) {
      return const OtpVerifyResult(
        status: OtpVerifyStatus.tooManyAttempts,
        message: 'Demasiados intentos fallidos. Pide un código nuevo.',
      );
    }

    if (code != pending.code) {
      pending.attempts++;
      final left = _maxAttempts - pending.attempts;
      return OtpVerifyResult(
        status: OtpVerifyStatus.invalidCode,
        message: left > 0
            ? 'Código incorrecto. Te quedan $left intento(s).'
            : 'Código incorrecto. Sin intentos restantes.',
      );
    }

    pending.used = true;
    final isNewUser = _verifiedPhones.add(phone);
    final token = base64Url
        .encode(List<int>.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    _phoneBySessionToken[token] = phone;
    return OtpVerifyResult(
      status: OtpVerifyStatus.verified,
      message: isNewUser
          ? 'Número verificado correctamente.'
          : 'Sesión iniciada.',
      sessionToken: token,
      isNewUser: isNewUser,
    );
  }

  @override
  Future<SessionCheckResult> checkSession(String token) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final phone = _phoneBySessionToken[token];
    if (phone == null) {
      return const SessionCheckResult(
        status: SessionCheckStatus.invalid,
        message: 'La sesión no es válida o expiró.',
      );
    }
    return SessionCheckResult(status: SessionCheckStatus.valid, phone: phone);
  }

  @override
  Future<void> logout(String token) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _phoneBySessionToken.remove(token);
  }
}
