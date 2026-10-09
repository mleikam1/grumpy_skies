# Acceptance checklist

Codex must copy this into an evidence report, marking each item PASS / FAIL / BLOCKED / NOT APPLICABLE with a file, command, screenshot or explanation. Unchecked items below are requirements, not tests already passed by the package author.

## Visual authority and scope
- [ ] Both approved original PNGs were opened and examined before implementation.
- [ ] The Light board controls geometry and static content in both themes.
- [ ] The final same-layout Dark board, not the alternate Frat Bro board, controls dark treatment.
- [ ] No older simple SVG/emoji cast is used as final character art.
- [ ] No poster headings, annotations, fake phone frame or fake 9:41 status bar appears inside the app.
- [ ] Screens are real Flutter UI, not full-screen screenshots with invisible hotspots.
- [ ] Dynamic text/values/controls are not baked into illustration assets.
- [ ] Unpictured secondary screens are reported as derived extensions, not independently approved designs.

## Character identity and asset quality
- [ ] All five approved character appearances are represented.
- [ ] IDs and aliases for karen, frat_bro, politician, grandpa and two_year_old remain compatible.
- [ ] New art appears consistently on Today, Roasts, selectors, Settings and relevant shares.
- [ ] The same canonical character assets are used in both themes without color inversion/tinting.
- [ ] Karen's sunglasses, blonde hair and pink blazer match the reference.
- [ ] Grandpa's glasses, white side hair and green sweater match the reference.
- [ ] Frat Bro, Politician and toddler match their thumbnail identities; extrapolations are disclosed.
- [ ] Each runtime asset has provenance, dimensions, alpha status and a documented final path.
- [ ] No ghost captions, UI borders or neighboring faces are inside reusable portrait art.
- [ ] High-density quality was inspected at actual intended display sizes.
- [ ] Reconstructed art is identified as reconstructed, not an extracted original.
- [ ] Old saved memes still resolve legacy artwork/media references.

## Theme architecture and persistence
- [ ] Light and Dark are actually distinct ThemeData/color palettes.
- [ ] Light/Dark/System choices work and persist through restart.
- [ ] Missing/unknown old preference values migrate safely without resetting other preferences.
- [ ] Rapid preference changes cannot persist an outdated value last.
- [ ] System mode responds to OS brightness; explicit Light/Dark do not.
- [ ] Saved Dark mode does not flash a bright app screen at startup.
- [ ] Both modes share layout/type metrics and a canonical widget structure.
- [ ] Switching mode preserves selected tab, route and scroll offset.
- [ ] Switching mode preserves selected persona, displayed roast and weather state.
- [ ] Switching mode preserves dirty meme drafts and undo history.
- [ ] Switching mode does not trigger new weather, location or AI requests.
- [ ] Meteorological day/night icon selection is independent of application brightness.
- [ ] Menus, dialogs, sheets, snackbars, inputs, focus states and system overlays are themed.
- [ ] App appearance does not recolor exported user artwork or ad creatives.

## Navigation and page structure
- [ ] Compact order is Today, Radar, Roasts, Fun.
- [ ] Today maps to /forecast; Settings remains reachable from the gear.
- [ ] Legacy redirects and nested URLs work, including cold/deep-link navigation.
- [ ] Browser/system Back navigation returns correctly.
- [ ] Secondary settings/editor routes do not falsely highlight Today.
- [ ] Bottom safe-area reserve matches real nav height and scales safely.
- [ ] Last scroll items and primary actions remain accessible above navigation/keyboard.
- [ ] Inactive tabs do not keep expensive loops/polling running unnecessarily.

## Approved Today
- [ ] Header/location/status positions match the Light reference.
- [ ] Large temperature, condition, supporting values and right artwork match hierarchy/proportions.
- [ ] Hero art does not obscure negative/triple-digit temperatures or long labels.
- [ ] Insight card has real supported data and a working detail action.
- [ ] Featured persona card matches portrait/text/button arrangement in both themes.
- [ ] Another changes local roast content without refetching weather.
- [ ] Share opens a real share flow or clearly labeled supported fallback.
- [ ] Hourly tiles and compact daily rows match the reference styling.
- [ ] Available days/hours, unit conversion, location timezone and date boundaries are correct.
- [ ] Real observation/source/freshness labels remain visible and truthful.

## Approved Roasts
- [ ] Header, title and canonical five-persona selector match.
- [ ] Selection persists and produces correct character/voice content.
- [ ] Grandpa fixture card matches the portrait and quote layout.
- [ ] Production respects saved selection, not a hardcoded Grandpa default.
- [ ] Another/Share sit beneath the card as in the reference.
- [ ] Exact displayed quote and frozen context are preserved when creating a meme.
- [ ] History timestamps/progress represent real events and do not increment on rebuild.
- [ ] Empty history, no weather, long roast and save failure are handled.

## Approved Fun and existing activities
- [ ] Make a meme/Templates/My memes tabs are functional.
- [ ] Meme Studio promotion matches text/art/action composition in both themes.
- [ ] Quick templates render the approved art/copy pattern and open actual templates.
- [ ] Featured meme opens editable layered content rather than a flattened screenshot.
- [ ] Fortune Cookie, prediction wheel and Weather Menace remain accessible.
- [ ] Novelty content is distinguishable from real weather; no fake scientific probabilities.
- [ ] Repeated actions cannot fabricate progression/rewards.

## Meme editor, storage and exports
- [ ] Existing document schema/IDs and local library are preserved.
- [ ] Imported photos and local media remain accessible.
- [ ] Autosave, recovery and explicit save show accurate status/errors.
- [ ] Undo/redo, text edits, transforms, stickers, layers and weather chips still work.
- [ ] App navigation does not crowd the focused editor UI.
- [ ] Keyboard/insets do not hide active inputs or export actions.
- [ ] Current roast transfers exactly; canceled replacement does not lose work.
- [ ] Native/web supported exports actually produce viewable files.
- [ ] Sharing cancellation is not reported as a successful share/reward.
- [ ] Operation/modal guards survive theme switches, export and returning from a share sheet.

## Radar, safety and data integrity
- [ ] Real radar/map implementation remains; no decorative mock map is presented as live.
- [ ] Source, timestamp, legend and observed-versus-forecast distinction are visible.
- [ ] Frame transitions retain prior valid content while new tiles load.
- [ ] Unavailable tiles/coverage and unsupported horizons show honest states.
- [ ] Background/inactive radar playback stops appropriately.
- [ ] Location switching cannot display a stale response for the previous location.
- [ ] Offline mode shows last real values with clear age/cache labeling.
- [ ] Production failure never falls back to synthetic 72-degree weather.
- [ ] Severe warnings retain neutral wording and immediate detail access.
- [ ] No jokes/ads/celebration compete with critical warnings under safety gates.

## Settings, ads, platform and accessibility
- [ ] Every visible settings action works or honestly states the unsupported/configuration state.
- [ ] Notification preference, OS permission and delivery setup are not conflated.
- [ ] Real version/license/privacy/contact destinations are used or their blockers identified.
- [ ] Ad placement IDs, sizes, consent, frequency and safety/operation gating remain correct.
- [ ] Ads are not added to the approved hero, warning panel or active editor canvas.
- [ ] No-fill or ineligible ads do not show fake creatives or misleading blank calls to action.
- [ ] Narrow phone, large phone, short-height and landscape layouts avoid overflow.
- [ ] Tablet/desktop use purposeful responsive arrangements with shared components.
- [ ] 200% text scaling has no hidden essential copy or controls.
- [ ] Touch regions, screen-reader labels, keyboard focus and selected-state semantics work.
- [ ] Actual composed text/background contrast and focus visibility were checked.
- [ ] Reduced-motion/animation lifecycle behavior is functional in both themes.

## Completion evidence
- [ ] Baseline and changed-file/dependency inventory are recorded.
- [ ] Real Today/Roasts/Fun captures exist for both themes in the same fixture state.
- [ ] Important secondary screens were captured in both themes.
- [ ] Visual comparison methodology, viewports and remaining differences are documented.
- [ ] Candidate images were not distorted to manufacture a successful comparison.
- [ ] Format/analyzer/unit/widget/integration results are recorded accurately.
- [ ] Available target builds were run; unavailable targets are explicitly BLOCKED.
- [ ] Asset status does not describe low-resolution placeholders as final production art.
- [ ] Fixture evidence and live checks are separately labeled.
- [ ] No unapproved deployment, spending, data wipe, external push or unrelated-project change occurred.
- [ ] Final report includes local run steps, migration/rollback details, and unresolved owner-only actions.
