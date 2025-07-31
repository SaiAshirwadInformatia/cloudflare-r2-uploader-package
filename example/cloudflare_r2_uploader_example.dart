import 'dart:io';
import 'package:cloudflare_r2_uploader/cloudflare_r2_uploader.dart';

void main() async {
  final uploader = CloudflareR2Uploader(
    accountId: 'your-account-id',
    accessKeyId: 'your-access-key',
    secretAccessKey: 'your-secret-access-key',
    bucketName: 'your-bucket',
  );

  final fileBytes = await File('example.jpg').readAsBytes();

  final url = await uploader.uploadFile(
    fileBytes: fileBytes,
    fileName: 'example.jpg',
    folderName: 'uploads',
    onProgress: (progress) =>
        print('Upload Progress: ${(progress * 100).toStringAsFixed(0)}%'),
  );

  if (url != null) {
    print('✅ File uploaded successfully: $url');
  } else {
    print('❌ Upload failed');
  }
}
