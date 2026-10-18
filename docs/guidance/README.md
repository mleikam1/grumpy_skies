# Local Wingman guidance catalog

The app bundles 240 reviewed messages in 40 evidence families. Selection uses existing weather, location, calendar context, and optional device-local preferences. JSON supplies text and named contracts; it cannot execute rules, create capabilities, call providers, or establish that a fact is true.

The approved content is in `assets/guidance/wingman_tips.en-US.json` and `assets/guidance/wingman_tip_family_contracts.json`. Both use schema version 1 and catalog version 1.1.0. Each template has a stable `id`, `familyId`, `text`, and mandatory `requiredGuards` list. The 35 narrower requirements in the supplied pack remain represented in both `variantOverrides` and the corresponding template. An empty list means no extra requirement beyond its family and the global evidence policy.

Run from the repository root:

```sh
python3 tools/validate_guidance_catalog.py --self-test --report docs/guidance/validation_report.json
```

The validator uses only Python's standard library and makes no network requests. It rejects unknown or missing fields, unregistered template/family/guard/surface IDs, changed registered contract prerequisites, unsupported priority bands, duplicate JSON keys, mismatched versions, omitted narrow guards, placeholders, numeric claims, duplicate text, near-duplicate wording within a family, and text over 160 characters or 28 words. It also requires a current review record for every message. Its 24 negative cases deliberately corrupt these boundaries. The Dart runtime separately validates and evaluates its registered contract set; passing editorial validation alone does not make a message eligible.

`variant_claim_review.json` records all 240 original and reviewed texts, inherited prerequisites, extra guards, exclusions, claim rationale, activity binding, and practical action focus. It is review evidence, not a production asset. `catalog_review.md` explains the review decisions. `validation_report.json` records deterministic byte sizes and hashes. `future_static_updates.md` describes a disabled future option; no updater is implemented by this catalog change. `dependency_runtime_audit.md` records the installed dependency and legacy-code audit.

## Editing content

1. Preserve a stable ID when correcting wording for the same situation and action. Do not reuse an ID for a different claim or action. Keep six genuinely useful variants per existing family, not six punctuation or synonym changes. The current reviewed pack has 240 distinct messages; future additions need new registered IDs in both validators.
2. Read the family contract and the template's narrower guards. Trace every weather, timing, location, and activity statement to an existing supported predicate. Review the full rendered message including its visible interval and location context. If the evidence does not support a phrase, narrow it or add an explicitly implemented guard; do not silently broaden eligibility.
3. Update `variant_claim_review.json`, retaining the supplied original text for this initial review. Explain the new claim and distinct action. A preference alone must not become an actual outing, commute, or outdoor event. Maintain uncertainty and provider precision.
4. Bump both catalog versions together. Schema changes, family changes, new IDs, changed surfaces, and new guards require coordinated changes to the registered Python and Dart schemas, code predicates, and negative tests. Arbitrary downloaded metadata must never relax compiled prerequisites.
5. Run validation, then the repository's guidance tests and supported UI checks. Check the complete text on narrow and large-text surfaces; the text budget does not guarantee a fixed line count. Test positive evidence and missing/contradictory/stale evidence for every changed guard. Existing official-alert handling always takes precedence.

No place, time, percentage, temperature, AQI number, or dynamic activity name is interpolated into these templates. The UI displays supported facts and scope separately using existing units, locale, and source precision. Adding interpolation requires a new, explicitly allowlisted schema and independent value validation.

## Delivery and privacy boundaries

Bundle loading is local initialization, never a request fallback. If loading or parsing fails, omit the optional tip. Evaluation and visibility must not refresh weather, geocode, query calendar, call an LLM, fetch content, write cloud data, or record analytics. A shown tip may enter the bounded local impression ring through the separate visibility path; rendering alone is not an impression. Preference changes use the existing local settings storage. Existing app weather, radar, map, advertising, and other costs remain separate from the guidance feature.
