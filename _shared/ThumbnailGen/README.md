# ThumbnailGen

Shared Nexus Mods thumbnail template and prompt for Kingdom Inc.

## Files

- `thumbnail-master.png`: the original untouched blank artwork master.
- `PROMPT.md`: the image-editing prompt and output rules.

## How to use

Run this workflow during every new-mod creation once the public name is known, without waiting for a separate thumbnail request. Generate the image, move it into the mod's Gen thumbnail folder, show it and ask explicitly for approval. Move it into approved assets only after approval of that image.

1. Open the target mod's `mod.json` and confirm the correct mod name.
2. Read `PROMPT.md` and supply the name as `MOD_NAME`.
3. Supply `BADGE = NONE` for a normal mod, or use `BUGFIX`, `CHEAT`, or a
   different label only when specifically requested.
4. Reference the existing `thumbnail-master.png` directly in the image tool.
   Leave the master where it is; do not copy it into the mod or Gen folder.
5. After successful generation, move only the generated image into
   `{ModName}/_AI/Gen/Assets/Thumbnails/`. Remove temporary thumbnail-generation
   files so that this directory contains only the image. Do not create or retain
   reference copies, hashes, per-image prompt files, generation records or other
   sidecars. Read the shared prompt in place and pass it directly to the tool.
6. Show the image inline and ask, "Do you approve this thumbnail?"
7. Only after explicit approval of that image, move it from Gen into
   `{ModName}/Assets/Thumbnails/`. Move it rather than copying it; a general
   publishing instruction is not thumbnail approval.

These thumbnail-specific rules override general prompt-saving, reference-copying
and generation-material preservation rules. Keep the shared master and shared
`PROMPT.md` unchanged by cleanup; remove only temporary per-image material.

No icons or extra decoration may be added unless explicitly requested.
The top banner text is `KINGDOM .INC` as specified in the prompt.

## Agent routing note

When creating a new mod or asked to create a Nexus thumbnail, agents must read
this directory's `PROMPT.md` and reference `thumbnail-master.png` in place.
Keep only the generated image in the mod's Gen thumbnail folder, show it and ask
for approval. After approval, move that image into `Assets/Thumbnails/`.
