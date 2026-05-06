import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:envoy/src/cli/commands/executor.dart';
import 'package:envoy/src/cli/helper.dart';

import '../base_command.dart';

class ValidateCommand extends Command with BaseCommand {
  @override
  String get description => 'Validate environment variables against config';

  @override
  String get name => 'validate';

  ValidateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output validation results to a JSON file',
    );
    argParser.addFlag(
      'exec',
      abbr: 'x',
      help: 'Execute a command after validation. Uses "exec" from config.',
      negatable: false,
    );
  }

  @override
  FutureOr run() async {
    final file = configFile();

    if (!file.existsSync()) {
      throw Exception('Config file ${file.path} not found');
    }

    final executor = EnvoyExecutor(
      configFile: file,
      results: globalResults!,
      logger: logger,
    );

    if (argResults?['exec'] == true) {
      await executor.execute(skipBuild: true);
    } else {
      final resolved = await executor.resolveVariables();
      final config = CliHelper.loadConfig(file.path);

      final result = <String, dynamic>{};
      for (final variable in config!.variables) {
        final key = variable.name.toUpperCase();
        if (variable.isVirtual) {
          result[key] = resolved[variable.name.toLowerCase()];
        } else {
          result[key] = variable.castTo.name;
        }
      }

      final output = jsonEncode(result);

      if (argResults?['output'] != null) {
        final outputFile = File(argResults!['output']);
        outputFile.writeAsStringSync(output);
      } else {
        stdout.writeln(output);
      }
    }
  }
}
