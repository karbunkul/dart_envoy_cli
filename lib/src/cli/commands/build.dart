import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:envoy/src/cli/commands/run.dart';

import '../base_command.dart';

class BuildCommand extends Command with BaseCommand {
  @override
  String get description => 'Build templates from config';

  @override
  String get name => 'build';

  @override
  FutureOr run() async {
    final file = configFile();

    if (!file.existsSync()) {
      throw Exception('Config file ${file.path} not found');
    }

    return RunCommand(
      configFile: file,
      results: globalResults!,
    ).run();
  }
}
