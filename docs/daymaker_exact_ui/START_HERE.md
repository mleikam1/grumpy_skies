# DayMaker — approved light + dark UI build kit

**This is the replacement handoff for the final approved designs.** It is not the earlier `daymaker_ui_handoff` concept package. Do not mix the earlier illustrations or the first, different Frat Bro dark-mode board into this build.

## Owner's final decision

Build the existing Flutter app at `mleikam1/grumpy_skies` to match the enclosed light-mode design, with the **same layout in dark mode**. Use the **characters pictured in these designs**, not the older character appearances in the app. Keep the underlying persona IDs and saved preferences.

## Give this to Codex

1. Extract the ZIP. Put this `daymaker_exact_ui` folder in the selected repository at `docs/daymaker_exact_ui/`, or leave it in Downloads and tell Codex where it is.
2. Open that existing weather-app checkout in the local Codex workspace.
3. Paste all of `CODEX_MASTER_PROMPT.txt`. Codex performs the implementation and local commands; the owner does not need to manually edit theme variables or copy individual images.

`gallery.html` displays the approved boards, individual screens, and character references. It is an offline reference viewer, **not an interactive app prototype**. All its images are included locally; no server is required.

## Files to read

| File | Role |
|---|---|
| `CODEX_MASTER_PROMPT.txt` | Copy/paste implementation instruction |
| `DESIGN_CONTRACT.md` | Visual authority, strict no-redesign rules, theme parity |
| `SCREEN_SPECIFICATIONS.md` | The three approved screens and the derived remaining app screens |
| `FLUTTER_IMPLEMENTATION_PLAN.md` | Repository integration, persistence, state, routes, phases |
| `CHARACTER_AND_ASSET_BRIEF.md` | New cast identity lock and honest artwork-production requirements |
| `ACCEPTANCE_CHECKLIST.md` | Functional, visual, theme, data, platform, and asset acceptance gates |
| `tokens/daymaker_theme_tokens.json` | Proposed implementation tokens calibrated to the screenshots |
| `fixtures/approved_design_fixture.json` | Synthetic visual-test content, never production weather |
| `references/REFERENCE_MANIFEST.json` | Original image hashes and exact crop provenance |
| `tools/compare_screenshots.py` | Overlay/difference tool for actual app captures |
| `tools/validate_package.py` | Package integrity and manifest checker |
| `SOURCE_NOTES.md` | Rechecked repository facts and official implementation references |
| `PACKAGE_QA.md` | What was and was not validated in this delivery |

## Exactly what is included

Two untouched 1448 × 1086 approved raster boards; 12 individual screen crops (six phone crops and six app-focused crops); 18 UI-component crops; eight character-reference crops; six weather/artwork-reference crops; specifications, fixture data, design tokens, and validation tools. All crops retain native resolution; none is claimed to contain newly recovered high-resolution detail.

## Important distinction

The board images are flattened generated mockups, not layered Figma/PSD files. They do not include the original font metrics, separate transparent character illustrations, or complete portraits of every persona. The smaller cast members are visible mainly as thumbnail portraits. Crops are useful visual references, not automatically production-ready cutouts.

Codex must implement real Flutter layout and controls, then produce/locate appropriate artwork guided by these exact references. Full-screen screenshot-as-UI, recoloring the old app without rebuilding the approved layout, or passing low-resolution screenshot fragments off as final high-density assets does not meet acceptance.

The approved visual scope is Today, Roasts, and Fun in both themes. Radar, Settings, the editor, onboarding, and other unpictured screens have complete implementation requirements here, but are **derived extensions**, not separately approved pixel references. Preserve their functionality and carry over the same design system.

No app code, cloud configuration, repo branches, or production data were changed by creating this package. No font files are distributed in this package.
