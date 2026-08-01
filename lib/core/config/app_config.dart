class AppConfig {
  AppConfig._();
  static const String supabaseUrl =
      'https://tbivoxyxclwjjspwsgvc.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiaXZveHl4Y2x3ampzcHdzZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMjA3NjMsImV4cCI6MjA5OTg5Njc2M30.uM9F6_O-ObiiVkF8hjQmsFovf3h4gTaode719u6bAnI';
  static const bool supabaseEnabled = true;
  static const String geminiApiKey =
      'AQ.Ab8RN6Jfsh4TWPHBZBuBdSJjbDs63KJXfNVvzqvYm2_OyAcZpA';
  static const String geminiModel = 'gemini-2.0-flash';
  static const bool geminiEnabled = true;
  static const bool newFeaturesEnabled = true;
  static const int defaultGeofenceRadius = 500;

  /// Web OAuth redirect URL. Set this to the production origin (e.g.
  /// `https://mohamedsabae50-prog.github.io/streetlore-web-app/`) so
  /// Google sign-in doesn't bounce back to `http://localhost:8080`.
  /// Leave as `null` to fall back to the current page origin (recommended
  /// for development on localhost).
  static const String? webRedirectUrl = null;

  /// Native OAuth redirect URL (deep link for Android/iOS).
  static const String mobileRedirectUrl = 'io.supabase.streetlore://login-callback/';
}
