# Persona emotion artwork evidence

The PNGs in `assets/personas/{persona}/{mood}.png` are separate built-in `image_gen` edits. Original portraits in `assets/approved_v1/personas/` and legacy asset paths remain unchanged. Runtime assets retain the exact bytes and native alpha returned by the tool; no local pixel or alpha editing was performed.

The five personas each use ten stable mood names: `happy`, `excited`, `hyped`, `cozy`, `complaining`, `annoyed`, `sad`, `worried`, `confident`, and `neutral`.

## Provenance

- `generation_manifest.jsonl` records Karen, Politician, and the four initial reference-card poses. Last matching persona/mood entry is the selected output; superseded source paths remain as generation history.
- `frat_bro_manifest.jsonl`, `grandpa_manifest.jsonl`, and `toddler_manifest.jsonl` record the remaining variants, with prompt, input paths, generated source, destination, and visual observations.
- `emotion_asset_metadata.json` consolidates selected outputs with native dimensions, alpha extrema, byte size, SHA-256, and verification that each runtime PNG matches its generated source exactly.
- `verification.json` checks completeness and distinct hashes. These mechanical checks do not establish clean matting.
- `references/` preserves the four supplied emotion cards used as pose references. Other identity crops remain in `../references/`.

## Visual QA

Each generated image was opened and assessed for recognizable identity, requested expression, costume, framing, and exterior alpha artifacts. `{persona}_light_dark.png` displays the ten moods on light and dark backgrounds at 128 × 171 pixel slots. These are comparison sheets, not application screenshots.

Karen complaining uses crossed arms, Frat Bro hyped uses two thumbs up, Grandpa cozy holds a plain mug, and the excited toddler wears the approved yellow raincoat and boots. These intentional pose/costume variants follow the supplied emotion-card examples. The other images retain the original approved bust clothing. Use aspect-preserving contain layout, especially for the excited toddler's full-body pose.

The generator retains small exterior colored flecks and edge fringes despite explicit clean-alpha instructions. They are much less apparent at card size but remain visible in native PNG inspection. No flawless/production-approved matting claim is made. Frat Bro's sunglasses hide eye changes, so brow, mouth, head inclination, and approved gesture provide his expression cues.

Run `python3 docs/ui_implementation/artwork/emotions/build_emotion_qa.py` with Pillow to refresh measurements and comparison sheets. The script only reads runtime art and writes evidence here; it never cleans or modifies runtime pixels.
