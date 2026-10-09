# Approved characters and artwork production

## Identity lock

The owner's last instruction is to use the characters **in the approved designs**. This replaces the earlier request to keep the app's old artwork. Keep the canonical storage IDs below; do not introduce a second persona model to achieve a visual update.

| ID | Approved visible identity | Available reference |
|---|---|---|
| `karen` | Blonde bob/shoulder-length hair, sunglasses on top of her head, pink blazer, dark top, small gold earrings, warm confident cartoon face | Large home-card portrait plus selector thumbnail |
| `frat_bro` | Light-blue backward cap, dark sunglasses, mustard/yellow shirt, friendly overconfident grin | Selector thumbnail only |
| `politician` | Neat side-parted brown hair, navy jacket, white shirt and red tie, polished friendly cartoon face | Selector thumbnail only |
| `grandpa` | Bald crown, white hair at sides, dark rounded glasses, white collar, green sweater, friendly smile | Large Roasts card portrait plus selector thumbnail |
| `two_year_old` | Small orange/brown top tuft, teal shirt, round cheeks, cheerful toddler expression | Selector thumbnail only |

Canonical order in the selector: Karen, Frat Bro, Politician, Grandpa, 2-Year-Old. Keep display labels separate from IDs and aliases. This display ordering is allowed to differ from the original enum/list order. Preserve all ID normalization and stored-selection compatibility.

The older app's personality voices remain appropriate, but old visual badges need a display mapping. In the reference, Karen is ROAST QUEEN; the Grandpa card says WEATHER WISEGUY. Do not rename `grandpa` or erase existing earned data just to show this subtitle.

## Actual source limitations

The two source boards are each 1448 × 1086 pixels. The entire cast row occupies only a small part of a board. The individual native-resolution thumbnail crops are roughly 55–65 pixels wide. They are not high-density avatar masters. Portrait-context crops may include the background gradient and nearby UI. None has a clean guaranteed alpha channel or missing-body information.

The package deliberately does not call these crops production sprites, does not invent clean vectors, and does not magnify them and call that recovered detail. Compare them at native size in the gallery.

## Asset-production pass to execute in Codex

First inspect this package and the project-owned image folders available in the selected repository/workspace for larger matching originals. Search narrow task-relevant directories; do not sweep unrelated personal photos. Reuse an actual larger match only after comparing it visually against this reference.

When no match exists, create new static assets using the exact reference as a visual guide. Use an available approved image-editing/generation capability when available. Do not assume a particular image API/key, paid tool, browser plugin, or an active Adobe session. Do not purchase access, upload private unrelated images, or install global software without necessary approval. Local raster extraction can support development, but cannot recover detail hidden or absent in the source.

A reconstruction must match face shape, hair, skin, glasses, clothing colors, pose, and soft dimensional shading. Do not use freehand basic geometric SVG people as a shortcut. Produce a contact sheet with the reference next to each candidate. Record whether each item is original, extracted, or reconstructed. A materially different face is an unresolved asset issue, not a harmless implementation detail.

For Karen and Grandpa, create a transparent bust matching the larger approved card portrait. For Frat Bro, Politician, and the toddler, initially use a portrait/bust composition based on the approved thumbnail; do not invent full-body outfits, new props, or costumes. Any extrapolated body detail should be identified in the asset report.

## Required runtime assets (proposed paths, not files supplied by this kit)

```
assets/daymaker_v2/personas/karen_portrait.webp
assets/daymaker_v2/personas/frat_bro_portrait.webp
assets/daymaker_v2/personas/politician_portrait.webp
assets/daymaker_v2/personas/grandpa_portrait.webp
assets/daymaker_v2/personas/two_year_old_portrait.webp
assets/daymaker_v2/weather/sun_grumpy_cloud.webp
assets/daymaker_v2/weather/sunglasses_cloud.webp
assets/daymaker_v2/weather/sun_sunglasses.webp
assets/daymaker_v2/weather/coffee_cloud.webp
assets/daymaker_v2/weather/storm_cloud.webp
assets/daymaker_v2/memes/beach_sun_background.webp
```

These are target names for Codex to create/integrate, not a claim they already exist in this package. Names may be mapped through the existing typed `DmAssets` registry without breaking callers.

Aim for at least 768 × 1024 portrait source masters and optimized 1x/2x/3x outputs sufficient for the actual maximum slot. Small selector images can use separate face crops of those masters. Weather art should have sufficient resolution for a ~200 logical-pixel hero at high device pixel ratios. Raster compression must not introduce colored halos around alpha edges. Keep aspect ratio and use `BoxFit.contain` or a deliberate documented face crop.

Both themes use the same face/portrait source. Put pink, mint, or blue portrait backdrops in Flutter containers. Never select the dark board's slightly altered generated faces as separate theme-specific identities.

## Weather illustrations and meme art

Match the approved rounded, softly shaded sun/cloud style rather than flat emoji. Today uses a white grumpy cloud in front of a yellow sun wearing sunglasses. The Fun hero uses a cloud in sunglasses. Quick templates show a sun in sunglasses, a cloud with coffee, and a storm cloud with lightning.

The small novelty weather illustration is not the meteorological data source. Real condition icons must be condition-aware and independent of theme brightness. Preserve the existing animated weather-icon mapping where it is useful, but make its styling fit the approved UI.

The promotional phrase GOOD WEATHER BAD DECISIONS can be rendered as layered text/sticker content, not fused into the reusable cloud art. For the featured beach meme, use clean background art plus editable text layers. Do not promote a low-resolution already-captioned screenshot into an editable meme template.

Suggested non-sensitive captions from the approved design:

- Current mood: “Same forecast. Different attitude.”
- Monday energy: “Cloudy with a chance of caffeine.”
- This weather…: “Looks serious. Just like my snacks.”
- Featured meme: “FORECAST: 100% CHANCE OF NO CHILL.”

These are entertainment copy, not actual forecasts. Avoid unlicensed internet meme templates or third-party character cameos from older alternate boards.

## Production acceptance

Every asset requires a source/provenance record, actual dimensions, alpha status, appearance comparison, intended max display size, and final integrated path. No embedded button labels, ghost text, card edges, neighbor portraits, or screenshot navigation may remain in reusable artwork.

Development placeholders are allowed so functional work can continue. Mark them in `ASSET_STATUS.md` and preview builds, and do not present them as final production artwork. When only asset reconstruction is blocked, continue the remaining UI work and report the exact missing items; do not silently revert to the old characters or claim exact visual completion.
