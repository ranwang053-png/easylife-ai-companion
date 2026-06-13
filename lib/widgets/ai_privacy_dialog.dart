import 'package:flutter/material.dart';

Future<bool?> showAiPrivacyDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AI 形象生成说明'),
      content: const Text(
        '我们会根据你上传的宠物照片生成一个陪伴形象。当前版本仅为原型演示，不会真实上传图片。'
        '未来接入 AI 服务时，会在获得你的同意后再处理图片。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('暂不使用'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('同意并继续'),
        ),
      ],
    ),
  );
}
