# PlanCast release verification — current DayMaker UI

Authoritative checkout: `feat/persona-sky-blue-theme` at `7a24ec0`, the approved
DayMaker light/dark design. This corrects an earlier implementation made against
the older `bedddc8` preservation checkout. The earlier checkout is left intact.

The active `/forecast` route now places the daily horizontal tiles in the original
hourly tile position, followed by hourly vertical rows in the original daily row
position. PlanCast follows immediately, before observation freshness and metrics.
Both expanded experiences remain available; the full hourly timeline retains its
existing local roast interludes. The new UI's themes, artwork, navigation and all
pre-existing uncommitted styling changes are preserved.

Baseline: `flutter analyze --no-pub` clean; `flutter test --no-pub --reporter
expanded` passed all 670 tests. Real app widget captures were saved in light/dark
before editing Dart source. Final results and captures are recorded separately.

## Architecture and cost

- `lib/features/plancast`: platform-neutral calendar repository; normalized event
  models; isolated venue weather repository; deterministic interval evaluator;
  factual briefing composer; cached local persona opinion; notification planner,
  comparable-forecast change detector, controller, screens and lifecycle boundary.
- Production uses EventKit/CalendarContract through the native channel, never test
  fixture calendars. No OAuth, runtime LLM, routing, background location, exact
  alarm, cloud calendar upload, new billed service or deployment is introduced.
- Existing weather backend and cache are reused, with coordinate-only request keys,
  coalesced venue work, concurrency two, six new venues per refresh, twelve request
  attempts per hour, backoff and explicit deferred coverage. Review these caps
  against actual provider entitlements before release. Persona/unit rebuilds do not
  trigger venue requests.
- The existing location search resolves cities/localities, not reliable street
  addresses. Users explicitly confirm candidate locations or set exact coordinates.
  Structured calendar coordinates are used where available; explicit corrections
  override them. Recurring venue mappings are scoped to unchanged source locations
  and expire. Meeting links are never followed and Online events skip weather.
- Event snapshots stay in memory. Only necessary preferences, expiring corrections,
  opaque deduplication metadata and bounded notices are protected locally. A public
  SharedPreferences boolean remembers invitation dismissal; it contains no calendar
  data. No calendar payload is passed to ads, analytics, crash reports or speech
  services. Offline voice unavailable means text-only, with an explanation.

## Notification contract

Notifications require separate consent. Defaults: 07:00 device-local morning,
two-hour event heads-up, at most two additional routine notices/day, private
previews, 22:00–07:00 quiet hours. Day-before and evening notices are optional.
The queue uses persistent native APIs, at most 32 PlanCast notices within seven
days, with iOS space reserved for unrelated pending app notices. Quiet-hour notices
shift to the end of quiet hours only when useful. Native event fingerprints detect
observed moves, title/venue changes and cancellation without uploading the event.

Weather-specific notice text requires a short freshness window and a last-checked
time; otherwise generic invitations are scheduled. Notices are one-shot. Native
maintenance is opportunistic and does not fetch fresh weather at delivery. iOS
cannot guarantee delivery-time validation; Android also rechecks expiry at actual
delivery and suppresses delivery during actual quiet hours. On iOS, OS-delayed
delivery can cross planned quiet-hour or freshness boundaries without executing
app code. Calendar edits while suspended can remain unreflected until execution
resumes. Never market this release as guaranteed real-time calendar/weather alerts.
Existing weather-alert settings and unrelated notifications are not canceled.

## Required release checks on physical devices

- [ ] iOS 17+ full event permission: grant, denial, restriction, write-only rejection,
      external revocation, and reconnect. Legacy permission only on supported iOS
      13–16. No Contacts or Reminders prompt.
- [ ] Android READ_CALENDAR grant/deny/revoke; no WRITE_CALENDAR. Android 13+
      POST_NOTIFICATIONS independent denial/revocation and channel disablement.
- [ ] Multiple device accounts; explicit individual calendar selection; no calendars;
      hidden/sync-disabled calendars; recurring exceptions; overlapping events;
      moved/deleted/canceled/declined/tentative invitations; all-day exclusive ends;
      overnight events; date-line travel and DST repeated/skipped hours.
- [ ] Remote venue while Today/radar remain elsewhere; ambiguous address; corrected
      coordinates; Online/Indoor/Outdoor/Unknown; all forecast intervals and buffers;
      missing versus 0%; stale/offline/partial/day-only/beyond-horizon coverage.
- [ ] Small phone/tablet, large text, screen reader and keyboard; actual icon motion
      in previews/details; app inactivity, scroll, theme/unit/persona transitions;
      reduced motion; no flashes or leaked tickers.
- [ ] Airplane-mode offline speech in supported device languages; missing/downloaded
      voices; stop, navigation and app background cancellation; private speech off.
- [ ] Morning/event/evening/day-before queue, meaningful change cooldown, quiet hours,
      cancellation and replacement; no more than daily budget; lock-screen privacy;
      changed/removed-event deep links; device time-zone and clock changes.
- [ ] iOS background refresh opportunities, OS-delayed delivery and process death;
      Android Doze/process termination/restart/timezone behavior. Confirm generic
      stale fallback and no repeating yesterday's text.
- [ ] Disconnect and external revocation remove PlanCast private data, observers,
      jobs and pending notices while preserving unrelated weather notifications.
- [ ] Inspect release traffic/logs to confirm no calendar titles, addresses beyond
      explicit location lookup, descriptions, guests or payloads leak to providers.
- [ ] Verify the publisher's privacy contact, app-store calendar/notification/privacy
      disclosures and actual provider terms/attribution; do not submit automatically.
- [ ] Set a production app version/build number (currently absent in pubspec) and
      review existing CocoaPods + Swift Package build warnings without discarding
      unrelated native configuration. Both tracked Package.resolved files in this
      authoritative checkout remain present and unchanged.

Automated commands, results and fixture/live screenshot distinctions are recorded
in the task's verification deliverable. A build or simulator smoke pass does not
replace the physical-device checks above.
