import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dotenv/dotenv.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:envoy/src/cli/helper.dart';

import '../base_command.dart';

class VariableCommand extends Command with BaseCommand {
  @override
  String get description => 'Manage and inspect variables';

  @override
  List<String> get aliases => ['var'];

  @override
  String get name => 'variable';

  @override
  String get invocation => 'envoy variable <subcommand>';

  VariableCommand() {
    addSubcommand(ListVariablesCommand());
  }
}

class ListVariablesCommand extends Command with BaseCommand {
  @override
  String get description => 'List all variables and their resolved values';

  @override
  String get name => 'list';

  @override
  Future<void> run() async {
    final file = configFile();
    if (!file.existsSync()) {
      logger.err('Config file not found at ${file.path}');
      return;
    }

    final progress = logger.progress('Loading configuration');

    try {
      final config = CliHelper.loadConfig(file.path);
      if (config == null) {
        progress.fail('Failed to load config');
        return;
      }

      final isVerbose = logger.level == Level.verbose;

      if (isVerbose) {
        logger.detail('Config file: ${file.path}');
        logger.detail('Total variables defined: ${config.variables.length}');
      }

      progress.update('Resolving variables...');

      final env = DotEnv(includePlatformEnvironment: true);
      final useEnv = globalResults![CliHelper.env] as bool;

      if (useEnv) {
        final envFile = File(p.normalize(p.join(file.parent.path, '.env')));
        if (envFile.existsSync()) {
          env.load([envFile.path]);
        }
      }

      progress.complete('Variables inspection:');
      logger.info(
        darkGray.wrap(
            '  (Note: Showing resolved values without constraint validation)'),
      );
      logger.info('');

      for (final variable in config.variables) {
        final name = variable.name.toUpperCase();
        final type = variable.castTo.name;
        final summary = variable.summary ?? 'No description';

        String constraintStr = 'None';
        if (variable.hasConstraint) {
          final c = variable.constraint!;
          if (c.name == 'inline') {
            constraintStr = 'inline rules: ${c.rules}';
          } else {
            constraintStr = '${cyan.wrap(c.name)} (rules: ${c.rules})';
          }
        }

        String resolvedValue;
        String? error;

        try {
          if (variable.isVirtual) {
            resolvedValue = variable.virtual!.performExec();
          } else {
            resolvedValue = env.getOrElse(name, () => 'NOT SET');
          }

          if (resolvedValue != 'NOT SET') {
            variable.cast(resolvedValue); // Проверка на валидность типа
          }
        } catch (e) {
          resolvedValue = 'ERROR';
          error = e.toString();
        }

        // Вывод информации о переменной
        logger.info('${lightCyan.wrap(name)} ${darkGray.wrap('($type)')}');
        logger.info('  ${white.wrap('Description:')} $summary');
        logger.info('  ${white.wrap('Constraint:')} $constraintStr');

        final valueColor = resolvedValue == 'NOT SET'
            ? darkGray
            : (resolvedValue == 'ERROR' ? lightRed : lightGreen);

        logger.info(
            '  ${white.wrap('Resolved Value:')} ${valueColor.wrap(resolvedValue)}');

        if (error != null) {
          logger.info('  ${lightRed.wrap('Error details:')} $error');
        }

        if (variable.isVirtual) {
          final v = variable.virtual!;
          logger.info('  ${darkGray.wrap('Source:')} virtual (${v.exec})');
          if (v.overrides != null && v.overrides!.length > 1) {
            logger.info('  ${darkGray.wrap('Platform overrides:')}');
            for (final entry in v.overrides!.entries) {
              final platform = entry.key;
              final command = entry.value;

              // Проверяем, является ли эта платформа текущей
              final isCurrent = platform == Platform.operatingSystem ||
                  (platform == 'macos' && Platform.isMacOS) ||
                  (platform == 'darwin' && Platform.isMacOS);

              final platformLabel =
                  isCurrent ? lightGreen.wrap(platform) : platform;
              logger.info('    ${darkGray.wrap('-')} $platformLabel: $command');
            }
          }
        } else {
          logger.info(
              '  ${darkGray.wrap('Source:')} ${useEnv ? '.env / system' : 'system environment only'}');
        }

        logger.info('');
      }
    } catch (e) {
      progress.fail('Error: $e');
    }
  }
}
