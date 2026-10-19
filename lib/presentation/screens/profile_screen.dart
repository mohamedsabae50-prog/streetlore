import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/animations/app_animations.dart';
import '../../core/constants/app_version.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/geofencing_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_icons.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../logic/place_provider.dart';
import '../../logic/geofence_provider.dart';
import '../../logic/tour_provider.dart';
import '../../logic/theme_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/gamification_provider.dart';
import 'package:flutter/scheduler.dart';
import '../../logic/achievement_provider.dart';
import '../../logic/locale_provider.dart';
import '../../logic/streak_provider.dart';
import '../../l10n/app_strings.dart';
import 'login_screen.dart';
import 'emergency_screen.dart';
import 'currency_converter_screen.dart';
import 'journal_screen.dart';
import 'prayer_times_screen.dart';
import 'achievements_screen.dart';
import 'admin_panel_screen.dart';
import 'legal_document_screen.dart';
import 'paywall_screen.dart';
import 'suggest_place_screen.dart';
import 'search_users_screen.dart';
import '../widgets/social_user_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final _privacyPolicyUri = Uri.parse(
    'https://mohamedsabae50-prog.github.io/streetlore/privacy.html',
  );
  static final _deleteAccountUri = Uri.parse(
    'https://mohamedsabae50-prog.github.io/streetlore/delete-account.html',
  );

  final ConfettiController _confetti = ConfettiController();
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _shareLocationActivity = true;
  bool _privacyLoaded = false;
  bool _privacyLoading = false;
  bool _isUploadingAvatar = false;
  String? _privacyError;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadTogglePrefs();
    _refreshOnNextFrame();
  }

  void _refreshOnNextFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.userId.isNotEmpty) {
        context.read<PlaceProvider>().fetchRemoteCounts(auth.userId);
      }
      _maybeCelebrateStreakBadge();
    });
  }

  Future<void> _loadTogglePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _locationEnabled = prefs.getBool('location_enabled') ?? true;
      });
    }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.isGuest) return;
    try {
      final enabled = await SupabaseService.instance
          .fetchLocationActivitySharing();
      if (mounted) {
        setState(() {
          _shareLocationActivity = enabled;
          _privacyLoaded = true;
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'ProfileScreen: failed to load location privacy: $error\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _privacyError = 'privacy_settings_failed';
          _privacyLoaded = false;
        });
      }
    }
  }

  Future<void> _setLocationActivitySharing(bool enabled) async {
    if (_privacyLoading) return;
    setState(() {
      _privacyLoading = true;
      _privacyError = null;
    });
    try {
      await SupabaseService.instance.setLocationActivitySharing(enabled);
      if (mounted) setState(() => _shareLocationActivity = enabled);
    } catch (error, stackTrace) {
      debugPrint(
        'ProfileScreen: failed to save location privacy: $error\n$stackTrace',
      );
      if (mounted) {
        setState(() => _privacyError = 'privacy_settings_save_failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('privacy_settings_save_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _privacyLoading = false);
    }
  }

  Future<void> _pickAvatar(
    BuildContext context,
    AuthProvider auth, {
    ImageSource source = ImageSource.gallery,
  }) async {
    SupabaseClient? avatarClient;
    String? uploadedAvatarPath;
    try {
      final selectedImage = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (selectedImage == null || !context.mounted) return;
      setState(() => _isUploadingAvatar = true);
      final compressed = await selectedImage.readAsBytes();
      final client = SupabaseService.instance.clientOrNull;
      final userId = client?.auth.currentUser?.id;
      if (client == null || userId == null || userId != auth.userId) {
        throw StateError('Sign in to upload a profile picture.');
      }
      avatarClient = client;
      final objectPath =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await client.storage
          .from('avatars')
          .uploadBinary(
            objectPath,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      uploadedAvatarPath = objectPath;
      await auth.updateAvatarUrl(
        client.storage.from('avatars').getPublicUrl(objectPath),
      );
    } catch (error, stackTrace) {
      debugPrint('ProfileScreen: avatar upload failed: $error\n$stackTrace');
      if (avatarClient != null && uploadedAvatarPath != null) {
        try {
          await avatarClient.storage.from('avatars').remove([
            uploadedAvatarPath,
          ]);
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint(
            'ProfileScreen: failed to clean up uploaded avatar: '
            '$cleanupError\n$cleanupStackTrace',
          );
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('avatar_upload_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _selectBuiltInAvatar(AuthProvider auth, String avatar) async {
    try {
      await auth.updateAvatarUrl(avatar);
    } catch (error, stackTrace) {
      debugPrint(
        'ProfileScreen: built-in avatar update failed: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('avatar_upload_failed'))),
        );
      }
    }
  }

  Future<void> _showAvatarChoices(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('avatar_choose_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: Text(context.tr('take_photo')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(context.tr('choose_gallery')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              const Divider(),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                children: [
                  for (final preset in ExplorerAvatar.presetUrls)
                    IconButton(
                      tooltip: context.tr(
                        'avatar_preset_${preset.split(':').last}',
                      ),
                      onPressed: () => Navigator.pop(sheetContext, preset),
                      icon: ExplorerAvatar(
                        avatarUrl: preset,
                        displayName: auth.userName,
                        radius: 24,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice is ImageSource) {
      await _pickAvatar(context, auth, source: choice);
    } else if (choice is String) {
      await _selectBuiltInAvatar(auth, choice);
    }
  }

  Future<void> _openPublicPage(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('No browser could open $uri.');
    } catch (error, stackTrace) {
      debugPrint(
        'ProfileScreen: could not open public page: $error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('public_link_failed'))));
    }
  }

  Future<void> _setSmartAlerts(
    BuildContext context,
    GeofenceProvider geo,
    bool enabled,
  ) async {
    if (!enabled) {
      await geo.disableSmartAlerts();
      return;
    }
    final consent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('geo_background_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('smart_alerts_consent')),
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LegalDocumentScreen(
                    document: LegalDocument.privacy,
                  ),
                ),
              ),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: Text(context.tr('geo_read_privacy_policy')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('geo_enable')),
          ),
        ],
      ),
    );
    if (consent != true || !context.mounted) return;

    final result = await geo.enableSmartAlerts(
      context.read<PlaceProvider>().places,
    );
    if (result != GeofencingStartResult.started && context.mounted) {
      final key = switch (result) {
        GeofencingStartResult.noPlacesSelected => 'smart_alerts_no_gems',
        GeofencingStartResult.unsupported => 'geo_unsupported',
        GeofencingStartResult.locationServicesDisabled =>
          'checkin_location_disabled',
        GeofencingStartResult.locationPermissionDenied =>
          'checkin_location_permission',
        GeofencingStartResult.backgroundPermissionDenied =>
          'geo_background_denied',
        GeofencingStartResult.notificationPermissionDenied =>
          'geo_notifications_denied',
        GeofencingStartResult.notificationsUnavailable ||
        GeofencingStartResult.locationUnavailable => 'geo_start_failed',
        GeofencingStartResult.started => 'geo_monitoring_on',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(key))));
    }
  }

  Future<void> _editName(BuildContext context, AuthProvider auth) async {
    final ctrl = TextEditingController(text: auth.userName);
    final formKey = GlobalKey<FormState>();
    String? newName;
    try {
      newName = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: Theme.of(ctx).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              context.tr('edit_name_dialog_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: context.tr('login_full_name'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.tr('login_err_name');
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(ctrl.text);
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  context.tr('cancel'),
                  style: TextStyle(color: context.textSec),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(ctrl.text);
                  }
                },
                child: Text(
                  context.tr('sign_in_continue'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      ctrl.dispose();
    }
    if (newName == null || newName.trim().isEmpty) return;
    if (!mounted) return;
    await auth.updateGuestName(newName);
    if (!context.mounted) return;
    final gam = context.read<GamificationProvider>();
    gam.syncWithAuth(auth);
    HapticFeedback.lightImpact();
  }

  Future<void> _maybeCelebrateStreakBadge() async {
    final g = context.read<GamificationProvider>();
    final streakBadges = g.stats.badges.where(
      (b) => b.id.startsWith('b_streak_'),
    );
    if (streakBadges.isEmpty) return;
    final highest = streakBadges
        .map((b) => int.tryParse(b.id.replaceFirst('b_streak_', '')) ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    final prefs = await SharedPreferences.getInstance();
    const key = 'profile_celebrated_streak_badge';
    final celebrated = prefs.getInt(key) ?? 0;
    if (highest > celebrated) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _confetti.play();
      await prefs.setInt(key, highest);
    }
  }

  Widget _proProfileCard(
    BuildContext context, {
    required bool isPro,
    required String? subscriptionTier,
  }) {
    final tierLabel = switch (subscriptionTier?.toLowerCase()) {
      'weekly' => context.tr('pro_tier_weekly'),
      'monthly' => context.tr('pro_tier_monthly'),
      'annual' => context.tr('pro_tier_annual'),
      'lifetime' => context.tr('pro_tier_lifetime'),
      _ => null,
    };
    final title = isPro
        ? [
            context.tr('pro_member'),
            if (tierLabel != null) tierLabel,
          ].join(' - ')
        : context.tr('pro_title');
    final card = Ink(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ratingGold.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(isPro ? 'pro_member_subtitle' : 'pro_subtitle'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isPro)
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              color: Colors.white,
            ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: isPro
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                );
              },
              child: card,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeP = context.watch<ThemeProvider>();
    final placeP = context.watch<PlaceProvider>();
    final tourP = context.watch<TourProvider>();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 32,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: auth.isLoggedIn && !auth.isGuest
                                ? () => _pickAvatar(context, auth)
                                : null,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 3,
                                ),
                              ),
                              child: ExplorerAvatar(
                                avatarUrl: auth.avatarUrl,
                                displayName: auth.userName,
                                radius: 45,
                                fallbackColor: Colors.white,
                              ),
                            ),
                          ),
                          if (auth.isLoggedIn && !auth.isGuest)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _showAvatarChoices(context, auth),
                                child: const CircleAvatar(
                                  radius: 13,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          if (_isUploadingAvatar)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.48),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (auth.isLoggedIn && !auth.isGuest)
                        TextButton.icon(
                          onPressed: _isUploadingAvatar
                              ? null
                              : () => _showAvatarChoices(context, auth),
                          icon: const Icon(
                            Icons.face_retouching_natural_rounded,
                          ),
                          label: Text(context.tr('avatar_choose_title')),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              auth.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _editName(context, auth),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: AnimatedLottieIcon(
                          animation: LottieAnimations.trophy,
                          size: 40,
                          color: AppColors.warning,
                          secondaryColor: AppColors.goldLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.userEmail,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stat(
                              label: context.tr('prof_saved'),
                              numericValue:
                                  placeP.savedPlaces.length >
                                      placeP.remoteSavedCount
                                  ? placeP.savedPlaces.length
                                  : placeP.remoteSavedCount,
                              icon: Icons.bookmark_rounded,
                              delayMs: 200,
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),

                            _Stat(
                              label: context.tr('prof_explored'),
                              numericValue: tourP.checkedInPlaceIds.length,
                              icon: Icons.explore_rounded,
                              delayMs: 320,
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            _Stat(
                              label: context.tr('prof_tours'),
                              numericValue: tourP.visitedTourIds.length,
                              icon: Icons.map_rounded,
                              delayMs: 440,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _proProfileCard(
                    context,
                    isPro: auth.isPro,
                    subscriptionTier: auth.subscriptionTier,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Consumer<StreakProvider>(
                    builder: (context, streak, _) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFB923C), Color(0xFFEF4444)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    streak.currentStreak == 0
                                        ? context.tr('streak_start')
                                        : context.tr('streak_days', {
                                            'n': '${streak.currentStreak}',
                                            's': streak.currentStreak == 1
                                                ? ''
                                                : 's',
                                          }),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    streak.longestStreak > 0
                                        ? context.tr('streak_best', {
                                            'b': '${streak.longestStreak}',
                                            't': '${streak.totalVisitDays}',
                                            's': streak.totalVisitDays == 1
                                                ? ''
                                                : 's',
                                          })
                                        : context.tr('streak_begin'),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Consumer<GamificationProvider>(
                    builder: (context, g, _) {
                      final badgesById = {
                        for (final badge in g.stats.badges) badge.id: badge,
                      };
                      final badges = badgesById.values.toList(growable: false);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('badges_title'),
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: context.textPri,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (badges.isEmpty)
                            Text(
                              context.tr('no_badges'),
                              style: TextStyle(
                                color: context.textSec,
                                fontSize: 13,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < badges.length; i++)
                                  FadeInUp(
                                    delay: Duration(milliseconds: 60 * i),
                                    offsetY: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.25,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.workspace_premium_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.tr(badges[i].name),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Consumer<AchievementProvider>(
                    builder: (context, ach, _) {
                      final recent = ach.recentUnlocked(limit: 3);
                      final ratio = ach.completionRatio;
                      // v1.0.56 fix: variables are explicitly
                      // unlocked_count / total_count. The displayed
                      // format is "{unlocked_count} / {total_count}".
                      final unlockedCount = ach.totalUnlocked;
                      final totalCount = ach.totalAvailable;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AchievementsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFB347), Color(0xFFFF7E5F)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFF7E5F,
                                ).withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Achievements',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        Text(
                                          '$unlockedCount / $totalCount unlocked',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 8,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (recent.isEmpty)
                                Text(
                                  'Start your collection',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    for (final def in recent) ...[
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.22,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          def.icon,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        'View all',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('passion_banner_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('passion_banner_sub'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    context.tr('section_app_settings'),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textPri,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _Card(
                      children: [
                        _ToggleTile(
                          icon: Icons.dark_mode_rounded,
                          title: context.tr('dark_mode'),
                          subtitle: themeP.isDark
                              ? context.tr('dark_theme_on')
                              : context.tr('light_theme_on'),
                          color: const Color(0xFF6366F1),
                          value: themeP.isDark,
                          onChanged: (_) {
                            HapticFeedback.lightImpact();
                            context.read<ThemeProvider>().toggleTheme();
                          },
                        ),
                        _Div(),
                        _ToggleTile(
                          icon: Icons.notifications_rounded,
                          title: context.tr('push_notif'),
                          subtitle: context.tr('push_notif_sub'),
                          color: AppColors.accent,
                          value: _notificationsEnabled,
                          onChanged: (v) async {
                            HapticFeedback.lightImpact();
                            setState(() => _notificationsEnabled = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('notifications_enabled', v);
                          },
                        ),
                        _Div(),
                        _ToggleTile(
                          icon: Icons.location_on_rounded,
                          title: context.tr('location_services'),
                          subtitle: context.tr('location_services_sub'),
                          color: AppColors.success,
                          value: _locationEnabled,
                          onChanged: (v) async {
                            HapticFeedback.lightImpact();
                            setState(() => _locationEnabled = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('location_enabled', v);
                          },
                        ),
                        if (auth.isLoggedIn && !auth.isGuest) ...[
                          _Div(),
                          if (_privacyLoaded)
                            _ToggleTile(
                              icon: Icons.shield_outlined,
                              title: context.tr('share_location_activity'),
                              subtitle: context.tr(
                                'share_location_activity_subtitle',
                              ),
                              color: AppColors.success,
                              value: _shareLocationActivity,
                              onChanged: _setLocationActivitySharing,
                            ),
                          if (_privacyError != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                16,
                                0,
                                16,
                                8,
                              ),
                              child: Text(
                                context.tr(_privacyError!),
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                        _Div(),
                        Consumer<GeofenceProvider>(
                          builder: (context, geo, _) => _ToggleTile(
                            icon: Icons.radar_rounded,
                            title: context.tr('smart_alerts_title'),
                            subtitle: context.tr('smart_alerts_subtitle'),
                            color: const Color(0xFF0EA5E9),
                            value: geo.smartAlertsEnabled,
                            onChanged: (enabled) async {
                              HapticFeedback.lightImpact();
                              await geo.ready;
                              if (!context.mounted) return;
                              await _setSmartAlerts(context, geo, enabled);
                            },
                          ),
                        ),
                        _Div(),
                        Consumer<LocaleProvider>(
                          builder: (context, lp, _) {
                            return _ToggleTile(
                              icon: Icons.translate_rounded,
                              title: context.tr('language'),
                              subtitle: lp.isArabic ? 'العربية' : 'English',
                              color: const Color(0xFF0EA5E9),
                              value: lp.isArabic,
                              onChanged: (_) async {
                                HapticFeedback.lightImpact();
                                await lp.toggle();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    context.tr('section_about'),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textPri,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: FadeInUp(
                  delay: const Duration(milliseconds: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _Card(
                      children: [
                        _ActionTile(
                          icon: Icons.health_and_safety_rounded,
                          title: context.tr('emergency_info'),
                          subtitle: context.tr('emergency_info_sub'),
                          color: const Color(0xFFEF4444),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EmergencyScreen(),
                              ),
                            );
                          },
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.mosque_rounded,
                          title: context.tr('prayer_times'),
                          subtitle: context.tr('prayer_times_sub'),
                          color: const Color(0xFF14B8A6),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrayerTimesScreen(),
                              ),
                            );
                          },
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.people_alt_rounded,
                          title: context.tr('users_search_title'),
                          subtitle: context.tr('users_search_subtitle'),
                          color: const Color(0xFF6366F1),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const SearchUsersScreen(),
                              ),
                            );
                          },
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.add_location_alt_rounded,
                          title: context.tr('suggest_hidden_gem'),
                          subtitle: context.tr('suggest_hidden_gem_subtitle'),
                          color: const Color(0xFF10B981),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SuggestPlaceScreen(),
                              ),
                            );
                          },
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.attach_money_rounded,
                          title: context.tr('currency_converter'),
                          subtitle: context.tr('currency_converter_sub'),
                          color: const Color(0xFF14B8A6),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CurrencyConverterScreen(),
                              ),
                            );
                          },
                        ),
                        _Div(),

                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (!auth.isAdmin) return const SizedBox.shrink();
                            return _ActionTile(
                              icon: Icons.admin_panel_settings_rounded,
                              title: context.tr('admin_title'),
                              subtitle:
                                  '${context.tr('admin_field_category')}: '
                                  'ATM / Hotel / Cafe / ...',
                              color: const Color(0xFFEF4444),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminPanelScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.menu_book_rounded,
                          title: context.tr('travel_journal'),
                          subtitle: context.tr('travel_journal_sub'),
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const JournalScreen(),
                              ),
                            );
                          },
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.help_outline_rounded,
                          title: context.tr('help_center'),
                          subtitle: context.tr('help_center_sub'),
                          color: const Color(0xFF0EA5E9),
                          onTap: () => _showHelp(context),
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.star_outline_rounded,
                          title: context.tr('rate_app'),
                          subtitle: context.tr('rate_app_sub'),
                          color: AppColors.ratingGold,
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('rate_thanks')),
                                ),
                              ),
                        ),
                        _Div(),
                        _ActionTile(
                          icon: Icons.info_outline_rounded,
                          title: context.tr('about_app'),
                          subtitle: formatAppVersionLabel(),
                          color: context.textSec,
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'EgyptLore',
                            applicationVersion: kAppVersion,
                            applicationIcon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.explore_rounded,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    onPressed: () => _showSignOutDialog(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('sign_out'),
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    context.tr('profile_legal_title'),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textPri,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Card(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.description_outlined,
                          color: AppColors.accent,
                        ),
                        title: Text(context.tr('terms_of_service_title')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const LegalDocumentScreen(
                                document: LegalDocument.terms,
                              ),
                            ),
                          );
                        },
                      ),
                      _Div(),
                      ListTile(
                        leading: const Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.error,
                        ),
                        title: Text(context.tr('delete_account_public')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openPublicPage(_deleteAccountUri),
                      ),
                      _Div(),
                      ListTile(
                        leading: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Color(0xFF0EA5E9),
                        ),
                        title: Text(context.tr('privacy_policy_title')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openPublicPage(_privacyPolicyUri),
                      ),
                      _Div(),
                      ListTile(
                        enabled: !_deletingAccount,
                        leading: _deletingAccount
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.error,
                                ),
                              )
                            : const Icon(
                                Icons.delete_forever_outlined,
                                color: AppColors.error,
                              ),
                        title: Text(
                          context.tr('delete_account_title'),
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: _deletingAccount
                            ? null
                            : () => _confirmDeleteAccount(context),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // v1.0.71 — map / photo attributions, required by the
              // OSM and Wikimedia Commons licenses.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.bgAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: context.textSec,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('attributions_title'),
                              style: TextStyle(
                                color: context.textPri,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('attribution_osm'),
                          style: TextStyle(
                            color: context.textSec,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('attribution_wikimedia'),
                          style: TextStyle(
                            color: context.textSec,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned.fill(child: ConfettiOverlay(controller: _confetti)),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardColor,
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
          size: 36,
        ),
        title: Text(
          context.tr('delete_account_title'),
          style: TextStyle(color: context.textPri, fontWeight: FontWeight.w800),
        ),
        content: Text(
          context.tr('delete_account_warning'),
          style: TextStyle(color: context.textSec, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('delete_account_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await SupabaseService.instance.deleteAccount();
      if (!context.mounted) return;
      await context.read<AuthProvider>().signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error, stackTrace) {
      debugPrint('ProfileScreen: account deletion failed: $error\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('delete_account_failed'))),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text(
          context.tr('sign_out_q'),
          style: TextStyle(color: context.textPri, fontWeight: FontWeight.w800),
        ),
        content: Text(
          context.tr('sign_out_sub'),
          style: TextStyle(color: context.textSec, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(color: context.textSec),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, a, __) => const LoginScreen(),
                  transitionDuration: const Duration(milliseconds: 500),
                  transitionsBuilder: (_, a, __, child) =>
                      FadeTransition(opacity: a, child: child),
                ),
                (route) => false,
              );
            },
            child: Text(
              context.tr('sign_out'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text(
          context.tr('help_center'),
          style: TextStyle(color: context.textPri, fontWeight: FontWeight.w800),
        ),
        content: Text(
          context.tr('help_contact'),
          style: TextStyle(color: context.textSec, fontSize: 14, height: 1.6),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('got_it'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int? numericValue;
  final IconData icon;
  final int delayMs;
  const _Stat({
    required this.label,
    required this.icon,
    this.numericValue,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: Duration(milliseconds: delayMs),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            (numericValue ?? 0).toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.textPri,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: context.textSec),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.textPri,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: context.textSec),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.hintColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 16,
      color: context.dividerColor,
    );
  }
}
