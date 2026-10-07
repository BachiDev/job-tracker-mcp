// Scripted evals: fixed inputs → expected tool-call sequences, no live LLM.
// Validates each fixture in evals/fixtures/*.json against the real toolDefs:
// tools exist, gated tools are confirm-gated, arg keys exist in the schema,
// and forbidden tools stay absent. Exit nonzero on any failure.
//
// Usage: dart run tool/evals.dart [--dir ../../evals/fixtures]
import 'dart:convert';
import 'dart:io';

import 'package:job_tracker_core/job_tracker_core.dart';

Future<void> main(List<String> args) async {
  var dir = '../../evals/fixtures';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--dir' && i + 1 < args.length) dir = args[++i];
  }

  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var failures = 0;
  for (final file in files) {
    final errors = _checkFixture(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    final name = file.uri.pathSegments.last;
    if (errors.isEmpty) {
      stdout.writeln('PASS $name');
    } else {
      failures++;
      stdout.writeln('FAIL $name');
      for (final e in errors) {
        stdout.writeln('  - $e');
      }
    }
  }
  if (files.isEmpty) {
    stdout.writeln('FAIL: no fixtures found');
    exit(1);
  }
  if (failures > 0) exit(1);
  stdout.writeln('OK: ${files.length} fixtures');
}

List<String> _checkFixture(Map<String, dynamic> f) {
  final errors = <String>[];
  for (final name in (f['expect_tools'] as List? ?? [])) {
    final def = findTool('$name');
    if (def == null) {
      errors.add('expected tool missing: $name');
      continue;
    }
    final wantArgs =
        ((f['args'] as Map?)?[name] as Map?)?.keys.map((k) => '$k') ?? [];
    final props =
        (def.inputSchema['properties'] as Map).keys.map((k) => '$k').toSet();
    for (final arg in wantArgs) {
      if (!props.contains(arg)) errors.add('$name: unknown arg $arg');
    }
  }
  for (final name in (f['expect_gated'] as List? ?? [])) {
    final def = findTool('$name');
    if (def == null) {
      errors.add('gated tool missing: $name');
    } else if (!def.requiresConfirmation) {
      errors.add('$name: write is not confirm-gated');
    }
  }
  for (final name in (f['expect_missing'] as List? ?? [])) {
    if (findTool('$name') != null) {
      errors.add('forbidden tool exists: $name');
    }
  }
  return errors;
}
