import '../models/otp_models.dart';

/// Contrato de red para el ciclo OTP, independiente de la implementación.
///
/// Las pantallas dependen solo de esta interfaz. Así, cuando el backend real
/// exista (Fase 2/3), basta con inyectar una implementación HTTP en vez del
/// mock, sin cambiar la UI.
abstract class OtpService {
  Future<OtpRequestResult> requestOtp(String phone);
  Future<OtpVerifyResult> verifyOtp(String phone, String code);
  Future<SessionCheckResult> checkSession(String token);
  Future<void> logout(String token);
}
