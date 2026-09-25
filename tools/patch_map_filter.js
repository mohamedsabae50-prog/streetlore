const fs = require('fs');
const file = 'D:/codes/streetlore/lib/presentation/screens/map_view_screen.dart';
let s = fs.readFileSync(file, 'utf8');
const old = [
  "  List<PlaceModel> _filtered(List<PlaceModel> all) {",
  "    if (_allOff && !_showAtms && !_showHotels) return const <PlaceModel>[];",
  "    if (_allOff) return all; // Hotels/ATMs are ON, show all main places too",
  "    if (_selectedCategory == null) return all;",
  "    return all.where((p) => p.category == _selectedCategory).toList();",
  "  }"
].join('\r\n');
const nw = [
  "  List<PlaceModel> _filtered(List<PlaceModel> all) {",
  "    // v1.0.31: exclusive extra-layer modes first so the map shows",
  "    // ONLY the chosen layer's markers (no stale main places).",
  "    if (_showAtms) return const <PlaceModel>[];",
  "    if (_showHotels) {",
  "      return all.where((p) => p.category == 'Hotels').toList();",
  "    }",
  "    if (_allOff) return const <PlaceModel>[];",
  "    if (_selectedCategory == null) return all;",
  "    return all.where((p) => p.category == _selectedCategory).toList();",
  "  }"
].join('\r\n');
const idx = s.indexOf(old);
if (idx === -1) {
  console.error('NOT FOUND');
  process.exit(1);
}
s = s.substring(0, idx) + nw + s.substring(idx + old.length);
fs.writeFileSync(file, s, 'utf8');
console.log('OK');
