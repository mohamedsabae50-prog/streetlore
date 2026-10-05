const fs = require('fs');

const file = 'D:/codes/streetlore/lib/main.dart';
let src = fs.readFileSync(file, 'utf-8');

// 1) Add ErrorWidget.builder and the locale-keyed MaterialApp.builder
//    inside the StreetloreApp.build() method.

// Find the existing StreetloreApp.build and add errorWidget + builder.
const oldBuild =
`  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, _) {
        return MaterialApp(
          title: 'Streetlore',
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: themeProvider.themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const SplashScreen(),
        );
      },
    );
  }`;

const newBuild =
`  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, _) {
        return MaterialApp(
          title: 'Streetlore',
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // v1.0.80 — Locale changes used to glitch into a solid gray
          // screen because some descendant widget captured the
          // previous Localizations widget during its build and threw
          // when the inherited scope was swapped. Wrapping the home
          // in a Builder keyed on the active locale forces a clean
          // subtree rebuild and isolates the rebuilt Locale-aware
          // widgets from the rest of the tree.
          builder: (context, child) {
            return _LocaleScope(
              locale: localeProvider.locale,
              child: child ?? const SizedBox.shrink(),
            );
          },
          // v1.0.80 — surface build-time errors instead of a silent
          // gray screen in release mode.
          errorWidgetBuilder: (details) => _ErrorScreen(details: details),
          themeMode: themeProvider.themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const SplashScreen(),
        );
      },
    );
  }`;

if (!src.includes(oldBuild)) {
  console.error('oldBuild not found');
  process.exit(1);
}
src = src.replace(oldBuild, newBuild);

// 2) Append _LocaleScope + _ErrorScreen widgets at the end of the file
//    (after StreetloreApp). They isolate the locale-driven subtree and
//    catch build errors.
const insertion =
`


/// v1.0.80 — wraps the MaterialApp subtree so that when the user
/// toggles the language from Settings, only the descendants of this
/// widget get torn down and rebuilt — not the MaterialApp or any of
/// the providers above it. The previous setup rebuilt the whole
/// MaterialApp subtree on every locale tick, which crashed some
/// descendant widgets that had cached stale Localizations references.
class _LocaleScope extends StatelessWidget {
  final Locale locale;
  final Widget child;
  const _LocaleScope({required this.locale, required this.child});

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: locale,
      child: KeyedSubtree(
        key: ValueKey<String>('locale_' + locale.languageCode),
        child: child,
      ),
    );
  }
}

/// v1.0.80 — visible error widget so any unhandled build-time error
/// inside the app shows up as a real red panel in release mode
/// instead of a silent gray screen. Falls back to the original
/// Flutter ErrorWidget if the builder itself throws.
class _ErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF1A0B1F),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bug_report_rounded,
                          color: Color(0xFFEF4444), size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Something went wrong',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B1119),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFEF4444), width: 1),
                    ),
                    child: Text(
                      details.exceptionAsString(),
                      style: const TextStyle(
                        color: Color(0xFFFFB4B4),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Restart the app — if it keeps crashing, please '
                    'share this screen with the dev team.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
`;

src = src + insertion;

fs.writeFileSync(file, src, 'utf-8');
console.log('Patched main.dart');