# Kingdom Inc. - Nexus Thumbnail Generation Prompt

## Required inputs

Use this prompt during new-mod creation as soon as the public name is known; no separate thumbnail request or Nexus page URL is needed. Generate the image, move only the image into the mod's Gen thumbnail folder, show it and ask explicitly for approval. Follow the output rules below.

- Reference image: the existing `thumbnail-master.png` (reference its current path directly; do not copy it)
- `MOD_NAME`: the exact mod name to display
- `BADGE`: `NONE`, `BUGFIX`, `CHEAT`, or another explicitly requested label

## Image editing prompt

Edit the supplied `thumbnail-master.png` into a finished Nexus Mods thumbnail for the
Kingdom Inc. mod named `{{MOD_NAME}}`.

**This is an edit of the supplied master, not a new design.** Preserve its 16:9
composition, dimensions/aspect ratio, existing decorative details, border, wood,
stone, brackets, banners, parchment shape, colors, shading, and crisp, square-pixel
art style. Do not redraw or rearrange the frame. Do not introduce new decorative
icons, pictures, symbols, props, characters, or patterns unless specifically
requested for this mod. Existing ornaments in the master should remain unchanged.

Only add the following text and, when requested, the small bottom badge:

1. **Top burgundy banner**: Center the exact text **KINGDOM .INC**. Set it in
   legible uppercase medieval pixel-art lettering, antique gold or ivory, sized
   to fit comfortably within the existing banner without crossing its border.
2. **Central ivory parchment**: Display the exact text **{{MOD_NAME}}** prominently
   and centered both horizontally and vertically. Use a bold, readable pixel-art
   title treatment in deep burgundy/dark umber with restrained antique-gold
   detailing if needed for readability. Keep generous blank padding from the
   parchment edges. For long names, reduce the text size or use at most two
   centered lines; never clip letters or alter the parchment to make room.
3. **Bottom dark-green area**:
   - If `BADGE` is `NONE` or left blank, leave the area **completely unchanged**.
     No plaque, badge, subtitle, frame, or added decoration.
   - If `BADGE` has a value such as `BUGFIX`, `CHEAT`, or an explicitly supplied
     label, add **one small ornamental plaque**, centered horizontally within
     the existing dark-green area. Display that label in uppercase pixel text.
     Keep its width only slightly larger than the text, with modest symmetric
     padding, and its height only large enough for the text and thin border.
     Do NOT make a wide strip or span the bottom region. Use the same burgundy,
     walnut, antique-gold and ivory palette as the original frame.

**Strict text requirements:** No text other than `KINGDOM .INC`, `{{MOD_NAME}}`,
and the optional `BADGE` label. Spelling must be exact. No watermark, logo,
placeholder text, technical labels, extra subtitles, or decorative lettering.

**Strict style requirements:** Authentic crisp pixel art, hard square pixel
edges, clean silhouettes, simple shading, no soft blur, photorealism, 3D,
painted textures, or gradients. Preserve the master's opaque background.
The result should remain readable as a small Nexus Mods listing thumbnail.

## Output and approval rules

- Render one finished PNG with an opaque background and the master's 16:9 ratio.
- Do not modify or overwrite `thumbnail-master.png`.
- After successful generation, move only the image into
  `{ModName}/_AI/Gen/Assets/Thumbnails/`.
- Remove temporary per-image files after successful generation. Leave only the
  image in the Gen thumbnail folder: no copied references, hashes, saved
  per-image prompts, generation records or other sidecars. Read this shared
  prompt in place; do not save a per-mod copy.
- Show the image inline and ask, "Do you approve this thumbnail?" A general
  publishing instruction does not substitute for approval of the image.
- Only after approval, move that image from Gen into
  `{ModName}/Assets/Thumbnails/`; do not leave a duplicate in Gen.
- These thumbnail-specific rules override general generation-material saving
  and preservation rules. Cleanup must leave the shared master and shared
  prompt intact. Only the approved image belongs in `Assets/Thumbnails/`.

## Examples of variable substitution

- Standard mod: `MOD_NAME = Better Building`, `BADGE = NONE`
- Bugfix mod: `MOD_NAME = Capsule Cleanup`, `BADGE = BUGFIX`
- Cheat mod: `MOD_NAME = Easy Resources`, `BADGE = CHEAT`
- Other label: `MOD_NAME = My Mod`, `BADGE = <explicit user-supplied label>`
