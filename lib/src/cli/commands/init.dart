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
  FutureOr run() async {
    final file = configFile();

    if (file.existsSync() && !force) {
      final rewrite = logger.confirm(
        'Rewrite current config?',
        defaultValue: true,
      );

      if (!rewrite) {
        return exit(1);
      }
    }

    file.writeAsStringSync(_config);
    logger.success('Save config in ${file.path}');
  }
}

const _config = '''
---
version: 1

variables:
  - name: FOO
''';
