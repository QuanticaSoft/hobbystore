import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/otp_models.dart';
import 'otp_service.dart';

/// Implementación real de [OtpService] contra el backend PHP en
/// flamenco.cnb.net (Fase 2), que a su vez reenvía al gateway SMS real
/// (Fase 3/4, Raspberry Pi nas-meteo). La app nunca habla con la Pi
/// directamente — ver backend_flamenco/otp/README.md y
/// backend_gateway/README.md para la arquitectura completa.
class HttpOtpService implements OtpService {
  HttpOtpService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// Base del backend en flamenco, SIN slash final, ej.
  /// "https://www.quanticasoft.com/otp" (request.php/verify.php cuelgan de
  /// ahí).
  final String baseUrl;
  final http.Client _client;

  @override
  Future<OtpRequestResult> requestOtp(String phone) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/request.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 15));

      final body = _decode(res.body);
      final expiresAtRaw = body['expiresAt'];
      return OtpRequestResult(
        status: _requestStatus(body['status'] as String?),
        message:
            (body['message'] as String?) ??
            'Respuesta inesperada del servidor.',
        expiresAt: expiresAtRaw is int
            ? DateTime.fromMillisecondsSinceEpoch(expiresAtRaw * 1000)
            : null,
        resendCooldownSeconds: (body['resendCooldownSeconds'] as int?) ?? 60,
      );
    } catch (e) {
      return OtpRequestResult(
        status: OtpRequestStatus.error,
        message: 'No se pudo contactar al servidor: $e',
      );
    }
  }

  @override
  Future<OtpVerifyResult> verifyOtp(String phone, String code) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/verify.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'code': code}),
          )
          .timeout(const Duration(seconds: 15));

      final body = _decode(res.body);
      return OtpVerifyResult(
        status: _verifyStatus(body['status'] as String?),
        message:
            (body['message'] as String?) ??
            'Respuesta inesperada del servidor.',
        sessionToken: body['sessionToken'] as String?,
        isNewUser: (body['isNewUser'] as bool?) ?? true,
      );
    } catch (e) {
      return OtpVerifyResult(
        status: OtpVerifyStatus.error,
        message: 'No se pudo contactar al servidor: $e',
      );
    }
  }

  @override
  Future<SessionCheckResult> checkSession(String token) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/session.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 15));

      final body = _decode(res.body);
      final message = (body['message'] as String?) ?? '';
      switch (body['status']) {
        case 'valid':
          return SessionCheckResult(
            status: SessionCheckStatus.valid,
            phone: body['phone'] as String?,
          );
        case 'invalid':
          return SessionCheckResult(
            status: SessionCheckStatus.invalid,
            message: message,
          );
        default:
          return SessionCheckResult(
            status: SessionCheckStatus.error,
            message: message.isEmpty
                ? 'Respuesta inesperada del servidor.'
                : message,
          );
      }
    } catch (e) {
      return SessionCheckResult(
        status: SessionCheckStatus.error,
        message: 'No se pudo contactar al servidor: $e',
      );
    }
  }

  @override
  Future<void> logout(String token) async {
    // Si falla (sin red), igual se borra el token local: la sesión del
    // servidor queda huérfana y expira sola.
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/logout.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Map<String, dynamic> _decode(String rawBody) {
    final decoded = jsonDecode(rawBody);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  OtpRequestStatus _requestStatus(String? raw) {
    switch (raw) {
      case 'sent':
        return OtpRequestStatus.sent;
      case 'rateLimited':
        return OtpRequestStatus.rateLimited;
      case 'blocked':
        return OtpRequestStatus.blocked;
      default:
        return OtpRequestStatus.error;
    }
  }

  OtpVerifyStatus _verifyStatus(String? raw) {
    switch (raw) {
      case 'verified':
        return OtpVerifyStatus.verified;
      case 'invalidCode':
        return OtpVerifyStatus.invalidCode;
      case 'expired':
        return OtpVerifyStatus.expired;
      case 'tooManyAttempts':
        return OtpVerifyStatus.tooManyAttempts;
      default:
        return OtpVerifyStatus.error;
    }
  }
}
