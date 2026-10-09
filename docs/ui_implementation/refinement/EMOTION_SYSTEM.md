# Persona expressions

The existing five persona IDs and their aliases are unchanged. `RoastMood` defines
ten stable values: happy, excited, hyped, cozy, complaining, annoyed, sad, worried,
confident and neutral. `Roast` and `RoastLine` accept optional editorial metadata.
The bundled pack now annotates all 35 existing quotes and retains their text,
weather constraints, selection weights and alert behavior. Its version is
2026.10.09.1; schema version remains 1 because this is an optional additive field.
The CSV source contains the same metadata, so regeneration preserves expressions.
Older CSVs and cached/remote JSON packs remain supported. No remote pack was deployed.

`RoastMoodResolver` gives explicit metadata precedence, including explicit neutral.
Older content uses ordered phrase matching, then a conservative persona default.
It has no random, time, theme or network input. The four requested examples resolve
to Karen/complaining, Frat Bro/hyped, Grandpa/cozy and 2-Year-Old/excited. Unknown
future JSON values safely use inference; invalid editorial CSV values fail loudly.

`PersonaEmotionAssets` maps the canonical persona and mood to
`assets/personas/<persona>/<mood>.png`. `DmPersonaPortrait` displays the native art
without tinting or stretching. Its same-persona fallback chain is requested mood,
neutral, then the retained approved portrait. Missing artwork never switches the
quote to a different persona. Selector portraits retain their existing stable
identity; Today, featured Roasts, crew/history entries and the reveal use the
specific displayed mood. The asset ledger records exact generation sources and
edge limitations. No legacy assets were deleted.

Both primary card variants include a mood badge and persona title. The Today card
keeps Another and Share; Roasts retains its full-width existing action row. Long
quotes use the available width without overlapping artwork. At large text sizes,
portrait/title and quote stack, and the buttons wrap rather than shrink.

`DisplayedRoastSnapshot` freezes the resolved mood with the exact quote and weather.
Registry equality includes that mood. Sharing and reveal receive this snapshot;
Meme Studio keeps the same existing caption/weather handoff and document schema.
No theme switch rerolls a quote or makes a weather request. No settings, cache,
persona-selection, history or meme data are erased or migrated.

Tests in `roast_emotion_system_test.dart` cover explicit/inferred selection,
legacy pack compatibility, CSV round-trip, alias resolution, fallback order,
registry updates, actual pack selection/history, and all five cards in both themes
at 320 logical pixels with 200% text. `roast_emotion_capture_test.dart` renders the
actual two card variants and ten-expression gallery for each persona in both modes.
The gallery and canonical example quotes are explicitly labeled fixture evidence.

The CSV builder/validator use pure Dart content models, re-exported by the existing weather-aware model file. `dart run tool/build_roast_pack.dart --output work/roast-pack-review.json` produced an exact parsed JSON match to the bundled pack. The regression suite invokes the standalone tool in a subprocess.
