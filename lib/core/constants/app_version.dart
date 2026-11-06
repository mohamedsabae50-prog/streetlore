/// Single source of truth for the semantic app version displayed in the UI.
///
/// Keep this in sync with the semantic version in `pubspec.yaml`.
///
/// The build number (`+NN`) is for platform release metadata and must not
/// be included in user-facing version labels.
const String kAppVersion = '2.1.42';

/// Platform build number, kept separate from user-facing version labels.
const int kAppBuildNumber = 245;

/// Human-friendly label for the About screen.
String formatAppVersionLabel() => 'Version $kAppVersion';
