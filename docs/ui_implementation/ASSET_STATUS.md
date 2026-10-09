# Approved artwork status

Updated October 9, 2026. All 11 requested runtime assets exist in `assets/approved_v1/`. These are **reference-guided reconstructions**, not recovered high-resolution originals, vectors, or exact duplicates of the approved board. The built-in `image_gen` tool was used; no API-key/CLI fallback was used. Legacy artwork remains untouched for compatibility with existing saved documents.

## Source search and provenance

The relevant project asset directories were inventoried and visually inspected using `artwork/legacy_asset_audit.png`. Existing persona faces, costumes and style differ from the approved design; none was reused as the new approved identity. The package's light board and native crops were viewed before reconstruction. The light board identity is shared by both app themes.

Karen and Grandpa were recovered from completed generated files left by the interrupted earlier artwork run, then visually compared with the approved crops. They are still reconstructions; “recovered” refers to recovering that tool output, not discovering original design masters. The other nine assets were generated in the resumed run. Original generated files remain in `~/.codex/generated_images/`; precise source paths, SHA-256 hashes, runtime dimensions and alpha ranges are recorded in `artwork/asset_metadata.json`. Copies of native reference crops are in `artwork/references/`.

## Runtime inventory

All paths below are relative to `assets/approved_v1/`. All PNGs retain their generated native size; no thumbnail has been enlarged and presented as a master. PNG was chosen to retain generated alpha unchanged. No destructive asset cleanup or old-path replacement was performed.

| Runtime path | Actual pixels | Alpha | Intended maximum logical use | Status / appearance observations |
| --- | --- | --- | --- | --- |
| `personas/karen_portrait.png` | 1086 × 1448 | RGBA, 0–255 | 160 × 220 portrait, 66 × 88 selector | Blonde bob, top sunglasses, pink blazer, dark shirt, earrings match; shoulder/hair contours and face shading are reconstructed. |
| `personas/frat_bro_portrait.png` | 1086 × 1448 | RGBA, 0–255 | 160 × 220 portrait, 66 × 88 selector | Blue backward cap, sunglasses and mustard shirt retained; face/shoulders extrapolated from 63 × 66 crop. |
| `personas/politician_portrait.png` | 1086 × 1448 | RGBA, 0–255 | 160 × 220 portrait, 66 × 88 selector | Brown side part, navy suit, white collar and red tie retained; bust details extrapolated from 62 × 66 crop. |
| `personas/grandpa_portrait.png` | 1086 × 1448 | RGBA, 0–255 | 160 × 220 portrait, 66 × 88 selector | Bald crown, side hair, navy glasses, green sweater and white collar match. Bottom has a soft alpha fade, following card reference. |
| `personas/two_year_old_portrait.png` | 1086 × 1448 | RGBA, 0–255 | 160 × 220 portrait, 66 × 88 selector | Orange/brown top tuft, cheerful round face and teal shirt retained; face/shoulders extrapolated from 58 × 66 crop. |
| `weather/sun_grumpy_cloud.png` | 1254 × 1254 | RGBA, 0–255 | 200 × 200 hero | Sun/sunglasses behind grumpy white cloud retained; cloud silhouette and proportions differ slightly. |
| `weather/sunglasses_cloud.png` | 1254 × 1254 | RGBA, 0–255 | 190 × 190 promo | Cloud, sunglasses, pink cheeks and paired face curves retained; caption sticker, sun fragment and yellow background removed. |
| `weather/sun_sunglasses.png` | 1254 × 1254 | RGBA, 0–255 | 90 × 90 template thumbnail | Golden sun, navy sunglasses and smile retained. Rays and dimensional shading reconstructed. |
| `weather/coffee_cloud.png` | 1254 × 1254 | RGBA, 0–255 | 90 × 90 template thumbnail | Grumpy cloud and brown coffee mug retained; steam and mug detail reconstructed. |
| `weather/storm_cloud.png` | 1254 × 1254 | RGBA, 0–255 | 90 × 90 template thumbnail | Slate cloud, yellow lightning and raindrops retained; cloud and lightning proportions reconstructed. |
| `memes/beach_sun_background.png` | 2172 × 724 | RGB, opaque | 350 × 117 featured preview; textless 3:1 document backdrop | Sun at left, beach/palm/ocean scene and open right area retained. All caption/logo text removed. Scene details reconstructed. |

Portrait native resolution supports the listed maximum display slots at 3× pixel density. Weather sources support the listed hero sizes at 3×. These display bounds are asset QA targets; actual responsive widgets may deliberately use smaller sizes. Preserve aspect ratio; do not stretch sprites. The beach source's native aspect ratio is 3:1; larger meme documents must use a deliberate contain/cover policy rather than claiming higher recovered detail.

## Visual evidence

- `artwork/character_comparisons.png`: each native approved crop, enlarged comparison crop, reconstruction on light pink and reconstruction on navy.
- `artwork/weather_comparisons.png`: all weather illustrations and beach background beside the approved crops.
- `artwork/runtime_slot_checks.png`: representative portrait/avatar/hero/template sizes over both light and dark backgrounds. This is an asset QA sheet, **not an application screenshot**.
- `artwork/legacy_asset_audit.png`: prior artwork assessed and rejected for approved identity matching.
- `artwork/build_asset_qa.py`: repeatable read-only image measurement and comparison-sheet generation. It does not alter runtime artwork.

All runtime PNGs were opened visually. No baked UI captions, card borders, neighboring faces, buttons or navigation remain. Only static illustration is included. Meme captions must remain Flutter/editor text layers. Full application screenshot evidence belongs to the separate UI acceptance report.

## Remaining quality issues — not exact/production-approved

Generated RGBA sources show detached colored pixels and ragged bright fringes when inspected at native resolution on a black transparency viewer. These are much less apparent at the representative 1× logical slots on pink/navy shown in the QA sheet, but source quality is not fully clean. Do not treat the presence of an alpha channel as proof of production-ready matting.

Dedicated built-in image edits were attempted on Karen and the hero to remove these speckles/halos while preserving identity. Both returned edge defects; neither was promoted into runtime. The rejected candidates are retained under `artwork/cleanup_candidates/` for evidence. No cleanup success is claimed. Final edge acceptance still requires either successful image-tool matte repair or explicit authorization for a deterministic local alpha-matte cleanup workflow.

The three thumbnail-only faces cannot be exact high-detail recoveries. Their simple collar/shoulder continuation is inferred from visible clothing; no full bodies, new costumes, props or alternate theme identities were invented. Karen and Grandpa also contain unavoidable reconstruction differences in hair contours, facial proportions and shoulder pose. The weather silhouettes are close interpretations with a more polished dimensional finish. The beach scene is a caption-free reconstruction, not a recovered original background.

## Tool mode and prompt record

The built-in image generation tool produced each asset separately with the actual approved crop attached. Each prompt named the crop as identity/composition lock, requested the approved soft dimensional cartoon style, constrained clothing/colors/pose, requested transparency where applicable, and prohibited text/UI. See `artwork/GENERATION_PROMPTS.md` for resumed-run prompts and cleanup instructions. The exact initial Karen/Grandpa generation prompts were not present in the resumed agent context, so they are not invented here; their generated source paths and the explicit cleanup prompts are retained.
