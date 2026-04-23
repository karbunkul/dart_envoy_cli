import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:interact/interact.dart';

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
      final rewrite = Confirm(
        prompt: 'Config file already exists (${file.path}). Overwrite?',
        defaultValue: true,
      ).interact();

      if (!rewrite) {
        logger.info('Aborted.');
        return;
      }
    }

    final projectName = Input(
      prompt: 'Enter your project name',
      defaultValue: 'Envoy Project',
    ).interact();

    final createConfirmed = Confirm(
      prompt: 'Create config file at ${file.path}?',
      defaultValue: true,
    ).interact();

    if (!createConfirmed) {
      logger.info('Aborted.');
      return;
    }

    final progress = logger.progress('Creating config file');
    try {
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(_generateConfig(projectName));
      progress.complete('Created config file: ${file.path}');
    } catch (e) {
      progress.fail('Failed to create config file: $e');
    }
  }

  String _generateConfig(String projectName) => '''
# $projectName Configuration File
# For more information, see: https://github.com/karbunkul/dart_envoy_cli

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
}
