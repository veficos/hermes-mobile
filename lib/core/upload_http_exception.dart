/// Structured HTTP failure produced by the Web multipart uploader.
class UploadHttpException implements Exception {
  final int statusCode;
  final String body;
  final String url;
  const UploadHttpException(this.statusCode, this.body, this.url);

  @override
  String toString() =>
      'upload failed ($statusCode) at $url${body.isEmpty ? '' : ': $body'}';
}
