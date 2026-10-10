# Catalog and editorial coverage

Recorded 2026-10-10 from the approved worktree. **530 active lines / 106 per persona** ship; the requested 5,000-line target is **not complete: 4,470 lines remain**. Do not market these counts as 5,000 or human-approved.

The baseline source contained 35 rows. All 35 stable IDs remain in CSV; 30 ordinary lines were retained/migrated and five severe-weather messages were retired from comedy packs in favor of application-owned safety copy. Another 250 individually authored candidate lines were reused from the read-only older working checkout after inspection. This task added 250 complete original candidate lines and performed a separate machine editorial pass. No formula-driven phrase combinations, city substitutions, or punctuation variants were used to inflate totals.

| Persona | Active | Today | Hourly | Commute | Weekend | Mood/activity | Context-free |
|---|---:|---:|---:|---:|---:|---:|---:|
| frat_bro | 106 | 64 | 18 | 8 | 8 | 8 | 11 |
| grandpa | 106 | 64 | 18 | 8 | 8 | 8 | 11 |
| karen | 106 | 64 | 18 | 8 | 8 | 8 | 11 |
| politician | 106 | 64 | 18 | 8 | 8 | 8 | 11 |
| two_year_old | 106 | 64 | 18 | 8 | 8 | 8 | 11 |

All ten moods occur for every persona. There are 52 data-only rules and 507 stable families; 33 lines with recurring premises share ten explicit families (subscription refunds, feedback forms, atmosphere workouts, sky playlists, quilts, stories, efficiency meetings, unearned credit, crayons and timeouts). Remaining complete premises keep granular stable family IDs. Longest active text: 109 characters.

The second pass corrected unsupported freezing claims under a broader cold rule; blue-sky wording that could have appeared at night; season/trend claims without historical or regional evidence; overly specific drizzle language; and repeated setup families. Existing approved explicit moods were preserved for migrated IDs. Required scope/daypart/placeholder constraints remain attached. Karen uses service complaints, Frat Bro friendly enthusiasm, Grandpa familiar observations, Politician fictional bureaucracy, and Two Year Old short imaginative reactions. Human originality/voice approval remains outstanding.

Build validation reports zero exact or near-duplicate errors, zero missing fields/moods/rules/placeholders, and zero content warnings. High-overlap detection normalizes punctuation and interpolation tokens and rejects >=85% token overlap for sufficiently long texts. It cannot prove that two jokes with dissimilar wording have different ideas; this remains part of editorial review.

The production-selector preview covers 26 simulated contexts × 5 personas × 5 content types = **650 cases**, with twelve seeded samples per case and a per-row hard-eligibility trace. It is a synthetic matrix, not live weather or a production screen capture. Actual expression artwork is checked for all selected samples and all fifty required persona/mood paths; missing files: zero. [Preview screenshot](evidence/editorial-preview.jpg) verifies the rule/mood filters, inspected text and actual Karen annoyed artwork in a local browser.

| Scenario and slot | Eligible counts: Frat Bro / Grandpa / Karen / Politician / Two Year Old |
|---|---|
| Clear / pleasant / today | 13 / 13 / 13 / 14 / 13 |
| Observed light rain / today | 8 / 8 / 8 / 8 / 9 |
| Hot and humid / today | 19 / 18 / 18 / 18 / 18 |
| Hourly clear / hourly | 7 / 7 / 7 / 7 / 7 |
| Unknown alerts / today | 8 / 8 / 8 / 8 / 8 |
| Active alert / safety gate / today | 0 / 0 / 0 / 0 / 0 |
| Stale weather / today | 3 / 3 / 3 / 3 / 3 |
| Unavailable weather / today | 3 / 3 / 3 / 3 / 3 |
| Incomplete weekend / weekend | 2 / 2 / 2 / 2 / 2 |

Active-alert contexts have zero eligible comedy rows and use application-owned safety text. Stale/unavailable current weather has three catalog context-free options per persona; incomplete weekends have two. These small pools require safe repeats and do not meet seven-day variety goals under heavy usage. Fallbacks remain available for all five content types and personas. Forecast rain-probability lines make probability claims, and hourly/commute/weekend rules cannot substitute present conditions.

Coverage gaps remain explicit: 4,470 additional substantive lines; only en-US editorial content; regional/holiday/season copy absent; few daily/commute/weekend alternatives; very little medium/spicy copy; no human approval. The suggested 500/200/150/100/50 allocation per persona is not met. Location-specific flavor and seasonal/holiday claims were withheld rather than fabricated. Inline placements that do not already exist in the approved UI remain a separate UI scope; the catalog and preview do not add screens or controls to production.

Reproduction commands and publication/rollback safeguards are in [README](README.md). Runtime engine, persistence, network and UI fidelity tests are documented by the implementation report; the editorial matrix does not replace those tests.
