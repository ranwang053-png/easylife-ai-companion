import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class SelectedPetImage {
  const SelectedPetImage({
    required this.bytes,
    required this.dataUrl,
  });

  final Uint8List bytes;
  final String dataUrl;
}

class PetImagePickerException implements Exception {
  const PetImagePickerException(this.message);

  final String message;
}

Future<SelectedPetImage?> pickPetImage({required bool preferCamera}) async {
  const typeGroup = XTypeGroup(
    label: 'images',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  );
  final file = await openFile(acceptedTypeGroups: const [typeGroup]);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final mimeType = _mimeTypeForFile(file);
  if (mimeType == null) {
    throw const PetImagePickerException('请选择 PNG、JPG 或 WebP 图片');
  }
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const PetImagePickerException('请选择 5MB 以内的 PNG、JPG 或 WebP 图片');
  }
  return SelectedPetImage(
    bytes: bytes,
    dataUrl: 'data:$mimeType;base64,${base64Encode(bytes)}',
  );
}

String? _mimeTypeForFile(XFile file) {
  final mimeType = file.mimeType;
  if (mimeType == 'image/jpeg' ||
      mimeType == 'image/png' ||
      mimeType == 'image/webp') {
    return mimeType;
  }
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.webp')) return 'image/webp';
  return null;
}
