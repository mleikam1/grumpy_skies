# Weather Meme Studio content

The supplied starter illustrations remain original, replaceable placeholder artwork. Their runtime files are deliberately separate from the flattened captioned examples, which are not bundled. `ASSET_PROVENANCE.md` records origin and usage; `source_svg/` preserves all 39 editable originals. `CAPTION_CATALOG.md` is the readable writing reference. `VALIDATION_REPORT.json` is the supplied pack's report, not a claim about the integrated app.

Runtime assets live in `assets/meme_backgrounds/`, `assets/meme_thumbnails/`, `assets/meme_stickers/`, and `assets/meme_content/`. The two JSON catalogs retain 15 stable template IDs, 24 sticker IDs, and all 140 complete caption pairs. Their original schema is shipped beside them. Flutter renders every caption, weather value, and watermark separately. Replacing an illustration at its existing path preserves saved project identity.

To author a template, add a text-free 1080×1080 WebP background and 288×288 thumbnail, add a unique catalog entry with top and bottom normalized safe-text rectangles, and supply whole joke pairs with globally unique IDs. Keep the original SVG and provenance. Tag weather topics accurately. Unsupported events such as pollen, rainbows, and temperature whiplash require verified observations before automatic suggestions; users can always select them manually. Never relabel a captioned reference image as a background.

The `meme_sans_bold` catalog alias resolves to the locally bundled `MemeSans` font. Editor size, position, stroke, and line height remain explicit Flutter values. Persona seed IDs are normalized through the app's `RoastPersonas` registry without changing its persisted IDs.

`MemeDocument` schema version 2 stores normalized geometry, ordered immutable typed layers, a background, local media references, style, and optional frozen weather. Version 1 documents migrate without discarding content. Unknown versions are rejected with a recovery message; unknown/missing artwork remains an identifiable reference for recovery. Imported images use `media:<id>`, never temporary paths or external URLs. Binary pixels do not enter JSON or undo history.

The controller groups a gesture or typing burst into one undoable change and retains 100 operations. `markSaved(document: savedSnapshot)` acknowledges an asynchronous save without marking newer edits saved. Its `mediaIds` includes active history, which the storage layer must retain during garbage collection.

Run `flutter test test/meme_domain_test.dart` to check catalog counts and defaults, all 54 runtime image decodes and dimensions, original asset hashes, canonical persona IDs, document migration/validation, logical history, reflow, and media ownership.
