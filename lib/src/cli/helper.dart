import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/config.dart';

class CliHelper {
  static const String output = 'output';
  static const String config = 'config';
  static const String verbose = 'verbose';
  static const String force = 'force';
  static const String env = 'env';

  static String outputDir(String? dir) {
    if (dir == null) {
      return p.current;
    }

    var path = p.normalize(dir);
    if (!p.isAbsolute(path)) {
      path = p.absolute(p.current, path);
    }

    if (Directory(path).existsSync()) {
      return p.normalize(Directory(path).absolute.path);
    }
    throw Exception('invalid dir');
  }

  static Config? loadConfig(String? path) {
    final file = configFile(path);

    if (!file.existsSync()) {
      return null;
    }

    final yaml = loadYaml(file.readAsStringSync());
    final json = jsonDecode(jsonEncode(yaml));

    return Config.import(json);
  }

  static File configFile(String? file) {
    if (file != null) {
      if (!file.endsWith('yaml')) {
        throw ArgumentError('Config file must be yaml file');
      }

      return File(p.normalize(p.absolute(file))).absolute;
    }

    return File(
      p.normalize(p.absolute('envoy.yaml')),
    ).absolute;
  }
}
