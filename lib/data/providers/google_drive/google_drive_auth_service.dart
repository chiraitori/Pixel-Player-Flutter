import 'package:google_sign_in/google_sign_in.dart';

class GoogleDriveAuthService {
  GoogleDriveAuthService._();

  static final instance = GoogleDriveAuthService._();

  static const scopes = <String>[
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/drive.file',
  ];

  bool _initialized = false;
  String? _initializedClientId;
  GoogleDriveSession? _session;

  GoogleDriveSession? get currentSession => _session;

  Future<GoogleDriveSession> signIn({required String serverClientId}) async {
    final clientId = serverClientId.trim();
    if (clientId.isEmpty || !clientId.endsWith('.apps.googleusercontent.com')) {
      throw const GoogleDriveAuthException(
        'Enter a valid Google OAuth Web client ID.',
      );
    }
    await _initialize(clientId);
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: scopes,
      );
      final authorization =
          await account.authorizationClient.authorizationForScopes(scopes) ??
          await account.authorizationClient.authorizeScopes(scopes);
      final session = GoogleDriveSession(
        account: account,
        accessToken: authorization.accessToken,
      );
      _session = session;
      return session;
    } on GoogleSignInException catch (error) {
      throw GoogleDriveAuthException(_messageFor(error));
    }
  }

  Future<GoogleDriveSession?> restore({required String serverClientId}) async {
    final clientId = serverClientId.trim();
    if (clientId.isEmpty) return null;
    try {
      await _initialize(clientId);
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      final account = attempt == null ? null : await attempt;
      if (account == null) return null;
      final authorization = await account.authorizationClient
          .authorizationForScopes(scopes);
      if (authorization == null) return null;
      return _session = GoogleDriveSession(
        account: account,
        accessToken: authorization.accessToken,
      );
    } on Object {
      return null;
    }
  }

  Future<void> disconnect() async {
    _session = null;
    if (_initialized) await GoogleSignIn.instance.disconnect();
  }

  Future<String?> refreshAccessToken() async {
    final account = _session?.account;
    if (account == null) return null;
    try {
      final authorization = await account.authorizationClient
          .authorizationForScopes(scopes);
      if (authorization == null) return null;
      _session = GoogleDriveSession(
        account: account,
        accessToken: authorization.accessToken,
      );
      return authorization.accessToken;
    } on GoogleSignInException {
      return null;
    }
  }

  Future<void> _initialize(String clientId) async {
    if (_initialized) {
      if (_initializedClientId != clientId) {
        throw const GoogleDriveAuthException(
          'The OAuth client ID changed. Restart PixelPlay before signing in.',
        );
      }
      return;
    }
    await GoogleSignIn.instance.initialize(serverClientId: clientId);
    _initialized = true;
    _initializedClientId = clientId;
  }

  String _messageFor(GoogleSignInException error) => switch (error.code) {
    GoogleSignInExceptionCode.canceled => 'Google sign-in was canceled.',
    GoogleSignInExceptionCode.clientConfigurationError =>
      'Google sign-in is not configured for com.chiraitori.pixelplay. '
          'Check the OAuth client ID, package name, and SHA certificate.',
    GoogleSignInExceptionCode.interrupted =>
      'Google sign-in was interrupted. Try again.',
    GoogleSignInExceptionCode.uiUnavailable =>
      'Google sign-in UI is unavailable on this device.',
    _ => error.description ?? 'Google sign-in failed.',
  };
}

class GoogleDriveSession {
  const GoogleDriveSession({required this.account, required this.accessToken});

  final GoogleSignInAccount account;
  final String accessToken;
}

class GoogleDriveAuthException implements Exception {
  const GoogleDriveAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
