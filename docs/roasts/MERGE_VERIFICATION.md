# Main-branch merge verification

This final verification follows the initial implementation handoff in `VERIFICATION_REPORT.md`. The initial handoff's counts, build identity and browser screenshots remain historical evidence for that build. This report records the small correction and final checks performed for the owner's requested merge to `origin/main` on October 10, 2026.

## Final review correction

A stalled browser response could prevent cancellation from completing: the response reader needed an abort, but that abort originally happened after cancellation. The downloader now aborts inside its body-timeout callback before emitting the timeout error. The browser client consumes the expected rejected read during cancellation. A real browser `ReadableStream` regression proves that the stalled read terminates, the scheduler releases its in-flight request, and a later permitted sync succeeds. The production timeout remains 15 seconds for headers or the next body chunk. Optional downloads remain disabled by default.

Only the two optional HTTP transport files changed in production after the initial tested handoff. No approved UI component, artwork, catalog content, routes, theme, or monetization behavior changed during merge preparation. Generated `/coverage/` is now ignored; `coverage_summary.json` remains committed, and the raw LCOV file remains in the delivery evidence.

## Completed checks

| Check | Result |
| --- | --- |
| `flutter test --no-pub --coverage --reporter expanded` | 585 passed; zero failures |
| `flutter analyze --no-pub` | No issues |
| Focused engine/controller/update suite | 78 passed |
| Native update suite | 25 passed |
| Chrome transport + IndexedDB suites | 3 passed |
| Backend `npm test` (includes TypeScript build) | 17 passed; source unchanged since that run |
| Catalog validation | 530 active rows, 52 rules accepted |
| Release staging tests | 2 passed |
| Changed Dart formatting / Git whitespace | Clean |
| `flutter build web --release --no-pub --target lib/main.dart` | Built successfully, 43.6 seconds |
| `flutter build ios --simulator --debug --no-pub --target lib/main.dart` | Built successfully, 23.7 seconds |

Final recorded coverage is 11,014/13,373 lines (82.36%) overall and 1,877/2,096 lines (89.55%) in the roast engine scope. Browser-only tests run separately from VM coverage. The iOS simulator build still prints the pre-existing missing build-name/build-number warnings; this is not an App Store submission or simulator/device installation.

Local logs are `work/merge-final-tests.log`, `work/merge-final-analysis.log`, `work/merge-web-release.log`, `work/merge-ios-simulator.log`, `work/engine-timeout-native.log`, `work/engine-timeout-chrome.log`, and `work/engine-timeout-analyze.log`. The initial build identity is preserved at `work/roast-build-identity-initial.json`; the final one is `work/roast-build-identity.json`. Its production source digest is `3c26311a8998461bc8302801b59d1b5a6e99d423e67064d179a41f4d616f889d`.

## Publication scope

The requested operation updates GitHub `origin/main` through a normal fast-forward from the verified worktree. No force push, history rewrite, Firebase deployment, billing change, or device installation is part of this merge. The separate older local `main` checkout contains unrelated uncommitted work and is preserved. No GitHub Actions workflow, branch-protection rule, or required status check is configured in the inspected repository; validation above was run locally.

Catalog and release limitations remain unchanged: 530/5,000 lines, human editorial review outstanding, optional update origin unverified/default off, and no new approved inline humor or preference controls. The 74 identical UI captures and initial live browser network measurements are documented in `UI_VERIFICATION.md` and `VERIFICATION_REPORT.md`.
