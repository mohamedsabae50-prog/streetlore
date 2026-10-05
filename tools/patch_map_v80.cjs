const fs = require('fs');

const file = 'D:/codes/streetlore/lib/presentation/screens/map_screen.dart';
let src = fs.readFileSync(file, 'utf-8');

function replaceRegex(src, pattern, flags, label, content) {
  const re = new RegExp(pattern, flags);
  if (!re.test(src)) {
    console.error('pattern not found:', label);
    process.exit(1);
  }
  return src.replace(re, content);
}

// 1) Replace transparent-PNG bytes block with magenta debug block.
//    Pattern matches from the doc-comment through the `]);` plus newline.
const transparentRe = /\/\/\/ v1\.0\.78 — 1×1 fully-transparent PNG bytes[\s\S]*?\]\);\n/;
const magentaBlock = `/// v1.0.80 — VISIBLE error tile (semi-opaque magenta). A failed
/// tile now shows as a small magenta square instead of invisibly
/// vanishing. The bytes below are a hand-built minimal 1×1 PNG
/// (8-bit RGBA, magenta, deflate via zlib).
final Uint8List _kDebugErrorPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0x99, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x9F, 0x01, 0x00, 0x07, 0x82, 0x02, 0x7E, 0xA6,
  0xDC, 0xD2, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
`;
src = src.replace(transparentRe, magentaBlock);

// 2) Replace the tile URL list. The OLD block spans multiple lines.
src = replaceRegex(
  src,
  /const\s+list<string>\s*_tileUrls\s*=\s*\[[\s\S]*?\]\;[\s\S]*?const\s+list<string>\s*_tileSubdomains\s*=\s*\[[\s\S]*?\]\;/i,
  'gi',
  'tile-list',
  `// v1.0.80 — CartoDB Voyager primary (no rate-limit, works in Egypt),
// OSM + ESRI as 2-tier fallbacks. NOTE: the empty subdomain '' that
// v1.0.78 used to "support" ESRI (which has no {s} placeholder) broke
// CartoDB and OSM — their {s}.basemaps.cartocdn.com fallback URLs got
// rewritten to "https://.basemaps.cartocdn.com/..." which is an invalid
// host. With no valid fallback, when ESRI was blocked we fell back to
// a fully-broken URL set and the user saw a solid gray map. We now
// keep subdomains = ['a','b','c'] (CartoDB + OSM only) and rely on
// the tile ordering to pick ESRI when neither CartoDB nor OSM
// responds.
const List<String> _tileUrls = [
  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
];
const List<String> _tileSubdomains = ['a', 'b', 'c'];`
);

// 3) Replace errorTileCallback + errorImage pair.
src = replaceRegex(
  src,
  /errorTileCallback:\s*\(tile, error, stackTrace\)\s*\{[\s\S]*?errorImage:\s*MemoryImage\(_kTransparentPng\),/,
  'gi',
  'tile-error',
  `errorTileCallback: (tile, error, stackTrace) {
                      final msg = 'tile failed: $error';
                      debugPrint('MapScreen ' + msg);
                      if (mounted && _firstTileError == null) {
                        _firstTileError = msg;
                        setState(() {});
                      }
                    },
                    // v1.0.80 — visible magenta 1x1 PNG so a fully-broken
                    // map reads as a magenta checkerboard instead of
                    // an invisible gray. (Previously: a transparent PNG
                    // silently hid every tile failure.)
                    errorImage: MemoryImage(_kDebugErrorPng),`
);

// 4) Add `_firstTileError` state field next to `_errorMessage`.
src = replaceRegex(
  src,
  /String _errorMessage\s*=\s*'';/,
  'g',
  'state-field',
  `String _firstTileError = '';
  String _errorMessage = '';`
);

// 5) Insert the visible error banner overlay just before the attribution.
src = replaceRegex(
  src,
  /\/\/ Map data attribution/,
  'g',
  'banner-anchor',
  `// v1.0.80 — visible error banner so a half-elsewhere gray map is
                    // immediately debuggable. Shows the first tile-failure
                    // message. Dismissable.
                    if (_firstTileError.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Material(
                          color: const Color(0xCC7F1D1D),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Map tiles failed: \$_firstTileError',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 18),
                                  onPressed: () => setState(() {
                                    _firstTileError = '';
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Map data attribution`
);

// 6) Also add `Material` import (needed for the banner widget).
if (!src.includes("import 'package:flutter/material.dart'") &&
    !src.match(/^import 'package:flutter\/material\.dart';\s*$/m)) {
  console.error('Material import missing!');
  process.exit(1);
}

fs.writeFileSync(file, src, 'utf-8');
console.log('Patched map_screen.dart');