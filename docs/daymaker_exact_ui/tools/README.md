# Local verification tools

`validate_package.py` uses the Python standard library and checks package checksums, JSON, original-image hashes and PNG/crop metadata. It does not validate a Flutter application.

`compare_screenshots.py` uses Pillow. Use a project-local Python environment if needed. It writes a side-by-side image, 50% overlay, raw difference, amplified difference, and a diagnostic JSON report. Inputs remain untouched.

Example after implementing and capturing actual Flutter UI:

```sh
python tools/compare_screenshots.py \
  --reference aligned_reference_card.png \
  --candidate aligned_flutter_card.png \
  --output ../../ui_implementation/comparisons/today-card-light
```

Optional `--reference-box x,y,right,bottom` and `--candidate-box ...` crop equivalent regions. Use `--scale-candidate` only for uniform pixel-density normalization. The script rejects unequal aspect ratios to avoid hiding layout errors with non-uniform stretching. Coordinates are image pixels, not Flutter logical pixels.

Normalize state, text scale, font availability and viewport context before comparisons. App-focused reference crops still contain generated raster text and slight source-image inaccuracies. For theme parity, use identical actual Flutter state/layout in both themes; the canonical Light reference controls geometry. The tool does not assign a PASS/FAIL fidelity percentage. Review differences visually, then establish real deterministic Flutter goldens for regression testing.

Do not put a comparison of a concept image against itself in the app's acceptance evidence. That only tests the comparison tool, not the app.
