import 'dart:convert';
import 'dart:io';

import 'package:hermes_mobile/core/update_manifest_crypto.dart';
import 'package:hermes_mobile/core/update_manifest_schema.dart';

Future<void> main(List<String> args) async {
  try {
    final options = _Options.parse(args);
    final document = _readJsonObject(options.path);
    final signed = document.containsKey('signed');
    final publicKey =
        options.publicKey ??
        Platform.environment['HERMES_MOBILE_UPDATE_PUBLIC_KEY'] ??
        '';
    final payload = await verifyUpdateManifestEnvelope(
      document,
      publicKey: publicKey,
      allowUnsigned: !signed,
    );
    final previous = options.previousPath == null
        ? null
        : await _readPayload(options.previousPath!, publicKey: publicKey);
    validateUpdateManifestPayload(
      payload,
      requireArtifacts: signed || options.requireArtifacts,
      previous: previous,
    );
    final latest = payload['latest_version'];
    final androidBuild = (payload['android'] as Map)['build'];
    final iosBuild = (payload['ios'] as Map)['build'];
    stdout.writeln(
      'Valid Hermes Mobile ${signed ? 'signed' : 'source'} manifest: '
      'latest=$latest android_build=$androidBuild ios_build=$iosBuild',
    );
  } on FormatException catch (error) {
    stderr.writeln('Invalid update manifest: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Invalid update manifest: ${error.message}');
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

Future<Map<String, dynamic>> _readPayload(
  String path, {
  required String publicKey,
}) async {
  final document = _readJsonObject(path);
  return verifyUpdateManifestEnvelope(
    document,
    publicKey: publicKey,
    allowUnsigned: !document.containsKey('signed'),
  );
}

class _Options {
  final String path;
  final String? publicKey;
  final String? previousPath;
  final bool requireArtifacts;

  const _Options({
    required this.path,
    required this.publicKey,
    required this.previousPath,
    required this.requireArtifacts,
  });

  factory _Options.parse(List<String> args) {
    String? path;
    String? publicKey;
    String? previousPath;
    var requireArtifacts = false;
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--require-artifacts') {
        requireArtifacts = true;
      } else if (arg == '--public-key' || arg == '--previous') {
        if (++index >= args.length) throw ArgumentError('$arg needs a value');
        if (arg == '--public-key') {
          publicKey = args[index];
        } else {
          previousPath = args[index];
        }
      } else if (arg.startsWith('--public-key=')) {
        publicKey = arg.substring('--public-key='.length);
      } else if (arg.startsWith('--previous=')) {
        previousPath = arg.substring('--previous='.length);
      } else if (arg.startsWith('-')) {
        throw ArgumentError('unknown option $arg');
      } else if (path == null) {
        path = arg;
      } else {
        throw ArgumentError('only one manifest path is allowed');
      }
    }
    return _Options(
      path: path ?? 'update.json',
      publicKey: publicKey,
      previousPath: previousPath,
      requireArtifacts: requireArtifacts,
    );
  }
}
