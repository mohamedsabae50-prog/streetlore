const fs = require('fs');
const path = 'D:/codes/streetlore/lib/presentation/screens/login_screen.dart';
const lines = fs.readFileSync(path, 'utf8').split(/\r?\n/);
// _GradientButton class is at lines 362-431 (1-indexed).
// Keep lines 1..361, drop 362..431, keep 432..end.
const head = lines.slice(0, 361);
const tail = lines.slice(431);
console.error('head', head.length, 'tail', tail.length);
fs.writeFileSync(path, head.concat(tail).join('\n'), 'utf8');
console.log('done');
