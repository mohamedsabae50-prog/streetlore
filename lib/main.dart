import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/services/offline_storage_service.dart';
import 'core/services/revenuecat_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/sync_queue_service.dart';
import 'core/services/realtime_resilience.dart';
import 'core/config/app_config.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/app_strings.dart';
import 'logic/place_provider.dart';
import 'logic/tour_provider.dart';
import 'logic/theme_provider.dart';
import 'logic/auth_provider.dart';
import 'logic/locale_provider.dart';
import 'logic/place_photos_provider.dart';
import 'core/services/widget_sync_service.dart';
import 'core/services/widget_deep_link_service.dart';
import 'logic/blocked_users_provider.dart';
import 'logic/streak_provider.dart';
import 'logic/squad_provider.dart';
import 'logic/journal_provider.dart';
import 'logic/achievement_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/no_internet_screen.dart';
import 'logic/trip_provider.dart';
import 'logic/review_provider.dart';
import 'logic/ai_features_providers.dart';
import 'logic/connectivity_provider.dart';

Future<void> main() async {
  const sentryDsn =
      'https://a53b51a6844eba2f4f122031f2c12f7d@o4512250554810368.ingest.de.sentry.io/4512250574798928';
  await SentryFlutter.init((options) {
    // An empty DSN keeps the app runnable until a project DSN is configured.
    options.dsn = sentryDsn == 'YOUR_SENTRY_DSN_HERE' ? '' : sentryDsn;
    options.enableTombstone = true;
    options.beforeSend = (event, hint) {
      if (isTransientNetworkError(event.toJson().toString())) return null;
      return event;
    };
  }, appRunner: _runApplication);
}

Future<void> _runApplication() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    if (isTransientNetworkError(error)) {
      debugPrint('Ignoring transient unhandled network error: $error');
      return true;
    }
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    return false;
  };
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      Sentry.captureException(details.exception, stackTrace: details.stack),
    );
  };

  // v1.0.80 — surface any unhandled build-time widget error as a
  // visible red panel instead of a silent gray screen in release.
  // The default Flutter behavior in release is to render a flat gray
  // rectangle, which made the locale-switch crash un-debuggable.
  // v1.0.89 — wrap the builder in try/catch. If _ErrorScreen itself
  // throws (e.g. on Flutter Web where certain plugins may misbehave),
  // Flutter would otherwise call this builder again with the new error,
  // producing an infinite "Another exception was thrown: jI<void>" loop
  // and a permanently black screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    try {
      return _ErrorScreen(details: details);
    } catch (_) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF1A0B1F),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'A widget failed to render. Pull to refresh or restart.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }
  };

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );

  await OfflineStorageService.instance.init();
  await SupabaseService.instance.init();
  await SyncQueueService.instance.init();

  final auth = AuthProvider();
  await auth.bootstrap();
  final blockedUsers = BlockedUsersProvider();
  unawaited(
    blockedUsers.setUserId(auth.userId).catchError((Object error, stackTrace) {
      debugPrint('Blocked users startup sync failed: $error\n$stackTrace');
    }),
  );
  unawaited(SyncQueueService.instance.flush());
  await _configureRevenueCat(auth.userId);
  unawaited(_bindAuthDeepLink(auth));

  final placeProvider = PlaceProvider();
  final tourProvider = TourProvider();
  final tripProvider = TripProvider();
  void syncTourVisitStatus() {
    tourProvider.syncVisitedPlaces(
      tripProvider.visitedPlaceIds,
      placeProvider.places,
    );
  }

  tripProvider.addListener(syncTourVisitStatus);
  placeProvider.addListener(syncTourVisitStatus);
  syncTourVisitStatus();
  unawaited(placeProvider.loadPlaces(force: true));
  unawaited(tourProvider.loadTours());

  final gamification = GamificationProvider();
  gamification.syncWithAuth(auth);

  final streak = StreakProvider();
  await streak.setUserId(auth.userId);
  final squad = SquadProvider();
  unawaited(squad.setUserId(auth.userId));
  final achievements = AchievementProvider(
    auth: auth,
    gam: gamification,
    places: placeProvider,
    streak: streak,
    tours: tourProvider,
  );
  // v1.0.56: wire gamification -> streak/achievements so a single
  // gamification.applyAction('check_in', ...) call updates the
  // streak and re-runs the catalog-based achievement re-evaluation
  // automatically (the missing piece that broke badge unlocks).
  gamification.bindHelpers(
    streak: streak,
    achievements: achievements,
    squad: squad,
  );

  Future<void> bootstrapFromSupabase(String userId) async {
    await streak.setUserId(userId);
    await Future.wait([
      placeProvider.bootstrapForUser(userId),
      tourProvider.bootstrapForUser(userId),
      gamification.bootstrapForUser(userId),
      tripProvider.refreshVisited(),
      streak.refreshFromRemote(),
    ]);
    achievements.refreshFromStats();
  }

  void authListener() {
    final id = auth.userId;
    unawaited(SyncQueueService.instance.flush());
    gamification.syncWithAuth(auth);
    achievements.syncWithAuth(auth);
    unawaited(squad.setUserId(id));
    unawaited(
      blockedUsers.setUserId(id).catchError((Object error, stackTrace) {
        debugPrint('Blocked users auth sync failed: $error\n$stackTrace');
      }),
    );
    if (id.isEmpty) {
      _lastBootstrappedUserId = null;
      unawaited(tripProvider.refreshVisited());
      tourProvider.clearCheckedInPlaces();
      unawaited(streak.setUserId(''));
      return;
    }
    if (id == _lastBootstrappedUserId) return;
    _lastBootstrappedUserId = id;
    unawaited(_configureRevenueCat(id));
    unawaited(bootstrapFromSupabase(id));
  }

  auth.addListener(authListener);
  if (auth.userId.isNotEmpty) {
    _lastBootstrappedUserId = auth.userId;
    unawaited(bootstrapFromSupabase(auth.userId));
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
        ChangeNotifierProvider<PlaceProvider>.value(value: placeProvider),
        ChangeNotifierProvider<TourProvider>.value(value: tourProvider),
        ChangeNotifierProvider<GamificationProvider>.value(value: gamification),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => GeofenceProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
        ChangeNotifierProvider(create: (_) => PlacePhotosProvider()),
        ChangeNotifierProvider<BlockedUsersProvider>.value(value: blockedUsers),
        ChangeNotifierProvider<StreakProvider>.value(value: streak),
        ChangeNotifierProvider<SquadProvider>.value(value: squad),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider<AchievementProvider>.value(value: achievements),
      ],
      child: const EgyptLoreApp(),
    ),
  );
}

Future<void> _configureRevenueCat(String userId) async {
  try {
    await RevenueCatService.instance.configure(userId);
  } catch (error, stackTrace) {
    debugPrint('RevenueCat startup configuration failed: $error\n$stackTrace');
  }
}

String? _lastBootstrappedUserId;

Future<void> _bindAuthDeepLink(AuthProvider auth) async {
  try {
    final links = AppLinks();
    final initial = await links.getInitialLink();
    if (initial != null && !WidgetDeepLinkService.handleUri(initial)) {
      await auth.handleAuthCallback(initial);
    }
    links.uriLinkStream.listen((uri) async {
      if (!WidgetDeepLinkService.handleUri(uri)) {
        await auth.handleAuthCallback(uri);
      }
    });
  } catch (e) {
    debugPrint('Deep link bind failed: $e');
  }
}

class EgyptLoreApp extends StatefulWidget {
  const EgyptLoreApp({super.key});

  @override
  State<EgyptLoreApp> createState() => _EgyptLoreAppState();
}

class _EgyptLoreAppState extends State<EgyptLoreApp>
    with WidgetsBindingObserver {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _offlineNoticeShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = 80;
    imageCache.maximumSizeBytes = 60 << 20;
  }

  @override
  void didHaveMemoryPressure() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
    super.didHaveMemoryPressure();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateOfflineNotice(bool shouldShow, String message) {
    if (!shouldShow) {
      _offlineNoticeShown = false;
      return;
    }
    if (_offlineNoticeShown) return;
    _offlineNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LocaleProvider, PlaceProvider>(
      builder: (context, themeProvider, localeProvider, placeProvider, _) {
        // After the first frame of the app build, update the Android widget
        // with the current Place of the Day and cached weather.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            WidgetSyncService.updateWidgetData(context);
            WidgetDeepLinkService.openPendingPlace();
          } catch (_) {}
        });

        return MaterialApp(
          navigatorKey: WidgetDeepLinkService.navigatorKey,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          title: 'EgyptLore',
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          builder: (context, child) {
            return _LocaleScope(
              locale: localeProvider.locale,
              child: Consumer2<AuthProvider, ConnectivityProvider>(
                builder: (context, auth, connectivity, app) {
                  _updateOfflineNotice(
                    auth.isPro && connectivity.hasInternet == false,
                    context.tr('offline_mode_notice'),
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      app ?? const SizedBox.shrink(),
                      if (!auth.isPro && connectivity.hasInternet == false)
                        const NoInternetScreen(),
                    ],
                  );
                },
                child: child,
              ),
            );
          },
          themeMode: themeProvider.themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const SplashScreen(),
        );
      },
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      fontFamily: 'Cairo',
      textTheme: const TextTheme().apply(
        fontFamily: 'Cairo',
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B82F6),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      fontFamily: 'Cairo',
      textTheme: const TextTheme().apply(
        fontFamily: 'Cairo',
        bodyColor: const Color(0xFFF1F5F9),
        displayColor: const Color(0xFFF1F5F9),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF1F5F9),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1C2433),
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1C2433),
      ),
    );
  }
}

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
        key: ValueKey<String>('locale_${locale.languageCode}'),
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
                      Icon(
                        Icons.bug_report_rounded,
                        color: Color(0xFFEF4444),
                        size: 32,
                      ),
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
                        color: const Color(0xFFEF4444),
                        width: 1,
                      ),
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
