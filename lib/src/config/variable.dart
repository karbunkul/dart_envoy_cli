part of 'config.dart';

@immutable
final class Variable {
  final String name;
  final CastType castTo;
  final CastConstraint? constraint;
  final String? summary;
  final Virtual? virtual;

  const Variable({
    required this.name,
    this.castTo = CastType.string,
    this.constraint,
    this.summary,
    this.virtual,
  });

  bool get hasConstraint => constraint != null;
  bool get isVirtual => virtual != null;

  Object cast(String value) {
    return switch (castTo) {
      CastType.int => int.parse(value),
      CastType.boolean => bool.parse(value),
      CastType.double => double.parse(value),
      CastType.string => value,
    };
  }
}

final class Virtual {
  final String exec;
  final Map<String, dynamic>? overrides;

  Virtual({required this.exec, this.overrides});

  factory Virtual.from(dynamic params) {
    final execField = params['exec'];
    if (execField is String) {
      return Virtual(exec: execField);
    }
    if (execField is Map) {
      final currentPlatform = Platform.operatingSystem;
      // Map 'macos' to 'darwin' for compatibility
      final searchKeys = [currentPlatform];
      if (currentPlatform == 'macos') searchKeys.add('darwin');
      if (currentPlatform == 'darwin') searchKeys.add('macos');

      String? resolvedExec;
      for (final key in searchKeys) {
        if (execField.containsKey(key)) {
          resolvedExec = execField[key] as String?;
          break;
        }
      }

      if (resolvedExec == null) {
        throw ArgumentError(
          'virtual: missing command for current platform ($currentPlatform). '
          'Available: ${execField.keys.join(', ')}',
        );
      }

      return Virtual(
        exec: resolvedExec,
        overrides: Map<String, dynamic>.from(execField),
      );
    }
    throw UnsupportedError('virtual must be string or map');
  }

  String performExec() {
    final parts = exec.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || (parts.length == 1 && parts.first.isEmpty)) {
      throw ArgumentError('Virtual exec command cannot be empty');
    }

    final executable = parts.first;
    final arguments = parts.sublist(1);

    final result = Process.runSync(
      executable,
      arguments,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        result.stderr.toString().trim(),
        result.exitCode,
      );
    }

    return result.stdout.toString().trim();
  }
}
