import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'offline_storage_service.dart';

class OfflineTileProvider extends NetworkTileProvider {
  OfflineTileProvider()
    : super(
        headers: Map<String, String>.from({
          'User-Agent':
              'StreetloreApp/2.1 (https://github.com/mohamedsabae50-prog/streetlore)',
        }),
      );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final cachedFile = OfflineStorageService.instance.getTileFile(
      coordinates.z,
      coordinates.x,
      coordinates.y,
    );
    if (!kIsWeb && cachedFile != null && cachedFile.existsSync()) {
      return FileImage(cachedFile);
    }
    return super.getImage(coordinates, options);
  }
}
