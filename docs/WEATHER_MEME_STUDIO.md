# Weather Meme Studio

The DayMaker Fun section opens an on-device editor at `/fun/meme`; `/meme-generator` remains a compatibility entry. A template creates a complete editable meme immediately. Customize exposes text, stickers, layers, canvas, and weather tools. Drafts, images, and project backups have separate actions and outcomes. No account, new backend, cloud upload, or generated AI request is required by this feature.

## Architecture

The feature lives beneath `lib/features/fun/meme/`. `meme_generator_screen.dart` is the existing route wrapper.

| Component | Responsibility |
| --- | --- |
| `meme_catalog.dart` | Validate and load the two bundled starter catalogs; create initial caption layers in safe text zones; resolve persona seed IDs through `RoastPersonas`. |
| `models/meme_document.dart` | Immutable version 2 document, normalized geometry, ordered typed layers, background/photo transforms, frozen weather, schema validation, version 1 migration, and safe asset references. |
| `meme_editor_controller.dart` | Provider-compatible `ChangeNotifier`, selection, edits, logical undo/redo, caption roles, style changes, and layout reflow. |
| `rendering/meme_renderer.dart` | Shared Flutter canvas painting for preview and PNG export, local fonts, image decoding, text fitting, and export overflow/missing-asset checks. |
| `meme_weather.dart` | Read cached weather, freeze units/observation/timezone, expose optional tokens, and retain the exact displayed roast snapshot. It does not fetch weather or regenerate a roast. |
| `meme_suggestions.dart` | Select intact, template-compatible joke pairs using weather/persona context and recent IDs. Manual selection remains available without weather. |
| `storage/` | Serialized local record/media writes, durable native files or browser IndexedDB, favorites/recents, project backup import/export, and media ownership. |
| `platform/` | Safe raster import, gallery/camera/lost-picker recovery, web drop handling, PNG saving, platform sharing, and browser downloads. |
| `widgets/` | Template library, editable canvas interaction, responsive inspector, and export-ready preview. |
| `meme_studio.dart` | Compose the workflow, autosave, source chooser, local weather updates, and navigation. |

The canonical canvas width is 1080. Square and two-panel outputs are 1080×1080; portrait is 1080×1350; story is 1080×1920. Layer rectangles are fractions of the document dimensions, rotation is in radians, and font/stroke sizes are fractions of document width. Preview resizing never rewrites those values. Layout changes use a confirmed fit/reflow operation; the original artwork stays centered. Two-panel layouts confine the original captions to separate columns and repeat the selected illustration in the two panels.

Text, sticker, image, shape, and weather-badge layers carry stable IDs. The original caption layers additionally carry `role: top` or `role: bottom`, so rerolling after reordering cannot overwrite an unrelated text layer. Duplicating a caption clears its role. Lock/hide/order and photo pan/zoom/rotation/flip/brightness/contrast are persisted. The renderer fits text without ellipsis; export reports captions that still overflow and layers that extend past the canvas.

History holds 100 logical operations. Typing within an 800 ms burst shares a history entry; a gesture groups updates until completion. History contains only immutable document values and asset references. `markSaved(document: savedSnapshot)` acknowledges precisely the snapshot that finished writing, preserving the dirty state of subsequent edits.

Reopened drafts, remixes, and imported backups require confirmation before replacing their existing captions, even before the first edit of the current session. Caption-pair replacement is atomic: if either original caption is locked, the action leaves both captions, caption identity, persona, and weather unchanged and asks the user to unlock the caption layers. This also protects exact Current Roast transfers from silently leaving an older locked punchline in place.

## Bundled artwork and writing

The supplied pack contributes 15 text-free 1080×1080 WebP backgrounds, 15 288×288 WebP thumbnails, and 24 transparent 512×512 PNG stickers. Runtime directories are registered in `pubspec.yaml`. The catalogs in `assets/meme_content/` preserve all 90 template pairs and 50 persona pairs, for 140 complete pairs. Flattened captioned example images are reference material and are not bundled as backgrounds.

Stable template IDs are:

```text
storm_boss_cat              tiny_umbrella_big_storm
forecast_betrayal           sun_is_personal
wind_left_the_chat          fog_buffering
forecast_roulette          snow_day_victory
humidity_volume            cloud_side_eye
sidewalk_preheating         monday_drizzle
rainbow_plot_twist          pollen_boss_battle
temperature_whiplash
```

`docs/meme-assets/source_svg/` preserves the 39 original vector sources. [Asset provenance](meme-assets/ASSET_PROVENANCE.md) and [caption reference](meme-assets/CAPTION_CATALOG.md) accompany them. The illustrations are explicitly identified as replaceable original placeholders. Replacing a background at the same catalog path and retaining its template ID preserves saved document identity.

`MemeSans` is locally bundled Nunito; `MemeMono` is locally bundled Space Mono Bold. The licenses are retained beside the fonts in `assets/fonts/`. The catalog alias `meme_sans_bold` resolves to `MemeSans`; no runtime font download is required. Epic, Cute, Sarcastic, Cozy, and Retro change font/weight, fill, outline, shadow, or pill styling independently of the speaking persona.

To add content, provide a text-free background and thumbnail, a unique template ID, two safe-text rectangles, a focal point, a default caption ID, and complete paired captions. Keep IDs globally unique and preserve each setup/punchline pair. Add stickers with unique IDs and transparent raster artwork; retain source files and provenance. Update catalog hashes when artwork changes. Run the catalog/asset tests and visually inspect the new content. All actual captions, weather values, and branding remain Flutter-rendered.

Personas retain the app's canonical `karen`, `frat_bro`, `politician`, `grandpa`, and `two_year_old` IDs. Pollen, rainbow, temperature-whiplash, and snow concepts require appropriate observed signals for automatic selection. Broad secondary tags must not be treated as evidence for an event. They remain manually selectable.

## Weather and privacy

Make One for Today reads available cached weather. The snapshot records the actual observation timestamp, display units, source/stale status, and location timezone/offset when supplied. Missing values stay absent. Editing, rerolling, saving, and exporting do not refresh weather or call an LLM. The user can explicitly update the snapshot. Exact displayed roast text and persona are passed from Forecast/Roasts; a chooser identifies the source when needed, including sample content.

City is opt-in. Coordinates and arbitrary metadata are rejected when importing a document's weather snapshot. The renderer handles optional weather-badge attribution separately from user layers. Existing weather retrieval and other app-wide activity remain separate from meme creation.

Photos stay in local storage. PNG/JPEG/WebP signatures and encoded dimensions are checked before full decode. Input is limited to 20 MB and 40 million pixels, then normalized to a PNG with a maximum edge of 2048 pixels; exported rasters do not preserve original EXIF/GPS metadata. SVG, HTML, corrupt images, and oversized input are rejected. Android lost-picker recovery creates recovered photo drafts instead of relying on temporary picker paths.

## Persistence and portable backups

Native records live under the application-support `daymaker_meme_studio/` directory, with separate `documents`, `media`, and `metadata` collections. A write flushes a `.pending` record and renames it into place. The store serializes writes and rejects an older timestamp replacing a newer saved document. Browser storage uses IndexedDB database `daymaker_memes_v1` with the same three collections; it does not put document/image blobs in preferences or localStorage.

Autosave uses a short debounce and also attempts a lifecycle flush. Corrupt projects are retained for recovery and do not wipe unrelated projects. Media is content-addressed and referenced as `media:<id>`. Garbage collection considers all saved projects and active undo/redo references; an unreadable saved project prevents potentially unsafe collection. User projects are not cache-evicted. Recent-export metadata and temporary native share copies are bounded separately.

A portable backup is a JSON file with format `daymaker-meme-project`, backup version 1, the versioned document, and embedded base64 media. Base64 is confined to this user-requested transport format. The limit is 64 MB. Import validates schema, IDs/path safety, exact media ownership, byte limits, decoded content, and every embedded image before saving a new imported copy. It does not overwrite the original project. Keep backups somewhere outside the app before clearing storage or uninstalling.

Browser storage is origin-specific and can be cleared or evicted. This change does not add a custom offline app shell/service worker or guarantee a cold offline web launch. After the application, fonts, and selected assets have loaded, local editing/export can continue without weather requests; a template whose asset has not loaded still needs that asset to be available from the browser/server cache. Native artwork and fonts are bundled for initial offline use. Actual offline browser behavior must be tested against the hosting/cache configuration used for release.

## Export and sharing

PNG is rendered from the same document painter used by preview at deterministic dimensions, after image/font preparation. It excludes selection outlines, gestures, guides, and controls. The export preview has separate Save Image, Share, Save Project Backup, and Continue Editing actions. Photos/MediaStore saving uses `gal` on mobile; denied access points the user to the file/share alternative. `share_plus` invokes the native share sheet and receives the button's iPad popover origin. Temporary native handoff copies are retained in a bounded cache.

Portable backup preparation runs independently after the PNG preview opens. A backup size/storage failure leaves PNG saving and sharing usable and exposes Retry Project Backup. A ready backup is saved from a fresh tap. If local export-history metadata cannot be written after a completed save/share, the preview preserves the platform result and shows a separate history warning.

The browser prepares PNG bytes before the next user Share tap, feature-detects file sharing, and otherwise requests a real browser download. Cancellation, denied permissions, unavailable status, and failures have distinct messages; a download request does not claim that the browser finished writing the file or that a meme was posted.

## Verification commands

Use the repository's installed compatible Flutter SDK and locked dependencies:

```sh
dart format lib/features/fun/meme lib/features/fun/meme_generator_screen.dart test/meme*_test.dart
flutter analyze
flutter test
flutter test test/meme_domain_test.dart test/meme_weather_test.dart test/meme_storage_test.dart test/meme_platform_test.dart test/meme_rendering_test.dart test/meme_export_preview_test.dart
flutter test --platform chrome test/meme_platform_web_test.dart
flutter build web --release
flutter build apk --debug
flutter build ios --simulator --debug
```

The domain tests decode every runtime asset, check dimensions/transparent sticker corners and original hashes, verify 140 pairs/defaults/persona mapping, and exercise serialization, migration, invalid data, media references, history grouping, layout reflow, and save acknowledgments. Weather, persistence, adapter, rendering, and widget tests exercise their separate boundaries. Compilation alone does not validate a real device's Photos permission flow, native share sheet, camera, iPad positioning, or web storage retention.

Integration verification results, screenshots, and example exports are recorded separately in the implementation handoff. Do not interpret this command list or the starter pack's `VALIDATION_REPORT.json` as a claim that an unexecuted platform passed. Device/browser execution should include 320/390/430/768/1280 widths, text scaling, reduced motion, keyboard/resize behavior, an imported-photo restart, an exhausted caption deck, all artwork, and square/portrait/story/two-panel export inspection.
