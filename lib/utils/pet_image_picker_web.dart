// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

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
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp';
  if (preferCamera) {
    input.setAttribute('capture', 'environment');
  }
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;
  if (!_isSupportedImage(file.type, file.name)) {
    throw const PetImagePickerException('请选择 PNG、JPG 或 WebP 图片');
  }
  if (file.size <= 0 || file.size > 12 * 1024 * 1024) {
    throw const PetImagePickerException('请选择 12MB 以内的 PNG、JPG 或 WebP 图片');
  }

  final reader = html.FileReader();
  final completer = Completer<String>();
  reader.onLoad.first.then((_) {
    final result = reader.result;
    if (result is String && result.startsWith('data:image/')) {
      completer.complete(result);
    } else {
      completer.completeError(
        const PetImagePickerException('无法读取这张图片，请换一张试试'),
      );
    }
  });
  reader.onError.first.then((_) {
    completer.completeError(
      const PetImagePickerException('无法读取这张图片，请换一张试试'),
    );
  });
  reader.readAsDataUrl(file);
  final dataUrl = await _normalizeImageDataUrl(await completer.future);
  return SelectedPetImage(
    bytes: base64Decode(dataUrl.split(',').last),
    dataUrl: dataUrl,
  );
}

Future<String> _normalizeImageDataUrl(String dataUrl) async {
  final image = html.ImageElement();
  final completer = Completer<void>();
  image.onLoad.first.then((_) => completer.complete());
  image.onError.first.then((_) {
    completer.completeError(
      const PetImagePickerException('无法处理这张图片，请换一张试试'),
    );
  });
  image.src = dataUrl;
  await completer.future;

  final sourceWidth = image.naturalWidth;
  final sourceHeight = image.naturalHeight;
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    throw const PetImagePickerException('无法处理这张图片，请换一张试试');
  }

  const maxSide = 1024;
  final scale = sourceWidth >= sourceHeight
      ? maxSide / sourceWidth
      : maxSide / sourceHeight;
  final targetWidth = (sourceWidth * (scale < 1 ? scale : 1)).round();
  final targetHeight = (sourceHeight * (scale < 1 ? scale : 1)).round();
  final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
  final context = canvas.context2D;
  context
    ..fillStyle = '#ffffff'
    ..fillRect(0, 0, targetWidth, targetHeight)
    ..drawImageScaled(image, 0, 0, targetWidth, targetHeight);

  for (final quality in const [0.88, 0.8, 0.72]) {
    final normalized = canvas.toDataUrl('image/jpeg', quality);
    final bytes = base64Decode(normalized.split(',').last);
    if (bytes.length <= 2 * 1024 * 1024) {
      return normalized;
    }
  }

  throw const PetImagePickerException('这张图片处理后仍然过大，请换一张更清晰的小图');
}

bool _isSupportedImage(String mimeType, String name) {
  if (mimeType == 'image/jpeg' ||
      mimeType == 'image/png' ||
      mimeType == 'image/webp') {
    return true;
  }
  final lowerName = name.toLowerCase();
  return lowerName.endsWith('.png') ||
      lowerName.endsWith('.jpg') ||
      lowerName.endsWith('.jpeg') ||
      lowerName.endsWith('.webp');
}
