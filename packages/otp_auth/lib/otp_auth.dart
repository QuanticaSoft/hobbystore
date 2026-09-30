/// Login por OTP compartido: registro y login son el mismo flujo
/// (StartupScreen → PhoneScreen → OtpScreen → la home de cada app).
library;

export 'src/models/otp_models.dart';
export 'src/otp_auth.dart';
export 'src/screens/otp_screen.dart';
export 'src/screens/phone_screen.dart';
export 'src/screens/startup_screen.dart';
export 'src/services/http_otp_service.dart';
export 'src/services/mock_otp_service.dart';
export 'src/services/otp_service.dart';
export 'src/services/session_store.dart';
