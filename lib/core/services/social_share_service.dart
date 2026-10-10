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

  static const _logoAsset = 'assets/logo/streetlore_logo.png';
  static const _imageTimeout = Duration(seconds: 20);

  static Future<void> shareCompletedTour({
    required BuildContext context,
    required ItineraryModel tour,
    required String locale,
    required String category,
    required String completedDetails,
  }) async {
    final imageBytes = await _loadOptionalImage(tour.coverImageUrl);
    if (!context.mounted) return;
    await _shareCard(
      context: context,
      photoBytes: imageBytes,
      title: tour.localizedTitle(locale),
      subtitle: tour.localizedDescription(locale),
      category: category,
      footer: completedDetails,
      fileName: 'streetlore-tour.png',
    );
  }

  static Future<void> sharePlacePhoto({
    required BuildContext context,
    required PlacePhoto photo,
    required PlaceModel place,
    required String locale,
    required String category,
    required String footer,
  }) async {
    final imageBytes = await _loadImage(photo.imageUrl);
    if (!context.mounted) return;
    final caption = photo.caption.trim();
    await _shareCard(
      context: context,
      photoBytes: imageBytes,
      title: place.localizedName(locale),
      subtitle: caption.isNotEmpty ? caption : place.address,
      category: category,
      footer: footer,
      fileName: 'streetlore-place-photo.png',
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
  }) async {
    final logo = await rootBundle.load(_logoAsset);
    if (!context.mounted) return;
    final direction = Directionality.of(context);
    final renderObject = context.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
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
        files: [XFile.fromData(image, mimeType: 'image/png', name: fileName)],
        sharePositionOrigin: origin,
      ),
    );
  }

  static Future<Uint8List?> _loadOptionalImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    return _loadImage(imageUrl);
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
