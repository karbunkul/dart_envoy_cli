import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart' as p;

part 'cast_constraint.dart';
part 'cast_type.dart';
part 'template.dart';
part 'variable.dart';

@immutable
final class Config {
  final List<Variable> variables;
  final List<BaseTemplate> templates;

  Config({
    required this.variables,
    required this.templates,
  });

  double get version => 1.0;

  static Config import(Map<String, dynamic> json) {
    return _ConfigImporter(json).toConfig();
  }
}

@immutable
final class _ConfigImporter {
  final Map<String, dynamic> json;

  const _ConfigImporter(this.json);

  Config toConfig() {
    return Config(
      variables: _variables,
      templates: _templates,
    );
  }

  List<BaseTemplate> get _templates {
    final templates = <BaseTemplate>[];
    for (final Map template in json['templates'] ?? []) {
      if (template.containsKey('template')) {
        templates.add(
          FileTemplate(
            output: template['output'],
            template: template['template'],
          ),
        );
      }

      if (template.containsKey('json')) {
        templates.add(
          JsonTemplate(
            output: template['output'],
            fields: (template['json']['fields'] as List).cast<String>(),
          ),
        );
      }
    }

    return templates;
  }

  List<Variable> get _variables {
    final variables = <Variable>[];

    for (final Map variable in json['variables']) {
      final castTo = variable['castTo'];

      final newCastTo = castTo != null
          ? CastType.import(variable['castTo'])
          : CastType.string;

      final constraint = variable['constraint'];
      CastConstraint? newConstraint;
      if (constraint != null) {
        final constraints = (json['constraints'] as List).firstWhere(
          (e) => e['name'] == constraint,
        );
        newConstraint = CastConstraint(
          name: constraint,
          rules: constraints['rules'],
        );
      }

      Virtual? newVirtual;

      if (variable.containsKey('virtual')) {
        newVirtual = Virtual.from(variable['virtual']);
      } else if (variable.containsKey('exec')) {
        newVirtual = Virtual.from(variable);
      }

      final importVar = Variable(
        name: variable['name'],
        summary: variable['summary'],
        castTo: newCastTo,
        constraint: newConstraint,
        virtual: newVirtual,
      );
      variables.add(importVar);
    }

    return variables;
  }
}
