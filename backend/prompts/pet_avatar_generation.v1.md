# Pet Avatar Generation Prompt V1

## Inputs

- `subject_image`
- `subject_description`，可选
- `style_reference_images`，可选

输出尺寸、背景和裁切比例由后端 Provider 配置，不重复写入用户 Prompt。

## Production Prompt

Transform the uploaded subject into a premium full-body cartoon cutout collectible mascot figure for Easylife.

Preserve the subject's recognizable identity and the most important visual cues: face shape, hairstyle, outfit colors, accessories, posture, distinctive markings, silhouette, or pet traits.

If the uploaded photo is a portrait, bust, half-body, sitting pose, cropped photo, or only shows the upper body, still create a complete standing full-body character. Infer a plausible lower body, shoes, paws, outfit continuation, and balanced toy proportions from the visible style cues. Do not crop the final character.

Style target: a warm high-end 3D animated collectible toy, blind-box figure, elegant lifestyle mascot. Use large expressive eyes, rounded soft proportions, a slightly chubby but graceful body, a calm friendly expression, detailed toy-grade materials, subtle subsurface scattering, and soft studio lighting.

Composition must be a complete standing character cutout, front-facing or slight three-quarter view, visible from head to shoes/paws, centered with generous transparent margin around the whole body so the app can crop safely. The character should occupy about 62-70% of the canvas height, leaving at least 12% transparent padding above the head/hair/hat, below the shoes/paws, and on both sides. Do not let any body part touch or approach the canvas edge. Not a portrait, not a bust, not only head and shoulders.

Clothing and accessory details matter. Reinterpret the uploaded outfit as layered premium toy clothing with clear fabric folds, scarf/jewelry/bag details when present, refined texture, and a polished collectible finish.

Mood: warm, friendly, comforting, premium, elegant, adult-friendly, cute but not childish, highly appealing as a companion app character.

Output should be a transparent-background PNG-style cutout: no scene, no floor, no room, no outdoor background, no border, no text.

If style reference images are provided, use them only for visual style, material, rendering quality, proportions, and finish. Do not copy the reference subject's identity, face, outfit, logo, text, or background.

Avoid generic identity, over-realistic human skin, flat avatar icon style, cropped body, close-up portrait, head-only mascot, heavy blush, harsh shadows, busy backgrounds, text, logos, watermarks, extra limbs, distorted anatomy, scary expressions, and low-quality rendering.

## Storage And Privacy

- 用户授权后才能发送原图。
- 候选图仅短期保存，用户确认后才持久化最终结果。
- 不记录原图 URL、完整人物描述或身份字段。
- 真人图片必须确认用户拥有使用权。

风格一致性优先通过已批准的参考图控制，不在 Prompt 中堆叠受保护品牌或大量重复风格词。
