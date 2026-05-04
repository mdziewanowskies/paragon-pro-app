// Design lint: enforce a single SF Symbols-equivalent icon family.
//
// We use Material Icons _rounded (and the occasional _outlined when a
// rounded variant doesn't exist, or the bespoke `Icons.apple` /
// `Icons.g_mobiledata_rounded`). This script fails CI when someone
// adds a stock weight icon (e.g. `Icons.add` instead of
// `Icons.add_rounded`).
//
// Run: `dart tool/check_icons.dart`. Exit code 1 = violations.

import 'dart:io';

const _allowedSuffixes = ['_rounded', '_outlined', '_sharp'];

// Names that don't have a _rounded counterpart in the Material set.
const _exemptions = <String>{
  'Icons.apple',
  'Icons.g_mobiledata_rounded',
};

final _iconRegex = RegExp(r'Icons\.([a-z][a-z0-9_]*)');

void main() {
  final root = Directory('lib');
  if (!root.existsSync()) {
    stderr.writeln('Run from the repo root: ./lib not found.');
    exit(2);
  }

  final violations = <String>[];

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    var line = 1;
    for (final raw in content.split('\n')) {
      for (final m in _iconRegex.allMatches(raw)) {
        final fullName = 'Icons.${m.group(1)}';
        if (_exemptions.contains(fullName)) continue;
        final ok = _allowedSuffixes.any((s) => fullName.endsWith(s));
        if (!ok) {
          violations.add('${entity.path}:$line  $fullName');
        }
      }
      line++;
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('✓ Icons audit: every Material icon uses _rounded / '
        '_outlined / _sharp.');
    exit(0);
  }

  stderr.writeln('✗ Inconsistent icon weights:');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  stderr.writeln('\nPick the matching _rounded variant or add an entry to '
      'tool/check_icons.dart _exemptions if no rounded variant exists.');
  exit(1);
}
