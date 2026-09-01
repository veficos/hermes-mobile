/// Structured HTTP failure that keeps transport details out of user-facing
/// error strings. UI boundaries should localize [statusCode].
class HttpStatusException implements Exception {
  final int statusCode;

  const HttpStatusException(this.statusCode);
}
