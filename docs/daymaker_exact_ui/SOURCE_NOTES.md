# Source notes and evidence limits

## Approved image provenance

The owner selected the provided light-mode board and then requested the identical composition in dark mode. This package preserves those two files byte-for-byte under `references/approved/`. Their SHA-256 hashes, dimensions and all crop rectangles are in `references/REFERENCE_MANIFEST.json`.

The owner subsequently explicitly chose the characters in the designs rather than the older character artwork in the current app. This is the visual identity decision used throughout this package. Earlier visual proposals and the first different-layout Dark board are intentionally omitted.

There are no hidden Figma layers, Photoshop documents or original character master illustrations available in these PNGs. Typography, logical spacing, theme colors and production asset dimensions specified here are implementation proposals inferred from the images. Only the PNG pixels and crop rectangles are exact source measurements.

## Remote files rechecked during packaging

The GitHub connector returned current default-branch contents for the following files. The branch metadata returned main `d984b2812da8b7d873abcf4b4464be1e07d93e2c`, with the earlier reviewed UI commit `bedddc8ebe68e681db4d3e6d842683c430eba8af` as its parent. This was a selected-file code inspection, not a new running-device audit of the entire app. The local checkout may be newer/different.

| File | Returned file blob SHA | Relevant observation |
|---|---|---|
| `AGENTS.md` | `90211b55f34c7cdfbc3a7d323c5c58c75cf4f281` | Real Flutter UI/dynamic text, adaptive architecture and reading existing style documents are required. |
| `lib/main.dart` | `0314f767e1d3acfc9bc256496492c30b73be3cac` | Existing repository/cache/controller/monetization wiring should be preserved. |
| `lib/design/dm_theme.dart` | `d79ec5a39c77319305cd2c025da33e171962c8ed` | Light and Dark getters return the same dark ThemeData. |
| `lib/app/daymaker_app.dart` | `5513d8563361b3e112466322950e6d7bfdffd266` | MaterialApp.router has only theme, not a complete dual-theme preference wiring. |
| `lib/services/settings_controller.dart` | `e031b8c49e6c1ed6542bad65502cffbc4febc870` | Existing persisted preference flow; fetched controller has no theme-mode accessor. |
| `lib/app/daymaker_shell.dart` | `26d07e80b73ae02bcf2f081a383a0868f10b6495` | Five destinations and monetization/safety behavior need careful four-tab migration. |
| `lib/features/roasts/models/roast_persona.dart` | `9e2652225b565b43e03d592dce4b3068265a699a` | Canonical five IDs, aliases and current asset mapping should be preserved/migrated. |

Canonical source paths can be opened at:

- https://github.com/mleikam1/grumpy_skies/blob/main/AGENTS.md
- https://github.com/mleikam1/grumpy_skies/blob/main/lib/main.dart
- https://github.com/mleikam1/grumpy_skies/blob/main/lib/design/dm_theme.dart
- https://github.com/mleikam1/grumpy_skies/blob/main/lib/app/daymaker_app.dart
- https://github.com/mleikam1/grumpy_skies/blob/main/lib/services/settings_controller.dart
- https://github.com/mleikam1/grumpy_skies/blob/main/lib/app/daymaker_shell.dart
- https://github.com/mleikam1/grumpy_skies/blob/main/lib/features/roasts/models/roast_persona.dart

Other component paths referenced in the integration plan come from the prior source review and must be revalidated in the current local tree. The newest commit also contains unrelated project handoff material; it is not a reason to switch this task to that other app.

## Official implementation references consulted

- Flutter themes: https://docs.flutter.dev/cookbook/design/themes
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- OpenAI Codex prompting entrypoint: https://developers.openai.com/codex/prompting/ (currently redirects to the official ChatGPT Learn prompting documentation)
- OpenAI AGENTS.md entrypoint: https://developers.openai.com/codex/guides/agents-md/ (currently redirects to official ChatGPT Learn agent-configuration documentation)

These support the shared-theme/context/verification approach. They do not certify that this package's palette is the original source palette, that the app is accessible, or that a particular model/tool/signing setup exists on the owner's computer. Model selection is left to the owner's available Codex configuration.

## What is not claimed

No Flutter app compilation, local-device launch, cloud deployment, live weather verification, high-resolution asset reconstruction, platform QA, or exact visual implementation has been performed by packaging this handoff. Those are Codex execution tasks with explicit acceptance evidence required. The comparison utilities and package contents are separately validated; see PACKAGE_QA.md.
