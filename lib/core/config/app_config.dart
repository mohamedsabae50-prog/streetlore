class AppConfig {
  AppConfig._();
  static const String supabaseUrl = 'https://tbivoxyxclwjjspwsgvc.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiaXZveHl4Y2x3ampzcHdzZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMjA3NjMsImV4cCI6MjA5OTg5Njc2M30.uM9F6_O-ObiiVkF8hjQmsFovf3h4gTaode719u6bAnI';
  static const bool supabaseEnabled = true;

  /// Real Gemini API keys are injected at build time via `--dart-define`
  /// (kept OUT of source so GitHub's secret scanner doesn't block
  /// pushes). Example:
  ///
  ///   flutter build apk --release \
  ///     --dart-define=GEMINI_API_KEYS=key1,key2,key3 \
  ///     --target-platform android-arm64
  ///
  /// If no keys are provided, the local offline path is used and the
  /// app still functions.
  static const String _dartDefineKeys =
      String.fromEnvironment('GEMINI_API_KEYS', defaultValue: '');

  /// Ordered list of Gemini API keys. The Gemini client rotates through
  /// these on failure so a single revoked/exhausted key never takes the
  /// whole feature down. Add new keys to the front.
  static List<String> get geminiApiKeys {
    // First allow test/runtime override.
    final dynamic dyn = _runtimeKeysAccessor?.call();
    if (dyn != null && dyn is List && dyn.isNotEmpty) {
      final typed = <String>[];
      for (final e in dyn) {
        if (e != null) {
          final s = e.toString();
          if (s.isNotEmpty) typed.add(s);
        }
      }
      if (typed.isNotEmpty) return List<String>.unmodifiable(typed);
    }
    final fromBuild = _dartDefineKeys
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    return fromBuild;
  }

  /// Convenience getter for the primary key (the first in [geminiApiKeys]).
  static String get geminiApiKey {
    final keys = geminiApiKeys;
    return keys.isNotEmpty ? keys.first : '';
  }

  /// Test/dev hook: inject the live key list without touching disk.
  static List<String> Function()? _runtimeKeysAccessor;

  /// Register a runtime provider for Gemini keys (used in tests / dev).
  static void setRuntimeGeminiKeysForTest(List<String>? keys) {
    if (keys == null) {
      _runtimeKeysAccessor = null;
    } else {
      _runtimeKeysAccessor = () => keys;
    }
  }

  /// Gemini model identifier. Per v1.0.26 spec: use `gemini-1.5-flash`
  /// which is the stable GA model for the Google AI Studio REST endpoint
  /// `?key=` API. Earlier `gemini-3.6-flash` / `gemini-3.8-flash` model
  /// identifiers do NOT exist on the Gemini Developer API and the calls
  /// returned 404 / 401. `gemini-1.5-flash` is the safe, documented choice.
  static const String geminiModel = 'gemini-1.5-flash';
  static const bool geminiEnabled = true;
  static const bool newFeaturesEnabled = true;
  static const int defaultGeofenceRadius = 500;

  static const String webRedirectUrl =
      'https://mohamedsabae50-prog.github.io/streetlore-web-app/';

  static const String mobileRedirectUrl =
      'io.supabase.streetlore://login-callback/';
}
