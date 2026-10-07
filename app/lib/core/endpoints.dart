/// Endpoint configuration. Overridable at build time:
/// `flutter run --dart-define=API_BASE_URL=... --dart-define=AUTH_BASE_URL=...`
/// Defaults point at this project's own backend (dev tunnel/prod URL set at
/// release; local shelf for development).
class Endpoints {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const authBaseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue:
        'https://ep-polished-mouse-b15ihsmx.neonauth.c-5.eu-central-1.aws.neon.tech/neondb/auth',
  );

  /// Default magic-link callback for native (mobile/desktop) builds.
  /// Web uses the app origin instead (see sign-in screen).
  static const mobileCallbackUrl = 'https://bachi.dev/work';
}
