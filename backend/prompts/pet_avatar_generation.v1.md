# Pet Avatar Generation Prompt V1

## Inputs

- `subject_image`
- `subject_description`，可选
- `style_reference_images`，可选

输出尺寸、背景和裁切比例由后端 Provider 配置，不重复写入用户 Prompt。

## Production Prompt

Transform the uploaded subject into a refined premium 3D collectible mascot for Easylife.

Preserve the subject's recognizable identity, distinctive colors, markings, silhouette, facial features, hairstyle, clothing cues, or pet traits.

Use a warm animated-feature character quality with rounded soft proportions, expressive eyes, a calm friendly expression, detailed toy-grade materials, subtle subsurface scattering, and soft studio lighting. The result should feel elegant, comforting, adult-friendly, and suitable for a premium lifestyle companion app.

Create a front-facing, full-body, centered composition on a clean background with enough margin for app cropping.

Avoid generic identity, childish or exaggerated styling, heavy blush, harsh shadows, busy backgrounds, text, logos, watermarks, extra limbs, distorted anatomy, cropped bodies, scary expressions, and low-quality rendering.

## Storage And Privacy

- 用户授权后才能发送原图。
- 候选图仅短期保存，用户确认后才持久化最终结果。
- 不记录原图 URL、完整人物描述或身份字段。
- 真人图片必须确认用户拥有使用权。

风格一致性优先通过已批准的参考图控制，不在 Prompt 中堆叠受保护品牌或大量重复风格词。
