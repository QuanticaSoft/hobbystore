import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/config/app_config.dart';

void main() {
  final sessionStore = SecureSessionStore();
  final OtpService otpService = AppConfig.useMockOtp
      ? MockOtpService()
      : HttpOtpService(baseUrl: AppConfig.otpBaseUrl);

  runApp(
    HobbyStoreApp(
      otpService: otpService,
      sessionStore: sessionStore,
      api: ApiClient(
        baseUrl: AppConfig.apiBaseUrl,
        sessionStore: sessionStore,
        sendDevPhone: AppConfig.useMockOtp,
      ),
    ),
  );
}
