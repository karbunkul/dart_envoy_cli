import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:envoy/src/cli/commands/commands.dart';

import 'package:envoy/src/cli/commands/executor.dart';

import 'helper.dart';

@immutable
final class EnvoyRunner extends CommandRunner {
  final Logger logger;

  EnvoyRunner({Logger? logger})
      : logger = logger ?? Logger(),
        super(
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
      abbr: 'v',
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
  Future<int> run(Iterable<String> args) async {
    try {
      _setup();
      final results = parse(args);

      if (results[CliHelper.verbose] == true) {
        logger.level = Level.verbose;
      }

      if (results.command?.name == null) {
        final runArguments = results.arguments;

        if (runArguments.contains('--help') || runArguments.contains('-h')) {
          printUsage();
          return ExitCode.success.code;
        }

        final configFile = CliHelper.configFile(results[CliHelper.config]);

        if (configFile.existsSync()) {
          await BuildExecutor(
            configFile: configFile,
            results: results,
            logger: logger,
          ).execute();
          return ExitCode.success.code;
        }
      }

      final result = await super.run(args);
      return result ?? ExitCode.success.code;
    } on UsageException catch (e) {
      logger.err(e.message);
      logger.info(e.usage);
      return ExitCode.usage.code;
    } catch (e, st) {
      logger.err(e.toString());
      if (logger.level == Level.verbose) {
        logger.detail(st.toString());
      }
      return ExitCode.software.code;
    }
  }
}
