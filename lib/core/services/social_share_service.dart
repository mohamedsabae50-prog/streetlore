import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/itinerary_model.dart';
import '../../data/models/place_photo.dart';
import '../../data/models/place_model.dart';
import '../../presentation/widgets/social_share_card.dart';

class SocialShareService {
  SocialShareService._();

  static const _logoAsset = 'assets/images/compass_only.png';
  static const _imageTimeout = Duration(seconds: 20);
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.alsaba.egyptlore';

  static String buildShareText({
    required String title,
    required String description,
    required String appName,
  }) {
    final cleanTitle = title.trim();
    final cleanDescription = _concise(description);
    return [
      if (cleanTitle.isNotEmpty) cleanTitle,
      if (cleanDescription.isNotEmpty) cleanDescription,
      appName.trim(),
      _playStoreUrl,
    ].where((part) => part.isNotEmpty).join('\n\n');
  }

  static String _concise(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final runes = normalized.runes.toList(growable: false);
    if (runes.length <= 240) return normalized;
    return '${String.fromCharCodes(runes.take(239))}…';
  }

  static Future<void> sharePlace({
    required BuildContext context,
    required PlaceModel place,
    required String locale,
    required String category,
    required String footer,
    GlobalKey? shareButtonKey,
    Rect? sharePositionOrigin,
  }) async {
    final description = place.localizedDescription(locale).trim();
    final imageUrl = place.officialImages.isEmpty
        ? place.imageUrl
        : place.officialImages.first;
    final imageBytes = await _loadOptionalImage(imageUrl);
    if (!context.mounted) return;
    await _shareCard(
      context: context,
      photoBytes: imageBytes,
      title: place.localizedName(locale),
      subtitle: description.isNotEmpty
          ? description
          : place.localizedAddress(locale),
      category: category,
      footer: footer,
      fileName: 'egyptlore-place.png',
      shareButtonKey: shareButtonKey,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> shareCompletedTour({
    required BuildContext context,
    required ItineraryModel tour,
    required String locale,
    required String category,
    required String completedDetails,
    GlobalKey? shareButtonKey,
    Rect? sharePositionOrigin,
  }) async {
    final imageBytes = await _loadOptionalImage(tour.coverImageUrl);
    if (!context.mounted) return;
    await _shareCard(
      context: context,
      photoBytes: imageBytes,
      title: tour.localizedTitle(locale),
      subtitle: tour.localizedDescription(locale).trim(),
      category: category,
      footer: completedDetails,
      fileName: 'egyptlore-tour.png',
      shareButtonKey: shareButtonKey,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> sharePlacePhoto({
    required BuildContext context,
    required PlacePhoto photo,
    required PlaceModel place,
    required String locale,
    required String category,
    required String footer,
    GlobalKey? shareButtonKey,
    Rect? sharePositionOrigin,
  }) async {
    final imageBytes = await _loadImage(photo.imageUrl);
    if (!context.mounted) return;
    final caption = photo.caption.trim();
    await _shareCard(
      context: context,
      photoBytes: imageBytes,
      title: place.localizedName(locale),
      subtitle: caption.isNotEmpty
          ? caption
          : place.localizedDescription(locale).trim().isNotEmpty
          ? place.localizedDescription(locale).trim()
          : place.localizedAddress(locale),
      category: category,
      footer: footer,
      fileName: 'egyptlore-place-photo.png',
      shareButtonKey: shareButtonKey,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> _shareCard({
    required BuildContext context,
    required Uint8List? photoBytes,
    required String title,
    required String subtitle,
    required String category,
    required String footer,
    required String fileName,
    GlobalKey? shareButtonKey,
    Rect? sharePositionOrigin,
  }) async {
    final logo = await rootBundle.load(_logoAsset);
    if (!context.mounted) return;
    final direction = Directionality.of(context);
    final origin =
        sharePositionOrigin ??
        sharePositionOriginFor(context, shareButtonKey: shareButtonKey);
    final controller = ScreenshotController();
    final image = await controller.captureFromWidget(
      SocialShareCard(
        photoBytes: photoBytes,
        logoBytes: logo.buffer.asUint8List(
          logo.offsetInBytes,
          logo.lengthInBytes,
        ),
        category: category,
        title: title,
        subtitle: subtitle,
        footer: footer,
        textDirection: direction,
      ),
      context: context,
      targetSize: const Size(1080, 1350),
      pixelRatio: 1,
      delay: const Duration(milliseconds: 250),
    );
    await SharePlus.instance.share(
      ShareParams(
        text: buildShareText(
          title: title,
          description: subtitle,
          appName: 'EgyptLore',
        ),
        files: [XFile.fromData(image, mimeType: 'image/png', name: fileName)],
        sharePositionOrigin: origin,
      ),
    );
  }

  static Rect sharePositionOriginFor(
    BuildContext context, {
    GlobalKey? shareButtonKey,
  }) {
    final originContext = shareButtonKey?.currentContext ?? context;
    final renderObject = originContext.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    if (box != null &&
        box.attached &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  static Future<Uint8List?> _loadOptionalImage(String? imageUrl) async {
    final value = imageUrl?.trim() ?? '';
    if (value.isEmpty) return null;
    try {
      return await _loadImage(value);
    } catch (error) {
      debugPrint('SocialShareService: optional image unavailable: $error');
      return null;
    }
  }

  static Future<Uint8List> _loadImage(String imageUrl) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      throw const FormatException('The image address is invalid.');
    }
    if (uri.scheme == 'data') {
      final data = UriData.fromUri(uri);
      if (!data.mimeType.startsWith('image/')) {
        throw const FormatException('The shared content is not an image.');
      }
      return data.contentAsBytes();
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const FormatException('This image format cannot be shared.');
    }
    final response = await http.get(uri).timeout(_imageTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'The image could not be downloaded (HTTP ${response.statusCode}).',
      );
    }
    final contentType = response.headers['content-type'];
    if (contentType != null && !contentType.startsWith('image/')) {
      throw const FormatException('The downloaded content is not an image.');
    }
    return response.bodyBytes;
  }
}
