# DayMaker Asset Manifest

The canonical production asset manifest now lives at [`../ASSET_MANIFEST.md`](../ASSET_MANIFEST.md).

Use that file as the source of truth for:

- Required asset paths.
- Screen usage.
- Format.
- Expected dimensions.
- Transparent background requirements.

The app is expected to run before final art ships. Generated assets should be added at the exact manifest paths and loaded through the fallback-aware `DmAssetImage` or `DmSvgIcon` wrappers.
