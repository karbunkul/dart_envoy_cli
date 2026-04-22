import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:envoy/envoy.dart';

void main(List<String> args) {
  runZonedGuarded(() => SmartEnvRunner().run(args), (error, stack) {
    Logger('envoy')..severe(error, stack);

    print(stack);

    exit(1);
  });
}
