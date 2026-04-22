import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dotenv/dotenv.dart';
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:prompts/prompts.dart' as prompts;
import 'package:envoy/src/cli/helper.dart';

import '../../config/config.dart';

@immutable
class RunCommand {
  final File configFile;
  final ArgResults results;
  static Logger _logger = Logger('envoy');

  const RunCommand({required this.configFile, required this.results});

  String get configDir => configFile.parent.path;

  FutureOr run() async {
    final config = CliHelper.loadConfig(configFile.path)!;
    final env = _initEnv();
    final force = results[CliHelper.force];

    final context = await _variables(env, config);

    final outputDir = CliHelper.outputDir(results[CliHelper.output]);

    for (final template in config.templates) {
      final rendered = template.performTemplate(
        vars: Map.unmodifiable(context),
        workDir: configDir,
      );

      final outputFile = File(p.normalize(p.join(outputDir, template.output)));

      if (outputFile.existsSync() && !force) {
        final rewrite = prompts.getBool(
          'Rewrite current file (${outputFile.path})?',
          defaultsTo: false,
          chevron: true,
        );

        if (!rewrite) {
          return exit(1);
        }
      }

      outputFile
        ..createSync(recursive: true)
        ..writeAsStringSync(rendered);
      _logger.info('Save file in ${outputFile.path}');
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
        _logger.info('Load environments from ${envFile.path}');
        env.load([envFile.path]);
      }
    }

    return env;
  }

  Future<Map<String, dynamic>> _variables(DotEnv env, Config config) async {
    final result = <String, dynamic>{};

    for (final variable in config.variables) {
      final key = variable.name.toLowerCase();
      final name = key.toUpperCase();

      result.putIfAbsent(key, () {
        late final raw;
        if (variable.isVirtual) {
          raw = variable.virtual!.performExec();
        } else {
          raw = env.getOrElse(key.toUpperCase(), () {
            throw ArgumentError('Missing value for $name in config');
          });
        }

        final castedValue = variable.cast(raw);

        if (variable.hasConstraint) {
          var schema = <String, dynamic>{};
          schema.addAll(variable.constraint!.rules);

          final validated = JsonSchema.create(schema).validate(castedValue);

          if (!validated.isValid) {
            final reason = validated.errors.first.message;

            throw ArgumentError('failed constraint, reason $reason', name);
          }

          return castedValue;
        }
        return castedValue;
      });
    }

    // for (final virtualVar in config.virtual ?? <VirtualVariable>[]) {
    //   if (virtualVar.exec != null) {
    //     final exec = virtualVar.exec!.split(' ');
    //
    //     final process = Process.runSync(
    //       exec.first,
    //       exec..removeAt(0),
    //       runInShell: true,
    //     );
    //
    //     result.putIfAbsent(
    //       virtualVar.name.toLowerCase(),
    //       () => process.stdout.toString().trim(),
    //     );
    //   }
    // }

    return result;
  }
}
