// One-off script: drop the now-unused _InputField and _GradientButton
// classes from login_screen.dart. flutter_lints complains about unused
// private members inside these classes.
const fs = require('fs');
const path = 'D:/codes/streetlore/lib/presentation/screens/login_screen.dart';
const lines = fs.readFileSync(path, 'utf8').split(/\r?\n/);
// Line numbering is 1-indexed in our reads.
// _InputField is at lines 361-459 (1-indexed). Keep 1..360, drop 361..459,
// and keep everything from 460 onwards.
const keep1 = lines.slice(0, 360); // 0..359 → lines 1..360
const dropRange = lines.slice(360, 459); // lines 361..459
const keep2 = lines.slice(459); // line 460+
console.error('keeping', keep1.length, 'dropping', dropRange.length, 'keeping tail', keep2.length);
fs.writeFileSync(path, keep1.concat(keep2).join('\n'), 'utf8');
console.log('done');
