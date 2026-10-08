import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/services/supabase_service.dart';
import '../data/models/place_photo.dart';

class PlacePhotosProvider extends ChangeNotifier {
  static const _kKey = 'place_photos_v1';
  static const _uuid = Uuid();

  final Map<String, List<PlacePhoto>> _byPlace = {};
  String _currentUserId = 'me';

  String get currentUserId => _currentUserId;

  void setUserId(String id) {
    if (_currentUserId == id) return;
    _currentUserId = id;
    notifyListeners();
  }

  List<PlacePhoto> photosFor(String placeId) =>
      List.unmodifiable(_byPlace[placeId] ?? const []);

  int totalFor(String placeId) => _byPlace[placeId]?.length ?? 0;

  PlacePhotosProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _byPlace.clear();
      for (final item in list) {
        final photo = PlacePhoto.fromMap(item as Map<String, dynamic>);
        _byPlace.putIfAbsent(photo.placeId, () => []).add(photo);
      }
      for (final entry in _byPlace.entries) {
        entry.value.sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (e) {
      debugPrint('PlacePhotosProvider load error: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final all = _byPlace.values.expand((e) => e).map((p) => p.toMap()).toList();
    await prefs.setString(_kKey, jsonEncode(all));
  }

  Future<PlacePhoto> addPhoto({
    required String placeId,
    required String userName,
    required Uint8List imageBytes,
    String? userId,
    String caption = '',
  }) async {
    final effectiveUserId = (userId ?? _currentUserId).trim();
    final photoId = _uuid.v4();
    final svc = SupabaseService.instance;
    var imageUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    String? storagePath;

    if (effectiveUserId.isNotEmpty && svc.clientOrNull != null) {
      final client = svc.clientOrNull!;
      storagePath = 'user-photos/$placeId/$photoId.jpg';
      await client.storage.from('place-images').uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      imageUrl = client.storage.from('place-images').getPublicUrl(storagePath);
    }

    final photo = PlacePhoto(
      id: photoId,
      placeId: placeId,
      userId: effectiveUserId,
      userName: userName,
      imageUrl: imageUrl,
      caption: caption,
      date: DateTime.now(),
    );
    if (effectiveUserId.isNotEmpty && svc.clientOrNull != null) {
      try {
        await svc.clientOrNull!.from('place_photos').insert(
          photo.toSupabaseInsert(),
        );
      } catch (e) {
        if (storagePath != null) {
          try {
            await svc.clientOrNull!.storage
                .from('place-images')
                .remove([storagePath]);
          } catch (cleanupError) {
            debugPrint(
              'PlacePhotosProvider.addPhoto: failed to clean up uploaded '
              'object $storagePath: $cleanupError',
            );
          }
        }
        rethrow;
      }
    } else {
      debugPrint(
        'PlacePhotosProvider.addPhoto: Supabase unavailable or no user id; '
        'photo $photoId is saved to this device only',
      );
    }

    _byPlace.putIfAbsent(placeId, () => []).insert(0, photo);
    await _save();
    notifyListeners();
    return photo;
  }

  Future<void> toggleLike(String placeId, String photoId) async {
    final list = _byPlace[placeId];
    if (list == null) return;
    final i = list.indexWhere((p) => p.id == photoId);
    if (i == -1) return;
    final photo = list[i];
    final liked = photo.isLikedBy(_currentUserId);
    final newLikedBy = Set<String>.from(photo.likedBy);
    int newLikes = photo.likes;
    if (liked) {
      newLikedBy.remove(_currentUserId);
      newLikes = (newLikes - 1).clamp(0, 1 << 30);
    } else {
      newLikedBy.add(_currentUserId);
      newLikes = newLikes + 1;
    }
    list[i] = photo.copyWith(likes: newLikes, likedBy: newLikedBy);
    await _save();
    notifyListeners();
  }

  Future<void> removePhoto(String placeId, String photoId) async {
    final list = _byPlace[placeId];
    if (list == null) return;
    list.removeWhere((p) => p.id == photoId);
    await _save();
    notifyListeners();
  }
}
