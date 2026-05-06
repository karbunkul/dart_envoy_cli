import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dotenv/dotenv.dart';
import 'package:json_schema/json_schema.dart';
import 'package:interact/interact.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:envoy/src/cli/helper.dart';

import '../../config/config.dart';

@immutable
class EnvoyExecutor {
  final File configFile;
  final ArgResults results;
  final Logger logger;

  const EnvoyExecutor({
    required this.configFile,
    required this.results,
    required this.logger,
  });

  String get configDir => configFile.parent.path;

  Future<Map<String, dynamic>> resolveVariables() async {
    final config = CliHelper.loadConfig(configFile.path);
    if (config == null) {
      throw Exception('Could not load configuration from ${configFile.path}');
    }
    final env = _initEnv();
    return _variables(env, config);
  }

  Future<void> execute({bool skipBuild = false}) async {
    final progress = logger.progress('Reading configuration');

    try {
      final config = CliHelper.loadConfig(configFile.path);
      if (config == null) {
        progress.fail('Could not load configuration from ${configFile.path}');
        return;
      }

      logger.detail('Config version: ${config.version}');
      logger.detail('Loaded ${config.variables.length} variables');
      logger.detail('Loaded ${config.templates.length} templates');

      final env = _initEnv();
      final force =
          results.wasParsed(CliHelper.force) ? results[CliHelper.force] : false;

      progress.update('Resolving variables');
      final context = await _variables(env, config);
      progress.complete('Configuration loaded');

      if (!skipBuild) {
        final outputDir = CliHelper.outputDir(
            results.wasParsed(CliHelper.output)
                ? results[CliHelper.output]
                : null);

        for (final template in config.templates) {
          final outputFile =
              File(p.normalize(p.join(outputDir, template.output)));

          if (outputFile.existsSync() && !force) {
            final rewrite = Confirm(
              prompt: 'File ${outputFile.path} already exists. Overwrite?',
              defaultValue: true,
            ).interact();

            if (!rewrite) {
              logger.info('Skipped ${outputFile.path}');
              continue;
            }
          }

          final templateProgress =
              logger.progress('Processing ${template.output}');

          try {
            final rendered = template.performTemplate(
              vars: Map.unmodifiable(context),
              workDir: configDir,
            );

            outputFile
              ..createSync(recursive: true)
              ..writeAsStringSync(rendered);

            templateProgress.complete('Generated ${outputFile.path}');
          } catch (e) {
            templateProgress.fail('Failed to process ${template.output}: $e');
          }
        }
      }

      // Handle --exec flag
      if (results.wasParsed('exec') &&
          (results['exec'] == true ||
              (results['exec'] is String &&
                  (results['exec'] as String).isNotEmpty))) {
        final commandToExec = results['exec'] is String
            ? results['exec'] as String
            : config.executable;

        if (commandToExec != null && commandToExec.isNotEmpty) {
          await _runCommand(commandToExec, context);
        } else {
          logger.err(
              'No executable defined in config and no command provided to --exec');
        }
      }
    } catch (e) {
      progress.fail('Action failed: $e');
      rethrow;
    }
  }

  Future<void> _runCommand(
      String commandLine, Map<String, dynamic> context) async {
    logger.info('Executing: $commandLine');

    final parts = commandLine.split(' ');
    final executable = parts.first;
    final arguments = parts.skip(1).toList();

    // Prepare environment variables for the child process
    final envVars = Map<String, String>.from(Platform.environment);
    context.forEach((key, value) {
      envVars[key.toUpperCase()] = value.toString();
    });

    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.inheritStdio,
      environment: envVars,
      runInShell: true,
    );

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      exit(exitCode);
    }
  }

  DotEnv _initEnv() {
    final env = DotEnv(includePlatformEnvironment: true);

    if (results.wasParsed(CliHelper.env) && results[CliHelper.env]) {
      final envFile = File(
        p.normalize(
          p.join(configDir, '.env'),
        ),
      ).absolute;

      if (envFile.existsSync()) {
        logger.detail('Loading environments from ${envFile.path}');
        env.load([envFile.path]);
      } else {
        logger.warn('.env file not found at ${envFile.path}');
      }
    }

    return env;
  }

  Future<Map<String, dynamic>> _variables(DotEnv env, Config config) async {
    final result = <String, dynamic>{};

    for (final variable in config.variables) {
      final key = variable.name.toLowerCase();
      final name = key.toUpperCase();

      final String raw;
      if (variable.isVirtual) {
        raw = variable.virtual!.performExec();
      } else {
        raw = env.getOrElse(name, () {
          throw ArgumentError('Missing value for $name in environment');
        });
      }

      final castedValue = variable.cast(raw);

      if (variable.hasConstraint) {
        final schema = <String, dynamic>{}..addAll(variable.constraint!.rules);
        final validated = JsonSchema.create(schema).validate(castedValue);

        if (!validated.isValid) {
          final reason = validated.errors.first.message;
          throw ArgumentError('Failed constraint for $name: $reason');
        }
      }

      result[key] = castedValue;
    }

    return result;
  }
}
