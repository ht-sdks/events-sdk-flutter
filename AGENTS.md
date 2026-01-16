# Agent Instructions

This file provides instructions for AI agents working on this Flutter/Dart monorepo.

## Project Overview

- **Language**: Dart (not TypeScript)
- **Framework**: Flutter SDK
- **Package Manager**: `pub` (similar to npm)
- **Package Config**: `pubspec.yaml` (similar to package.json)
- **Lock File**: `pubspec.lock`

### Project Structure

```
packages/
  core/                  # Main SDK: hightouch_events (published to pub.dev)
  plugins/
    plugin_adjust/       # Not yet published
    plugin_advertising_id/
    plugin_appsflyer/
    plugin_firebase/
    plugin_idfa/
example/                 # Demo app
```

---

## Updating Dependencies

### 1. Pre-flight Checks

```bash
# Check Flutter is installed
flutter doctor

# Ensure you're in the package directory
cd packages/core
```

### 2. Establish Test Baseline

```bash
flutter test
```
Record the number of passing/skipped tests before making any changes. This ensures you can verify nothing broke after upgrading.

### 3. Check for Security Advisories

```bash
flutter pub get
```
This automatically warns about known security advisories (unlike npm which requires `npm audit`).

### 4. Check Outdated Packages

```bash
flutter pub outdated
```

This shows:
- **Current**: Installed version
- **Upgradable**: Latest within current constraints
- **Resolvable**: Latest with loosened constraints
- **Latest**: Newest available

### 5. Upgrade Dependencies

```bash
# Upgrade within existing constraints
flutter pub upgrade

# Upgrade including major versions (updates pubspec.yaml automatically)
flutter pub upgrade --major-versions
```

### 6. Run Tests Again

```bash
flutter test
```
Compare to baseline. Fix any failures before proceeding.

### 7. Run Static Analysis

```bash
flutter analyze
```
Fix any errors. Info-level suggestions are optional.

### 8. Update All Packages in Monorepo

This is a **monorepo without centralized tooling**. Run upgrade commands in each package directory:

```bash
# Core (most important - do first)
cd packages/core && flutter pub upgrade --major-versions

# Plugins
cd packages/plugins/plugin_adjust && flutter pub upgrade --major-versions
cd packages/plugins/plugin_advertising_id && flutter pub upgrade --major-versions
cd packages/plugins/plugin_appsflyer && flutter pub upgrade --major-versions
cd packages/plugins/plugin_firebase && flutter pub upgrade --major-versions
cd packages/plugins/plugin_idfa && flutter pub upgrade --major-versions

# Example app
cd example && flutter pub upgrade --major-versions
```

---

## Version Bumping

### Semantic Versioning

- **PATCH** (1.0.1 → 1.0.2): Bug fixes, dependency updates, no new features
- **MINOR** (1.0.1 → 1.1.0): New backwards-compatible features
- **MAJOR** (1.0.1 → 2.0.0): Breaking API changes

Dependency updates are typically **PATCH** bumps.

### Files to Update (must stay in sync)

1. `packages/core/pubspec.yaml` → `version: X.Y.Z`
2. `packages/core/lib/version.dart` → `const hightouchVersion = "X.Y.Z";`
3. `packages/core/CHANGELOG.md` → Add entry at top

### Changelog Format

```markdown
## X.Y.Z

- Description of change 1
- Description of change 2
```

---

## Publishing to pub.dev

See `RELEASE.md` for full instructions.

```bash
cd packages/core

# Dry run first
flutter pub publish --dry-run

# Authenticate (if needed)
dart pub login

# Publish
flutter pub publish
```

**Note**: Only `packages/core` (hightouch_events) is currently published. Plugins are not yet on pub.dev.

---

## CI/CD

- CI config: `.github/workflows/ci.yml`
- Uses latest stable Flutter (`channel: stable`)
- Runs: `flutter pub get`, `flutter analyze`, `flutter test`

### CI Failures After Dependency Updates

If CI fails with Dart SDK version errors after updating dependencies:
1. Check what Dart version the new dependency requires
2. CI uses latest stable Flutter, which should be sufficient
3. If pinned to old version, update or remove the pin

---

## Common Issues

### Breaking API Changes

When upgrading major versions, APIs may change. Example from this project:
- `flutter_fgbg` 0.3→0.7 changed `FGBGEvents.stream` to `FGBGEvents.instance.stream`

Search for compile errors after upgrading and fix accordingly.

### New Lint Warnings

Upgrading `flutter_lints` may introduce new warnings. Common fixes:
- `use_super_parameters`: Use `super.paramName` instead of `this.paramName` in constructors
- `strict_top_level_inference`: Add explicit return types
- `unnecessary_this`: Remove redundant `this.` prefixes

These are safe style changes with no runtime impact.

### Transitive Dependency Constraints

Some packages can't be upgraded because they're constrained by:
- Flutter SDK itself
- Other transitive dependencies

These will update automatically when Flutter updates.

---

## Running the Example App

```bash
cd example
flutter run -d chrome    # Web
flutter run -d macos     # macOS
flutter run              # Default device
```

Hot reload: `r` | Hot restart: `R` | Quit: `q`

**Note**: Changes to initialization code (like `Configuration()`) require hot restart (`R`), not hot reload (`r`).

---

## Quick Reference

| npm equivalent | Flutter/pub command |
|----------------|---------------------|
| `npm install` | `flutter pub get` |
| `npm update` | `flutter pub upgrade` |
| `npm outdated` | `flutter pub outdated` |
| `npm audit` | Built into `flutter pub get` |
| `npm test` | `flutter test` |
| `npm run lint` | `flutter analyze` |
| `npm publish` | `flutter pub publish` |

