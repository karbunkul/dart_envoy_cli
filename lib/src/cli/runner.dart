import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:envoy/src/cli/commands/commands.dart';

import 'package:envoy/src/cli/commands/executor.dart';

import 'helper.dart';

@immutable
final class EnvoyRunner extends CommandRunner {
  EnvoyRunner()
      : super(
          'envoy',
          'Envoy is a tool for managing environment variables and generating files from templates.',
        );

  void _setup() {
    argParser.addOption(
      CliHelper.output,
      abbr: 'o',
      help: 'Default current directory',
    );

    argParser.addOption(
      CliHelper.config,
      abbr: 'c',
      help: 'Path for config file',
    );

    argParser.addFlag(
      CliHelper.force,
      abbr: 'f',
      help: 'Attempt to call action without prompting',
      defaultsTo: false,
    );

    argParser.addFlag(
      CliHelper.verbose,
      help: 'Output log information',
      abbr: 'd',
      defaultsTo: false,
    );

    argParser.addFlag(
      CliHelper.env,
      help: 'Load env from .env file',
      abbr: 'e',
      defaultsTo: false,
    );

    addCommand(InitCommand());
    addCommand(BuildCommand());
  }

  @override
  Future run(Iterable<String> args) async {
    // setup runner, init args
    _setup();

    final results = parse(args);
    _verbose(verbose: results[CliHelper.verbose]);

    if (results.command?.name == null) {
      final runArguments = results.arguments;

      if (runArguments.contains('--help') || runArguments.contains('-h')) {
        return super.run(args);
      }

      final configFile = CliHelper.configFile(results[CliHelper.config]);

      if (configFile.existsSync()) {
        return BuildExecutor(
          configFile: configFile,
          results: results,
        ).execute();
      }
    }

    return super.run(args);
  }

  void _verbose({bool verbose = false}) {
    Logger.root.level = Level.ALL;

    Logger.root.onRecord.listen((record) {
      if (verbose || record.level == Level.SEVERE) {
        final levelName = switch (record.level) {
          Level.SEVERE => 'ERROR',
          _ => record.level.name,
        };
        Colorize level = Colorize('[${levelName}]');
        level.bold();

        level = switch (record.level) {
          Level.INFO => level.blue(),
          Level.SEVERE => level.red(),
          Level.WARNING => level.yellow(),
          _ => level,
        };

        final time = record.time.toString().substring(0, 19);
        print('$level: $time: ${record.message}');
      }
    });
  }
}
