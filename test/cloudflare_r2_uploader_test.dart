import 'dart:typed_data';

import 'package:cloudflare_r2_uploader/cloudflare_r2_uploader.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final uploader = CloudflareR2Uploader(
      accountId: 'your-account',
      accessKeyId: 'your-key',
      secretAccessKey: 'your-secret',
      bucketName: 'my-bucket',
    );

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(
        uploader.uploadFile(
          fileBytes: Uint8List.fromList([]),
          fileName: 'test.txt',
        ),
        isTrue,
      );
    });
  });
}
