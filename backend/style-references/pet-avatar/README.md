# Pet avatar style references

Put optional style reference images here to guide Easylife partner avatar generation.

Supported formats:

- `.png`
- `.jpg`
- `.jpeg`
- `.webp`

Rules:

- The backend reads up to the first 3 images in filename order only when
  `AI_PET_AVATAR_STYLE_REFERENCE_DIR` points to this folder or another explicit
  reference folder.
- Each image should be 8MB or smaller.
- These images are used only as style, material, proportion, and rendering references.
- Restart the backend after adding, replacing, or removing reference images.

The backend no longer reads this folder by default. This avoids extra image
model input cost and prevents reference subjects, icons, or marks from being
copied into the generated avatar unintentionally. Enable it explicitly with
`AI_PET_AVATAR_STYLE_REFERENCE_DIR` after confirming the cost and style tradeoff.
