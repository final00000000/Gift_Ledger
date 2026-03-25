int compareSemver(String left, String right) {
  final leftVersion = _ParsedSemver.parse(left);
  final rightVersion = _ParsedSemver.parse(right);

  final coreComparison = _compareCore(leftVersion, rightVersion);
  if (coreComparison != 0) {
    return coreComparison;
  }

  return _comparePrerelease(leftVersion.prerelease, rightVersion.prerelease);
}

int _compareCore(_ParsedSemver left, _ParsedSemver right) {
  final major = left.major.compareTo(right.major);
  if (major != 0) {
    return major;
  }

  final minor = left.minor.compareTo(right.minor);
  if (minor != 0) {
    return minor;
  }

  return left.patch.compareTo(right.patch);
}

int _comparePrerelease(List<String> left, List<String> right) {
  if (left.isEmpty && right.isEmpty) {
    return 0;
  }
  if (left.isEmpty) {
    return 1;
  }
  if (right.isEmpty) {
    return -1;
  }

  final maxLength = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < maxLength; index++) {
    if (index >= left.length) {
      return -1;
    }
    if (index >= right.length) {
      return 1;
    }

    final result = _compareIdentifier(left[index], right[index]);
    if (result != 0) {
      return result;
    }
  }

  return 0;
}

int _compareIdentifier(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);

  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  if (leftNumber != null) {
    return -1;
  }
  if (rightNumber != null) {
    return 1;
  }
  return left.compareTo(right);
}

class _ParsedSemver {
  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  const _ParsedSemver({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
  });

  factory _ParsedSemver.parse(String value) {
    final normalized = value.split('+').first.trim();
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$',
    ).firstMatch(normalized);

    if (match == null) {
      throw FormatException('Invalid semantic version: $value');
    }

    final prereleasePart = match.group(4);
    return _ParsedSemver(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: prereleasePart == null || prereleasePart.isEmpty
          ? const <String>[]
          : prereleasePart.split('.'),
    );
  }
}
