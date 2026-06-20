# Pet Avatar Generation Prompt v1

## Purpose

Generate a premium companion mascot image from a user-uploaded subject photo or a user-provided subject description.

The generated image should preserve the subject's recognizable identity while translating it into Easylife's warm, refined companion style.

## Inputs

The backend provider adapter should supply:

- `subject_image`: user-uploaded image, when available.
- `subject_description`: optional user description of the subject.
- `relationship_context`: optional relationship such as pet, friend, family, partner, favorite person, or imagined companion.
- `style_reference_images`: optional approved Easylife style reference images.
- `output_size`: target image size.
- `background_preference`: default to clean background.

## Output

Expected model output:

- One full-body mascot image.
- Clean background.
- Front-facing centered composition.
- Suitable for use as a companion avatar or collectible-style character image.

The backend should store the generated image only after the user confirms it.

## Production Prompt

Transform the uploaded subject into a premium collectible mascot character for Easylife.

Preserve the subject's unique identity and recognizable features:

- Keep key facial or body features that make the subject identifiable.
- Keep distinctive colors, markings, silhouette, hairstyle, clothing cues, or pet traits when present.
- Avoid changing the subject into a generic character.

Visual style:

- High-end animated feature character quality.
- Premium collectible toy aesthetic.
- Blind-box figure feeling.
- Cute but refined mascot design.
- Rounded shapes.
- Chubby, soft proportions.
- Large expressive eyes.
- Soft, friendly expression.
- Warm, comforting, elegant, and premium.
- Appealing to adults, not childish.
- Consistent with a gentle lifestyle companion app.

Rendering:

- High-end 3D render.
- Soft studio lighting.
- Subtle subsurface scattering.
- Detailed but clean textures.
- Toy-grade materials.
- Smooth premium finish.
- Crisp details.
- High resolution.

Composition:

- Front-facing.
- Full body.
- Centered composition.
- Clean background.
- Enough margin around the character for app UI cropping.
- No busy environment.

Mood:

- Warm.
- Friendly.
- Comforting.
- Premium.
- Elegant.
- Calm and trustworthy.

Avoid:

- Do not make it childish.
- Do not make it exaggerated.
- Do not make it low quality.
- Do not add heavy shadows.
- Do not add sticker-like decorations.
- Do not add obvious blush or overly cute facial marks unless the subject naturally has similar features.
- Do not create a scary, uncanny, aggressive, messy, or cheap-looking character.
- Do not include text, logos, watermarks, UI elements, or brand marks.
- Do not imitate any specific copyrighted studio, franchise, living artist, or trademarked character style.

Quality target:

- Masterpiece-level composition.
- Premium 3D collectible figure.
- Clean app-ready avatar.

## Negative Prompt

low quality, blurry, noisy, distorted anatomy, uncanny face, scary expression, aggressive, messy background, cheap plastic, harsh lighting, overexposed, underexposed, watermark, text, logo, brand mark, sticker, childish, exaggerated, heavy blush, extra limbs, cropped body, side view

## Style Notes

The user-provided draft referenced well-known animated studio styles. For production use, this prompt intentionally generalizes those references into "high-end animated feature character quality" and "premium collectible toy aesthetic" to reduce brand and style imitation risk.

If approved reference images are available, the provider adapter may pass them as `style_reference_images` instead of naming protected brands or studios in the prompt.

## Safety And Privacy Rules

- Do not log the uploaded image URL, complete subject description, or user identity fields.
- Do not send the image to a provider unless the user has granted upload and generation consent.
- If the provider returns multiple candidates, show them as temporary previews and persist only the user-confirmed result.
- For real-person subjects, require explicit user confirmation that they have the right to use the source image.
- For pet subjects, make clear that generated images are stylized and may not perfectly match the pet.

## Version Notes

- v1: Initial production prompt based on user-provided partner mascot generation direction.

