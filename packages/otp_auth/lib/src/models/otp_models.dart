/// Resultado de pedir un código OTP.
enum OtpRequestStatus { sent, rateLimited, blocked, error }

class OtpRequestResult {
  final OtpRequestStatus status;
  final String message;

  /// Cuándo expira el código enviado (para mostrar cuenta regresiva).
  final DateTime? expiresAt;

  /// Segundos que el usuario debe esperar antes de poder reenviar.
  final int resendCooldownSeconds;

  const OtpRequestResult({
    required this.status,
    required this.message,
    this.expiresAt,
    this.resendCooldownSeconds = 60,
  });
}

/// Resultado de verificar un código OTP.
enum OtpVerifyStatus { verified, invalidCode, expired, tooManyAttempts, error }

class OtpVerifyResult {
  final OtpVerifyStatus status;
  final String message;

  /// Solo en [OtpVerifyStatus.verified]: registro y login son el mismo
  /// flujo, así que verificar el número siempre abre una sesión.
  final String? sessionToken;

  /// `false` si el número ya estaba verificado (es un login, no un registro).
  final bool isNewUser;

  const OtpVerifyResult({
    required this.status,
    required this.message,
    this.sessionToken,
    this.isNewUser = true,
  });
}

/// Resultado de validar una sesión guardada al abrir la app.
///
/// [SessionCheckStatus.error] (sin red, servidor caído) es distinto de
/// [SessionCheckStatus.invalid]: en ese caso no hay que borrar el token.
enum SessionCheckStatus { valid, invalid, error }

class SessionCheckResult {
  final SessionCheckStatus status;
  final String? phone;
  final String message;

  const SessionCheckResult({
    required this.status,
    this.phone,
    this.message = '',
  });
}
