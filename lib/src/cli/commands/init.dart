import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../base_command.dart';

class InitCommand extends Command with BaseCommand {
  @override
  String get description => 'Init new project';

  @override
  String get name => 'init';

  @override
  Future<void> run() async {
    final file = configFile();

    if (file.existsSync() && !force) {
      final rewrite = logger.confirm(
        'Config file already exists (${file.path}). Overwrite?',
        defaultValue: false,
      );

      if (!rewrite) {
        logger.info('Aborted.');
        return;
      }
    }

    final progress = logger.progress('Creating config file');
    try {
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(_config);
      progress.complete('Created config file: ${file.path}');
    } catch (e) {
      progress.fail('Failed to create config file: $e');
    }
  }
}

const _config = '''
# Envoy Configuration File
# For more information, see: https://github.com/karbunkul/envoy

version: 1.0

# Define constraints for your variables
constraints:
  - name: port_range
    rules:
      minimum: 1024
      maximum: 65535

# List of variables to be loaded from environment or virtual sources
variables:
  - name: APP_NAME
    castTo: string
  - name: PORT
    castTo: int
    constraint: port_range
  - name: DEBUG
    castTo: boolean
    virtual:
      exec: "echo true"

# Templates to be processed
templates:
  - template: templates/config.g.dart.mustache
    output: lib/config.g.dart
''';
