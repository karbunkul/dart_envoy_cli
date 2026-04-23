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
class BuildExecutor {
  final File configFile;
  final ArgResults results;
  final Logger logger;

  const BuildExecutor({
    required this.configFile,
    required this.results,
    required this.logger,
  });

  String get configDir => configFile.parent.path;

  Future<void> execute() async {
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
      final force = results[CliHelper.force];

      progress.update('Resolving variables');
      final context = await _variables(env, config);
      progress.complete('Configuration loaded');

      final outputDir = CliHelper.outputDir(results[CliHelper.output]);

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
    } catch (e) {
      progress.fail('Build failed: $e');
      rethrow;
    }
  }

  DotEnv _initEnv() {
    final env = DotEnv(includePlatformEnvironment: true);

    if (results[CliHelper.env]) {
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
