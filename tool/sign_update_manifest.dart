import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hermes_mobile/core/update_manifest_crypto.dart';
import 'package:hermes_mobile/core/update_manifest_schema.dart';

Future<void> main(List<String> args) async {
  try {
    final options = _SignOptions.parse(args);
    final privateKey =
        Platform.environment['HERMES_MOBILE_UPDATE_PRIVATE_KEY']?.trim() ?? '';
    if (privateKey.isEmpty) {
      throw const FormatException(
        'HERMES_MOBILE_UPDATE_PRIVATE_KEY is not configured',
      );
    }
    final source = _readJsonObject(options.source);
    final expectedPublicKey =
        options.expectedPublicKey ??
        Platform.environment['HERMES_MOBILE_UPDATE_PUBLIC_KEY'];
    final sourcePayload = source.containsKey('signed')
        ? await verifyUpdateManifestEnvelope(
            source,
            publicKey: expectedPublicKey ?? '',
          )
        : source;
    final payload =
        jsonDecode(jsonEncode(sourcePayload)) as Map<String, dynamic>;
    _applyOverrides(payload, options);
    validateUpdateManifestPayload(payload, requireArtifacts: false);

    await _attachArtifact(
      payload,
      platform: 'android',
      path: options.androidArtifact,
      url: options.androidArtifactUrl,
    );
    await _attachArtifact(
      payload,
      platform: 'ios',
      path: options.iosArtifact,
      url: options.iosArtifactUrl,
    );
    payload['published_at'] = DateTime.now().toUtc().toIso8601String();
    if (options.releaseTag != null) payload['release_tag'] = options.releaseTag;
    validateUpdateManifestPayload(payload);

    final signed = await signUpdateManifestPayload(
      payload,
      privateKey: privateKey,
    );
    if (expectedPublicKey?.trim().isNotEmpty == true &&
        expectedPublicKey!.trim() != signed.publicKey) {
      throw const FormatException(
        'signing key does not match HERMES_MOBILE_UPDATE_PUBLIC_KEY',
      );
    }

    final output = File(options.output);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(signed.envelope)}\n',
      flush: true,
    );
    stdout.writeln(
      'Signed Hermes Mobile manifest: ${options.output} '
      'public_key=${signed.publicKey} key_id=${signed.keyId}',
    );
  } on FormatException catch (error) {
    stderr.writeln('Unable to sign update manifest: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Unable to sign update manifest: ${error.message}');
    exitCode = 1;
  } on ArgumentError catch (error) {
    stderr.writeln('Invalid arguments: ${error.message}');
    exitCode = 64;
  }
}

Map<String, dynamic> _readJsonObject(String path) {
  final file = File(path);
  if (!file.existsSync()) throw FormatException('$path does not exist');
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) throw FormatException('$path root must be an object');
  return decoded.cast<String, dynamic>();
}

void _applyOverrides(Map<String, dynamic> payload, _SignOptions options) {
  if (options.version != null) payload['latest_version'] = options.version;
  if (options.minimumVersion != null) {
    payload['minimum_supported_version'] = options.minimumVersion;
  }
  if (options.releaseNotesUrl != null) {
    payload['release_notes_url'] = options.releaseNotesUrl;
  }
  final android = (payload['android'] as Map).cast<String, dynamic>();
  final ios = (payload['ios'] as Map).cast<String, dynamic>();
  if (options.androidBuild != null) android['build'] = options.androidBuild;
  if (options.iosBuild != null) ios['build'] = options.iosBuild;
  if (options.androidUpdateUrl != null) {
    android['url'] = options.androidUpdateUrl;
  }
  if (options.iosUpdateUrl != null) ios['url'] = options.iosUpdateUrl;
  if (options.androidMinimumBuild != null) {
    android['minimum_build'] = options.androidMinimumBuild;
  }
  if (options.iosMinimumBuild != null) {
    ios['minimum_build'] = options.iosMinimumBuild;
  }
  payload['android'] = android;
  payload['ios'] = ios;
}

Future<void> _attachArtifact(
  Map<String, dynamic> payload, {
  required String platform,
  required String path,
  required String url,
}) async {
  final file = File(path);
  if (!await file.exists()) throw FormatException('$path does not exist');
  final digest = await sha256.bind(file.openRead()).first;
  final config = (payload[platform] as Map).cast<String, dynamic>();
  config['artifact_url'] = url;
  config['sha256'] = digest.toString();
  config['size_bytes'] = await file.length();
  config['artifact_name'] = file.uri.pathSegments.last;
  payload[platform] = config;
}

class _SignOptions {
  final String source;
  final String output;
  final String androidArtifact;
  final String androidArtifactUrl;
  final String iosArtifact;
  final String iosArtifactUrl;
  final String? expectedPublicKey;
  final String? version;
  final String? minimumVersion;
  final String? releaseNotesUrl;
  final String? releaseTag;
  final String? androidUpdateUrl;
  final String? iosUpdateUrl;
  final int? androidBuild;
  final int? iosBuild;
  final int? androidMinimumBuild;
  final int? iosMinimumBuild;

  const _SignOptions({
    required this.source,
    required this.output,
    required this.androidArtifact,
    required this.androidArtifactUrl,
    required this.iosArtifact,
    required this.iosArtifactUrl,
    required this.expectedPublicKey,
    required this.version,
    required this.minimumVersion,
    required this.releaseNotesUrl,
    required this.releaseTag,
    required this.androidUpdateUrl,
    required this.iosUpdateUrl,
    required this.androidBuild,
    required this.iosBuild,
    required this.androidMinimumBuild,
    required this.iosMinimumBuild,
  });

  factory _SignOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (!arg.startsWith('--')) throw ArgumentError('unexpected $arg');
      final equals = arg.indexOf('=');
      if (equals > 2) {
        values[arg.substring(2, equals)] = arg.substring(equals + 1);
        continue;
      }
      if (++index >= args.length) throw ArgumentError('$arg needs a value');
      values[arg.substring(2)] = args[index];
    }
    const known = {
      'source',
      'output',
      'android-artifact',
      'android-artifact-url',
      'ios-artifact',
      'ios-artifact-url',
      'expected-public-key',
      'version',
      'minimum-version',
      'release-notes-url',
      'release-tag',
      'android-update-url',
      'ios-update-url',
      'android-build',
      'ios-build',
      'android-minimum-build',
      'ios-minimum-build',
    };
    final unknown = values.keys.where((key) => !known.contains(key)).toList();
    if (unknown.isNotEmpty) throw ArgumentError('unknown --${unknown.first}');
    String required(String name, [String? fallback]) {
      final value = values[name] ?? fallback;
      if (value == null || value.trim().isEmpty) {
        throw ArgumentError('--$name is required');
      }
      return value;
    }

    int? integer(String name) {
      final value = values[name];
      if (value == null) return null;
      final parsed = int.tryParse(value);
      if (parsed == null) throw ArgumentError('--$name must be an integer');
      return parsed;
    }

    return _SignOptions(
      source: required('source', 'update.json'),
      output: required('output'),
      androidArtifact: required('android-artifact'),
      androidArtifactUrl: required('android-artifact-url'),
      iosArtifact: required('ios-artifact'),
      iosArtifactUrl: required('ios-artifact-url'),
      expectedPublicKey: values['expected-public-key'],
      version: values['version'],
      minimumVersion: values['minimum-version'],
      releaseNotesUrl: values['release-notes-url'],
      releaseTag: values['release-tag'],
      androidUpdateUrl: values['android-update-url'],
      iosUpdateUrl: values['ios-update-url'],
      androidBuild: integer('android-build'),
      iosBuild: integer('ios-build'),
      androidMinimumBuild: integer('android-minimum-build'),
      iosMinimumBuild: integer('ios-minimum-build'),
    );
  }
}
