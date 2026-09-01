final updateVersionPattern = RegExp(
  r'^v?\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z.-]+)?$',
);

int compareAppVersions(String left, String right) {
  List<int> parts(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final core = normalized.split(RegExp(r'[-+]')).first;
    return core
        .split('.')
        .take(4)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  final a = parts(left);
  final b = parts(right);
  final width = a.length > b.length ? a.length : b.length;
  for (var index = 0; index < width; index++) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

void validateUpdateManifestPayload(
  Map<String, dynamic> manifest, {
  bool requireArtifacts = true,
  Map<String, dynamic>? previous,
}) {
  if (manifest['schema_version'] != 2) {
    throw const FormatException('schema_version must be 2');
  }
  final latest = manifest['latest_version']?.toString() ?? '';
  final minimum = manifest['minimum_supported_version']?.toString() ?? '';
  if (!updateVersionPattern.hasMatch(latest)) {
    throw const FormatException('latest_version is invalid');
  }
  if (!updateVersionPattern.hasMatch(minimum)) {
    throw const FormatException('minimum_supported_version is invalid');
  }
  if (compareAppVersions(minimum, latest) > 0) {
    throw const FormatException(
      'minimum_supported_version cannot exceed latest_version',
    );
  }
  _requireHttps(manifest['release_notes_url'], 'release_notes_url');

  for (final platform in const ['android', 'ios']) {
    final raw = manifest[platform];
    if (raw is! Map) throw FormatException('$platform must be an object');
    final config = raw.cast<String, dynamic>();
    _requirePositiveInt(config['build'], '$platform.build');
    _requirePositiveInt(config['minimum_build'], '$platform.minimum_build');
    if ((config['minimum_build'] as int) > (config['build'] as int)) {
      throw FormatException(
        '$platform.minimum_build cannot exceed $platform.build',
      );
    }
    _requireHttps(config['url'], '$platform.url');

    final artifactFieldsPresent = const [
      'artifact_url',
      'sha256',
      'size_bytes',
    ].any(config.containsKey);
    if (requireArtifacts || artifactFieldsPresent) {
      _requireHttps(config['artifact_url'], '$platform.artifact_url');
      final hash = config['sha256']?.toString() ?? '';
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        throw FormatException(
          '$platform.sha256 must be 64 lowercase hex chars',
        );
      }
      _requirePositiveInt(config['size_bytes'], '$platform.size_bytes');
    }
  }

  if (previous != null) {
    validateUpdateManifestPayload(previous, requireArtifacts: false);
    final previousVersion = previous['latest_version'].toString();
    if (compareAppVersions(latest, previousVersion) < 0) {
      throw const FormatException('latest_version cannot move backwards');
    }
    for (final platform in const ['android', 'ios']) {
      final currentBuild = (manifest[platform] as Map)['build'] as int;
      final previousBuild = (previous[platform] as Map)['build'] as int;
      if (currentBuild < previousBuild) {
        throw FormatException('$platform.build cannot move backwards');
      }
      if (compareAppVersions(latest, previousVersion) > 0 &&
          currentBuild == previousBuild) {
        throw FormatException(
          '$platform.build must increase for a newer version',
        );
      }
    }
  }
}

void _requirePositiveInt(Object? value, String field) {
  if (value is! int || value < 1) {
    throw FormatException('$field must be a positive integer');
  }
}

void _requireHttps(Object? value, String field) {
  final uri = Uri.tryParse(value?.toString() ?? '');
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw FormatException('$field must be an HTTPS URL');
  }
}
