# Approved artwork status

Current follow-up: **all 50 persona emotion assets are complete**. See [the emotion expansion ledger](#persona-emotion-expansion--october-9-2026) below for every file, dimension, source and remaining alpha limitation. The original 11-asset milestone remains documented first for provenance.

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

## Persona emotion expansion — October 9, 2026

Added **50 separate emotion portraits**, ten for each of Karen, Frat Bro, Politician, Grandpa, and 2-Year-Old. Each selected image was generated independently with the built-in `image_gen` identity-preserving edit workflow. No old portrait was copied repeatedly under different mood names. Existing `assets/approved_v1/` and legacy persona files remain unchanged.

All five personas support `happy`, `excited`, `hyped`, `cozy`, `complaining`, `annoyed`, `sad`, `worried`, `confident`, and `neutral`. Stable runtime paths are `assets/personas/{persona}/{mood}.png`. There are no missing requested mood files and no image fallback substitutions in this inventory.

All 50 native PNGs are **1086 × 1448 RGBA**, with alpha spanning 0–255. They total **62,955,894 bytes (60.039 MiB)** before platform packaging. All 50 have distinct SHA-256 hashes, and every runtime file matches its selected generated source byte-for-byte. Native sources were retained; no tiny reference crop was enlarged and shipped as a master.

The existing reconstructed approved portraits and native approved crops were visually inspected and supplied as identity references. Four specific user-supplied emotion cards additionally guide Karen complaining (crossed arms), Frat Bro hyped (two thumbs up and palm shirt emblem), Grandpa cozy (closed eyes and a plain mug), and 2-Year-Old excited (yellow raincoat and boots, arms raised). Copies of those cards are in `artwork/emotions/references/`. The other variants preserve the original bust clothing. The excited toddler intentionally uses the supplied full-body pose; preserve its aspect ratio and use contain layout.

Frat Bro cozy received one targeted revision after comparison showed its first face was too close to happy. The selected image has a calm tilted head and smaller contented smile. The earlier source and prompt remain in the generation history.

### Per-file inventory and sources

Every row below is a newly created expression edit. Source identifiers name the actual built-in generated PNG. Complete source paths, exact prompts, input references, native measurements, per-image byte counts and hashes are in `artwork/emotions/emotion_asset_metadata.json`. Raw generation history is retained in the four `*_manifest.jsonl` files; the last record for a persona/mood is the selected output.

| Runtime file | Native pixels | Generated source PNG |
| --- | --- | --- |
| `assets/personas/karen/happy.png` | 1086 × 1448 | `exec-d62b59f5-6fc6-4561-8dfb-c48bf5681197.png` |
| `assets/personas/karen/excited.png` | 1086 × 1448 | `exec-bb5520dd-7b81-4676-9cd6-3787205b213e.png` |
| `assets/personas/karen/hyped.png` | 1086 × 1448 | `exec-02f91926-0819-4182-bb4c-7a598293375a.png` |
| `assets/personas/karen/cozy.png` | 1086 × 1448 | `exec-15e1e4f7-c358-4fdc-991b-5a75215a20f5.png` |
| `assets/personas/karen/complaining.png` | 1086 × 1448 | `exec-1cacc81f-62bd-4278-b161-575854936006.png` |
| `assets/personas/karen/annoyed.png` | 1086 × 1448 | `exec-361e70e2-c89b-4984-abee-ac33905b8ec6.png` |
| `assets/personas/karen/sad.png` | 1086 × 1448 | `exec-d56ce67b-cad5-4071-9263-0d7337929c03.png` |
| `assets/personas/karen/worried.png` | 1086 × 1448 | `exec-7bed21f7-9ede-4884-bca8-392b79261b15.png` |
| `assets/personas/karen/confident.png` | 1086 × 1448 | `exec-e87f0254-a569-41d1-9ac2-d2ace7a451bc.png` |
| `assets/personas/karen/neutral.png` | 1086 × 1448 | `exec-96da007d-f9cc-46ea-bbdb-b2ef7621eab5.png` |
| `assets/personas/frat_bro/happy.png` | 1086 × 1448 | `exec-234bbc2f-0f07-4488-a0f2-a393b7265b22.png` |
| `assets/personas/frat_bro/excited.png` | 1086 × 1448 | `exec-1ebff9fd-107b-4ad6-861f-980737247da7.png` |
| `assets/personas/frat_bro/hyped.png` | 1086 × 1448 | `exec-8f0483a7-fefe-4661-864f-30e484cc138c.png` |
| `assets/personas/frat_bro/cozy.png` | 1086 × 1448 | `exec-78321b8a-e6d2-484a-be56-7827cba9e684.png` |
| `assets/personas/frat_bro/complaining.png` | 1086 × 1448 | `exec-ac4a1b34-5527-4d3b-bdfe-b143fe513974.png` |
| `assets/personas/frat_bro/annoyed.png` | 1086 × 1448 | `exec-ee0a008b-1578-469f-858c-3ffe867274c8.png` |
| `assets/personas/frat_bro/sad.png` | 1086 × 1448 | `exec-6bcacde3-86ca-426f-956c-6494394899c9.png` |
| `assets/personas/frat_bro/worried.png` | 1086 × 1448 | `exec-e30a7a38-25a4-40b7-a448-4fc25c67e8cf.png` |
| `assets/personas/frat_bro/confident.png` | 1086 × 1448 | `exec-60b3b770-67ab-453c-9bad-daa8259b522f.png` |
| `assets/personas/frat_bro/neutral.png` | 1086 × 1448 | `exec-7a244f88-ce53-4769-a9d7-5c3b9730073e.png` |
| `assets/personas/politician/happy.png` | 1086 × 1448 | `exec-18d1c931-5ab4-41a1-aec5-ffff64837980.png` |
| `assets/personas/politician/excited.png` | 1086 × 1448 | `exec-7abeeacd-f101-43d0-8a3d-58c9a178fc8b.png` |
| `assets/personas/politician/hyped.png` | 1086 × 1448 | `exec-1634e753-8a6b-495b-854e-ab036b0c9d97.png` |
| `assets/personas/politician/cozy.png` | 1086 × 1448 | `exec-7b3428fb-d943-4fd4-b07e-e208f67294a9.png` |
| `assets/personas/politician/complaining.png` | 1086 × 1448 | `exec-f575a8a9-793a-405e-b973-929bf2403372.png` |
| `assets/personas/politician/annoyed.png` | 1086 × 1448 | `exec-7ff02cd8-3ae6-46cc-849a-4890b3f83b6c.png` |
| `assets/personas/politician/sad.png` | 1086 × 1448 | `exec-c2ade29f-c869-44a9-9e60-a589aa261cc5.png` |
| `assets/personas/politician/worried.png` | 1086 × 1448 | `exec-010dcaf1-909a-4f47-b8ae-9706143e6297.png` |
| `assets/personas/politician/confident.png` | 1086 × 1448 | `exec-35d99bee-284c-45a3-b84b-a0a1be6269c2.png` |
| `assets/personas/politician/neutral.png` | 1086 × 1448 | `exec-0577a482-fb1c-471d-8efb-00190e48b356.png` |
| `assets/personas/grandpa/happy.png` | 1086 × 1448 | `exec-4055cef7-6308-4880-bdca-ebc7744627e4.png` |
| `assets/personas/grandpa/excited.png` | 1086 × 1448 | `exec-e8179441-f6c9-47fa-a097-07365ed004e8.png` |
| `assets/personas/grandpa/hyped.png` | 1086 × 1448 | `exec-5c1a127e-23cd-4c83-9965-0ea726371402.png` |
| `assets/personas/grandpa/cozy.png` | 1086 × 1448 | `exec-91c816d1-ac93-4332-9cd0-f661d2ce7fac.png` |
| `assets/personas/grandpa/complaining.png` | 1086 × 1448 | `exec-d2322fe2-79a1-4a7a-8e50-1d9a30773fd1.png` |
| `assets/personas/grandpa/annoyed.png` | 1086 × 1448 | `exec-7a257273-2fc6-4585-b0d5-73c298670d88.png` |
| `assets/personas/grandpa/sad.png` | 1086 × 1448 | `exec-282f9287-7db8-4c38-b863-a6c4e2f45cf9.png` |
| `assets/personas/grandpa/worried.png` | 1086 × 1448 | `exec-5d4d291a-4d44-45fa-8eff-43af1d7050d0.png` |
| `assets/personas/grandpa/confident.png` | 1086 × 1448 | `exec-0b2831ae-da79-4854-bf9b-1b8bc2bb3687.png` |
| `assets/personas/grandpa/neutral.png` | 1086 × 1448 | `exec-431282d8-89ed-4917-ac12-66553b0a4b75.png` |
| `assets/personas/two_year_old/happy.png` | 1086 × 1448 | `exec-7c4cffc1-44bd-4b3c-8c5e-c3988160b553.png` |
| `assets/personas/two_year_old/excited.png` | 1086 × 1448 | `exec-fcf22799-3a46-462b-9222-60b5b75638aa.png` |
| `assets/personas/two_year_old/hyped.png` | 1086 × 1448 | `exec-19bf82f3-6c6e-45e4-b4a6-1466f76a75f8.png` |
| `assets/personas/two_year_old/cozy.png` | 1086 × 1448 | `exec-cd5ec10a-d5db-4178-98b3-f4c9d73a868d.png` |
| `assets/personas/two_year_old/complaining.png` | 1086 × 1448 | `exec-87f98d10-c1a0-474f-a136-b3f0c8e49291.png` |
| `assets/personas/two_year_old/annoyed.png` | 1086 × 1448 | `exec-f40f6bac-b430-4720-8bd9-47037df17dd7.png` |
| `assets/personas/two_year_old/sad.png` | 1086 × 1448 | `exec-28fd4514-a0e8-4ae0-8b18-9d2d1c67a094.png` |
| `assets/personas/two_year_old/worried.png` | 1086 × 1448 | `exec-7af71c8c-c438-43e7-85c6-8f1348fce02d.png` |
| `assets/personas/two_year_old/confident.png` | 1086 × 1448 | `exec-58417fc1-e931-41e4-a6fc-36451ac75d1c.png` |
| `assets/personas/two_year_old/neutral.png` | 1086 × 1448 | `exec-78797517-919e-4dab-a8ab-f5f26847dca7.png` |

### Emotion quality review and remaining limitations

All selected images were opened individually and reviewed for expression, recognizable identity, costume, framing and transparency. The five `artwork/emotions/{persona}_light_dark.png` sheets were then visually checked at 128 × 171 pixel portrait slots on both light and dark backgrounds. They show actual generated assets, not application screenshots. Mood differences remain visible at these sizes; Frat Bro relies on eyebrow, mouth and head/gesture cues because his approved sunglasses cover the eyes.

**Native alpha matting is not flawless.** The tool continues to produce minor detached colored pixels and bright/color fringes, despite explicit clean-edge instructions. These are visible at native resolution and much less apparent at the checked card sizes. Toddler shirt-bottom cyan and Karen pink/white edges are the most noticeable source defects. They have not been hidden by a local cleanup or falsely labeled production-approved. The new images preserve generated alpha unchanged. Further source-edge cleanup remains a polish item; no missing emotion or incorrect-identity blocker was found.

`artwork/emotions/build_emotion_qa.py` reads runtime assets and writes measurement/comparison evidence only. It never modifies runtime pixels or alpha. `artwork/emotions/verification.json` records 50 expected/50 actual, no missing files, unique hashes, RGBA/alpha checks, provenance completeness and source-byte equality. These mechanical checks complement visual review; they do not prove clean matting.
