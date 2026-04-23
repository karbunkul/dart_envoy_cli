import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:envoy/envoy.dart';

Future<void> main(List<String> args) async {
  final logger = Logger();
  final runner = EnvoyRunner(logger: logger);

  final exitCode = await runner.run(args);

  exit(exitCode);
}
