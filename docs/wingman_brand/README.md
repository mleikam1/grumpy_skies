# Approved Wingman Weather branding

`source/winged_sun_weather_app_icon.png` is the unmodified user attachment,
originally named `Winged Sun Weather App Icon.png` on this Mac. Its SHA-256 is
`e79dafc98b7a9802c3259264bef771c26e4bfeab8d78b0fb9c28ca6bbc773bd0`.
It is kept outside the Flutter runtime bundle.

Run `python3 tools/prepare_wingman_brand.py` with Pillow installed. The installed
Codex bundled interpreter also provides Pillow. No Flutter dependency was added.
The repository had existing native icon/launch slots but no icon-generation
configuration; this deterministic script regenerates those same slots.

The script identifies only the blue outer boundary on the verified tile rows,
fills the entire interior span, makes the exterior transparent, and crops to
`(207, 196, 1048, 1024)`. It never keys out white, so the W and icy highlights
remain intact. All 660,472 retained RGB pixels are compared byte-for-byte with
the source. The derivative is 841 × 828 with transparent corners. The checked-in
JSON records these assertions. There is no generated/recreated artwork,
recoloring, tracing, animation, stretching, or baked-in wordmark.

`WingmanLogo` uses `BoxFit.contain`, the exact asset, and the accessible name
“Wingman Weather.” The main shared header puts the exact line “Whatever the
weather, we’ve got your back.” directly below its 48-pixel logo in normal
scaling caption typography. Existing titled subheaders retain their titles and
back behavior. Splash and About use the separate general tagline.

The existing iOS icon slots use opaque navy outside the tile as required by
the launcher. Android's existing legacy launcher slots preserve transparent
corners. PWA standard icons keep transparency; maskable icons use a navy field
and a 76% tile so the complete symbol survives circular masks. Native launch
images use the same transparent tile at 168 logical pixels. Pixel-mask review
was captured for iOS-style rounded corners, Android legacy, and PWA circular and
rounded crops. Actual device launcher verification remains a separate check.

Bundle/application IDs, backend URLs, signing, store identities, and permission
behavior are unchanged. No localization catalogs existed in this checkout.
English app-owned display strings and permission explanations were updated;
third-party attribution and stable storage names were left intact.

Persona image folders, roast packs, and roast/reveal backgrounds are no longer
declared in `pubspec.yaml`. Retired registry entries were removed. Weather art
and all creative-tool catalogs/art remain bundled. Saved meme documents have
always rejected persona-image asset paths, so persona portraits do not need a
compatibility bundle; legacy caption text/provenance is handled by the document
decoder without resurfacing a persona selector.

Focused verification: `test/wingman_brand_test.dart` checks the exact sentence,
logo accessibility, unclipped wrapping at 320/390/768 logical pixels and 1×/2×
text in both themes, settings navigation, and titled-header back navigation.
`test/about_screen_test.dart` retains About content and back checks.
`test/asset_manifest_test.dart` checks the active registered/catalog asset set.
Set `WINGMAN_BRAND_CAPTURE_ROOT` to write new screenshots without replacing
historical baselines.
