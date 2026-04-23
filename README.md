# Envoy 🚀

**Envoy** is a modern Dart CLI tool for managing environment variables and automated file generation based on templates.

Inspired by the architecture of `dart_inlay_cli`, it utilizes `mason_logger` and `interact` to provide a top-tier terminal user experience (UX).

---

## ✨ Features

- 🛠 **Initialization**: Quick project start with the interactive `init` command.
- 📋 **Variables**:
  - Load from system environment and `.env` files.
  - **Virtual Variables**: Execute shell commands to retrieve values (e.g., current git branch).
  - **Cross-platform**: Specify different commands for `linux`, `macos/darwin`, and `windows`.
  - **Type Casting**: Automatic casting to `int`, `boolean`, `double`, and `string`.
  - **Validation**: Value checking via JSON Schema (constraints).
- 📄 **Templates**:
  - Text file generation using **Mustache**.
  - Automated **JSON** config assembly from selected variables.
- 🔍 **Inspection**: Powerful `variable list` command to debug and verify all values before building.

---

## 🚀 Installation

If you are working with the source code:

```bash
dart pub get
```

To use via `dart run`:

```bash
dart run bin/envoy.dart --help
```

---

## 📖 Usage

### 1. Project Initialization
Creates a basic `envoy.yaml` configuration file interactively.

```bash
dart run bin/envoy.dart init
```

### 2. Build
Processes all templates and generates files. If no command is provided, `build` runs by default.

```bash
# Standard build
dart run bin/envoy.dart build

# Using a .env file and verbose logging
dart run bin/envoy.dart -e -v
```

**Flags:**
- `-c, --config`: Path to the configuration file (defaults to `envoy.yaml`).
- `-e, --env`: Load variables from `.env`.
- `-f, --force`: Overwrite files without prompting.
- `-v, --verbose`: Detailed output (logging).

### 3. Variable Inspection
Lists all variables, their summaries, types, validation rules, and current resolved values.

```bash
dart run bin/envoy.dart variable list -e
```

---

## ⚙️ Configuration (envoy.yaml)

```yaml
version: 1.0

# Validation rules
constraints:
  - name: port_range
    rules:
      minimum: 1024
      maximum: 65535

variables:
  - name: PORT
    summary: Port to run the server on
    castTo: int
    constraint: port_range

  - name: GIT_BRANCH
    summary: Current git branch
    exec: git rev-parse --abbrev-ref HEAD

  - name: PWD
    summary: Current working directory
    exec:
      linux: pwd
      darwin: pwd
      windows: dir

templates:
  - output: lib/config.g.dart
    template: templates/config.mustache

  - output: assets/config.json
    json:
      fields: [PORT, GIT_BRANCH, PWD]
```

---

## 🛠 Development

The project uses:
- [mason_logger](https://pub.dev/packages/mason_logger) — for progress bars and beautiful logs.
- [interact](https://pub.dev/packages/interact) — for interactive dialogues.
- [mustache_template](https://pub.dev/packages/mustache_template) — for the template engine.
- [json_schema](https://pub.dev/packages/json_schema) — for constraint validation.

---

## 📄 License

MIT
