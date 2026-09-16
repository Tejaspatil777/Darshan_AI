/// Base URL of the Spring Boot backend.
///
/// The only supported configuration is the manual compile-time define:
///
/// Example: `flutter run --dart-define=DARSHAN_API_URL=http://PC-IP:8000`
///
/// Defaults:
/// - local development ......... http://localhost:8000
/// - Android emulator .......... http://10.0.2.2:8000 (pass via --dart-define)
///
/// PHYSICAL DEVICE: the phone and the PC must be on the same LAN, and the
/// value baked here MUST be the PC's current LAN IPv4 (String.fromEnvironment
/// is compile-time only - changing WiFi/IP later does NOT update the app).
///
/// There is intentionally NO automatic server discovery (no mDNS, no Bonjour,
/// no IP scanning) — see task rule 20.
const String kDarshanApiUrl = String.fromEnvironment(
  'DARSHAN_API_URL',
  defaultValue: 'http://10.31.152.187:8000',
);

/// Strips any trailing slash so paths can be appended safely.
String normalizeBaseUrl(String raw) {
  final String trimmed = raw.trim();
  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}
