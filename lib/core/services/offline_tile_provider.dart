import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'offline_storage_service.dart';

class OfflineTileProvider extends TileProvider {
  OfflineTileProvider() : super(headers: {'User-Agent': _userAgent});

  static const _userAgent =
      'EgyptLoreApp/2.1 (https://github.com/mohamedsabae50-prog/streetlore)';

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _OfflineTileImageProvider(coordinates);
}

class _OfflineTileImageProvider
    extends ImageProvider<_OfflineTileImageProvider> {
  const _OfflineTileImageProvider(this.coordinates);

  static const _userAgent =
      'EgyptLoreApp/2.1 (https://github.com/mohamedsabae50-prog/streetlore)';

  final TileCoordinates coordinates;

  @override
  bool operator ==(Object other) =>
      other is _OfflineTileImageProvider &&
      other.coordinates.z == coordinates.z &&
      other.coordinates.x == coordinates.x &&
      other.coordinates.y == coordinates.y;

  @override
  int get hashCode => Object.hash(coordinates.z, coordinates.x, coordinates.y);

  @override
  Future<_OfflineTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture<_OfflineTileImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _OfflineTileImageProvider key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(key.coordinates, decode),
    scale: 1,
    debugLabel:
        'offline tile ${key.coordinates.z}/${key.coordinates.x}/${key.coordinates.y}',
    informationCollector: () => <DiagnosticsNode>[
      ErrorDescription('Tile coordinates: ${key.coordinates}'),
    ],
  );

  Future<ui.Codec> _load(
    TileCoordinates tile,
    ImageDecoderCallback decode,
  ) async {
    final cache = OfflineStorageService.instance;
    if (!kIsWeb && cache.getTileFile(tile.z, tile.x, tile.y) == null) {
      await cache.init();
    }
    var file = cache.getTileFile(tile.z, tile.x, tile.y);
    file ??= kIsWeb ? null : await _getTileFile(tile.z, tile.x, tile.y);
    Uint8List? bytes;

    final legacy = cache.getLegacyTileFile(tile.z, tile.x, tile.y);
    bytes = file == null ? null : await _readUsableTile(file);
    bytes ??= legacy == null ? null : await _readUsableTile(legacy);

    if (bytes == null && await _hasNetwork()) {
      bytes = await _downloadTile(tile.z, tile.x, tile.y, file);
    }

    bytes ??= await _findParentTile(tile);
    bytes ??= _transparentPng;

    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'OfflineTileProvider: image decode failed: $error\n$stackTrace',
      );
      final fallback = await ui.ImmutableBuffer.fromUint8List(_transparentPng);
      return decode(fallback);
    }
  }

  Future<Uint8List?> _findParentTile(TileCoordinates tile) async {
    for (var zoom = tile.z - 1; zoom >= 0; zoom--) {
      final scale = 1 << (tile.z - zoom);
      final parentX = tile.x ~/ scale;
      final parentY = tile.y ~/ scale;
      final cache = OfflineStorageService.instance;
      final parent = cache.getTileFile(zoom, parentX, parentY);
      if (parent != null) {
        final bytes = await _readUsableTile(parent);
        if (bytes != null) return bytes;
        final legacy = cache.getLegacyTileFile(zoom, parentX, parentY);
        if (legacy != null) {
          final legacyBytes = await _readUsableTile(legacy);
          if (legacyBytes != null) return legacyBytes;
        }
      }
    }
    return null;
  }

  Future<bool> _hasNetwork() async {
    if (kIsWeb) return true;
    try {
      final connections = await Connectivity().checkConnectivity();
      return !connections.contains(ConnectivityResult.none);
    } on Exception catch (error) {
      debugPrint('OfflineTileProvider: connectivity check failed: $error');
      return true;
    }
  }

  Future<Uint8List?> _readUsableTile(File file) async {
    try {
      if (!await file.exists() || await file.length() <= 100) return null;
      final bytes = await file.readAsBytes();
      return _isPng(bytes) ? bytes : null;
    } on FileSystemException catch (error) {
      debugPrint('OfflineTileProvider: cannot read ${file.path}: $error');
      return null;
    }
  }

  Future<File> _getTileFile(int zoom, int x, int y) async {
    final directory = await getApplicationDocumentsDirectory();
    final tileDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}offline_map_tiles_v3',
    );
    await tileDirectory.create(recursive: true);
    return File(
      '${tileDirectory.path}${Platform.pathSeparator}${zoom}_${x}_$y.png',
    );
  }

  Future<Uint8List?> _downloadTile(int zoom, int x, int y, File? file) async {
    final client = http.Client();
    try {
      for (final template in const [
        'https://a.tile.openstreetmap.fr/hot',
        'https://tile.openstreetmap.org',
      ]) {
        try {
          final response = await client
              .get(
                Uri.parse('$template/$zoom/$x/$y.png'),
                headers: const {'User-Agent': _userAgent},
              )
              .timeout(const Duration(seconds: 4));
          if (response.statusCode != 200 ||
              response.bodyBytes.length <= 100 ||
              !_isPng(response.bodyBytes)) {
            throw HttpException(
              'Tile server returned ${response.statusCode} '
              'for $zoom/$x/$y',
            );
          }
          if (file != null) {
            try {
              await file.parent.create(recursive: true);
              await file.writeAsBytes(response.bodyBytes, flush: true);
            } on FileSystemException catch (error) {
              debugPrint(
                'OfflineTileProvider: could not cache $zoom/$x/$y: $error',
              );
            }
          }
          return response.bodyBytes;
        } on Exception catch (error) {
          debugPrint(
            'OfflineTileProvider: $template tile $zoom/$x/$y failed: $error',
          );
        }
      }
      return null;
    } finally {
      client.close();
    }
  }

  bool _isPng(Uint8List bytes) =>
      bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;

  static final Uint8List _transparentPng = Uint8List.fromList([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1f,
    0x15,
    0xc4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0b,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9c,
    0x63,
    0x60,
    0x00,
    0x02,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0xa5,
    0xf6,
    0x45,
    0x40,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4e,
    0x44,
    0xae,
    0x42,
    0x60,
    0x82,
  ]);
}
