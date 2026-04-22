import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';

import '../config/config.dart';
import 'helper.dart';

mixin BaseCommand on Command {
  Config? loadConfig() {
    final path = globalResults?[CliHelper.config];
    final config = CliHelper.loadConfig(path);

    return config;
  }

  File configFile() {
    final path = globalResults?[CliHelper.config];
    return CliHelper.configFile(path);
  }

  bool get force {
    if (globalResults?.wasParsed(CliHelper.force) == true) {
      return globalResults![CliHelper.force];
    }

    return false;
  }

  Logger get logger => Logger('envoy');
}
