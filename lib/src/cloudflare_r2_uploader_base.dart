import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class CloudflareR2Uploader {
  final String accountId;
  final String accessKeyId;
  final String secretAccessKey;
  final String bucketName;
  final String region;

  CloudflareR2Uploader({
    required this.accountId,
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.bucketName,
    this.region = 'auto',
  });

  String get _baseUrl => 'https://$accountId.r2.cloudflarestorage.com';

  // Upload file with automatic MIME type detection
  Future<String?> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String? contentType,
    String? folderName,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Auto-detect content type if not provided
      contentType ??= lookupMimeType(fileName) ?? 'application/octet-stream';

      final url =
          '$_baseUrl/$bucketName/${folderName == null ? "" : '$folderName/'}$fileName';
      final uri = Uri.parse(url);

      onProgress?.call(0.1);

      final headers = await _createSignedHeaders(
        method: 'PUT',
        uri: uri,
        contentType: contentType,
        contentLength: fileBytes.length,
        payload: fileBytes,
      );

      onProgress?.call(0.3);

      final response = await http.put(uri, headers: headers, body: fileBytes);

      onProgress?.call(0.9);

      if (response.statusCode == 200 || response.statusCode == 204) {
        onProgress?.call(1.0);
        return '$_baseUrl/$bucketName/${folderName == null ? "" : '$folderName/'}$fileName';
      } else {
        log('Upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      log('Error uploading file: $e');
      return null;
    }
  }

  Future<Map<String, String>> _createSignedHeaders({
    required String method,
    required Uri uri,
    required String contentType,
    required int contentLength,
    required Uint8List payload,
  }) async {
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatDateTime(now);

    final canonicalUri = uri.path;
    final canonicalQueryString = uri.query;
    final host = uri.host;

    final canonicalHeaders = {
      'host': host,
      'x-amz-content-sha256': _sha256Hash(payload),
      'x-amz-date': amzDate,
      'content-type': contentType,
      'content-length': contentLength.toString(),
    };

    final signedHeaders = canonicalHeaders.keys.toList()..sort();
    final canonicalHeadersString = signedHeaders
        .map((key) => '$key:${canonicalHeaders[key]}')
        .join('\n');

    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQueryString,
      canonicalHeadersString,
      '',
      signedHeaders.join(';'),
      canonicalHeaders['x-amz-content-sha256']!,
    ].join('\n');

    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      _sha256Hash(utf8.encode(canonicalRequest)),
    ].join('\n');

    final signature = _calculateSignature(stringToSign, dateStamp);

    final authorization =
        '$algorithm '
        'Credential=$accessKeyId/$credentialScope, '
        'SignedHeaders=${signedHeaders.join(';')}, '
        'Signature=$signature';

    return {
      'Authorization': authorization,
      'Content-Type': contentType,
      'Content-Length': contentLength.toString(),
      'X-Amz-Content-Sha256': canonicalHeaders['x-amz-content-sha256']!,
      'X-Amz-Date': amzDate,
    };
  }

  String _calculateSignature(String stringToSign, String dateStamp) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretAccessKey'), dateStamp);
    final kRegion = _hmacSha256(kDate, region);
    final kService = _hmacSha256(kRegion, 's3');
    final kSigning = _hmacSha256(kService, 'aws4_request');
    final signature = _hmacSha256(kSigning, stringToSign);

    return signature
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  List<int> _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  String _sha256Hash(List<int> data) {
    return sha256.convert(data).toString();
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)}T'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}Z';
  }
}
