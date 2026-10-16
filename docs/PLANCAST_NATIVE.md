# PlanCast native integration

PlanCast uses a small Flutter method/event channel, with no calendar, notification,
or speech plugin dependency. Production data comes from the device calendar store.
The bridge is guarded on web and non-iOS/Android hosts.

## Official API decisions (checked 2026-10-15)

- [Apple EventKit access](https://developer.apple.com/documentation/eventkit/accessing-the-event-store): iOS 17+ uses `requestFullAccessToEvents`; write-only is insufficient. The existing iOS 13 deployment target requires an availability-checked legacy request and both usage strings. No event mutation, reminders permission or contacts permission exists in this bridge.
- [Android Calendar Provider](https://developer.android.com/identity/providers/calendar-provider) and [Instances](https://developer.android.com/reference/android/provider/CalendarContract.Instances): only `READ_CALENDAR`; query selected, visible device calendars through bounded instances, including recurrence exceptions. No `WRITE_CALENDAR`. Queries run on a serial worker, and change notifications are debounced.
- [Apple local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app): non-repeating `UNCalendarNotificationTrigger` requests, namespaced IDs, maximum 32 PlanCast requests, reserving capacity for other app features in a conservative total pending budget.
- [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission): `POST_NOTIFICATIONS` requested separately on Android 13+. Existing notification permission and channel disablement are respected.
- [Android inexact alarms](https://developer.android.com/develop/background-work/services/alarms): `setAndAllowWhileIdle` with immutable explicit `PendingIntent`, no exact-alarm permission. Delivery may be delayed by OS power restrictions. A protected persisted queue is restored after boot/update and adjusted for timezone/clock changes.
- [Apple background refresh](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtaskrequest) and [Android JobScheduler](https://developer.android.com/reference/android/app/job/JobScheduler): best-effort maintenance checks calendar permission, prunes deleted/moved/cancelled/declined instances and expired notices. No delivery-time weather-refresh promise and no network polling.
- [Apple Data Protection](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files): feature preferences and the bounded notification queue live in backup-excluded Application Support files with `completeUntilFirstUserAuthentication` protection. This allows maintenance after first unlock. Android uses AES-GCM with an Android Keystore key and atomic files under `noBackupFilesDir`.
- [Android voices](https://developer.android.com/reference/android/speech/tts/Voice) and [Apple speech synthesis](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer): Android selects only an installed voice whose `isNetworkConnectionRequired` is false and language matches the device. iOS conservatively selects only installed Apple compact system voices in the device language. No Personal Voice, third-party extensions, downloads, paid synthesis, remote fallback or autoplay. Missing offline voice returns `unavailable`; text remains available.

## Official reference recheck for the newer checkout (2026-10-15)

The API choices were rechecked against current official documentation after the
additive port. Apple’s documentation reader required its linked Markdown form;
those official pages were read directly. No third-party API guide was used.

- [EventKit authorization](https://developer.apple.com/documentation/eventkit/accessing-the-event-store): reading existing events requires full access; write-only does not reveal real calendars/events. Keep both the iOS 17+ and legacy usage descriptions, and the availability-checked requests.
- [Local notification delivery/cancellation](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app): the system delivers queued notifications while the app is stopped; explicit pending-request cancellation is required after changes. This does not provide application validation at actual delivery.
- [Background earliest start](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate): the date is a lower bound, not a guaranteed run time. [App refresh](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask) requires the fetch background mode.
- [Protection after first unlock](https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication): files become accessible after the first unlock and remain accessible across subsequent locks, enabling local maintenance. This is intentionally different from protection that becomes unavailable on every lock.
- [Apple device voices](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/speechvoices()): enumerates available device voices. Compact Apple identifiers are a conservative implementation filter, not a promised permanent identifier format; an absent match must remain unavailable with no download/network fallback.
- [Android calendar provider](https://developer.android.com/identity/providers/calendar-provider) and [Instances](https://developer.android.com/reference/android/provider/CalendarContract.Instances): READ_CALENDAR permits querying; use occurrence ranges and a selected-calendar projection on a worker thread. No provider writes are needed.
- [Android alarms](https://developer.android.com/develop/background-work/services/alarms): setAndAllowWhileIdle is inexact and can arrive late, especially under power restrictions. Preserve actual-delivery quiet/expiry checks and avoid an exact-alarm permission.
- [Android notification permission](https://developer.android.com/develop/ui/views/notifications/notification-permission): request POST_NOTIFICATIONS contextually on Android 13+. [Voice](https://developer.android.com/reference/android/speech/tts/Voice) exposes isNetworkConnectionRequired; verify an installed offline voice is selected before passing private text to the engine.
- [AtomicFile](https://developer.android.com/reference/android/util/AtomicFile): use its public delete operation for cleanup rather than deleting only the base file. Access stays serialized by the native executor.

## Privacy and lifecycle

Calendar titles, descriptions, guests and meeting contents are never sent by this
native implementation to network services, telemetry, logs or analytics. Only
identity, selected calendar, title, timing, location, category/status and optional
structured coordinates cross to Dart in memory. Descriptions and attachments are
never read. iOS examines only the current user's attendee response to reject
its declined events, without serializing guest data. Android reads the scalar
`selfAttendeeStatus` column.

All-day start and exclusive end are separate `YYYY-MM-DD` civil dates. Timed
values retain UTC epoch milliseconds and an IANA zone. Recurring identity includes
the original occurrence instant; overlapping events are not merged by title.

Disconnect stops foreground observation/speech, deletes this feature's protected
files/key, removes its pending/delivered notices, and cancels its maintenance job. Android uses `AtomicFile.delete()` so crash-recovery backup
and temporary versions are removed too. A pending speech request is invalidated
on stop, disconnect, activity pause or disposal before text reaches an engine.
Permission is checked before reads, on resume, in background maintenance and on
Android delivery. External revocation cannot be detected instantly while the OS
prevents execution. Source calendars are never edited.

Notification URLs contain opaque event hashes or civil day identifiers only.
Native instance identifiers are stored only in the protected local queue to
revalidate events, not in URLs. A native SHA-256 fingerprint invalidates notices
when titles, venues, timing or status change; private source text is not needed
in that comparison. Calendar/forecast/generated/expiry timestamps
travel with notices. Weather text is accepted only when its scheduled delivery is
within six hours of both calendar sync and the underlying forecast update; stale
text becomes a generic open-PlanCast invitation. Android checks actual delivery
time again. iOS cannot run validation at the exact notification delivery time;
its planned-delivery freshness check and opportunistic maintenance are the
reliability boundary. Quiet hours constrain planned times on both platforms;
Android also suppresses an inexact alarm that actually arrives during quiet hours.
iOS can defer delivery beyond the planned time without running application code,
so late delivery can cross that planned quiet-hours boundary. Event notices expire
by event start; Android enforces that at delivery. Unexpired inexact Android alarms
remain eligible if maintenance runs after their nominal time. Each payload is a
one-shot notice within seven days; old
briefings never repeat forever. Changes made while the app cannot run may not be
reflected until its next sync. Maintenance compares each saved scheduling zone
with the current zone so morning/evening wall-clock times recover on resume even
when a timezone-change callback was missed during termination. iOS requires physical-device confirmation of
background opportunities and late delivery behavior.

No new API keys, OAuth setup, paid APIs, foreground service, background location,
server uploads, cloud-calendar sync or production deployment is introduced.

## Authoritative checkout verification (2026-10-15)

The native source was ported additively to
`/Users/MattLeikam/Documents/Codex/2026-09-17/files-pasted-by-the-user-work/outputs/grumpy_skies`
(starting HEAD `7a24ec0`). The following results are from this newer checkout only.
Its deployment settings, bundle IDs, package configuration, assets/fonts, and both
tracked Swift package locks were preserved. Both locks match their pre-build
SHA-256 hashes; no lock restoration was performed.

Four native integration runs passed: Android API 36.1 initial/unrequested,
externally granted/empty-store, and externally revoked/unrequested states; iOS
26.3.1 initial/unrequested state. Each run used the actual platform channel,
checked permission/capability states and query guards, then launched this
checkout’s production `main.dart` without an automatic calendar permission
request. The granted Android store contained zero calendars, so populated
instance and recurrence queries remain unverified at runtime. External Android
grant/revoke did not exercise a real permission dialog; the unrequested flag
remained unset and `notDetermined` was the expected revoked result.

Final ordinary builds passed:

- `JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home flutter build apk --debug --no-pub`
- `flutter build ios --simulator --debug --no-codesign --no-pub`

One Android packaging attempt hit disk exhaustion. Removing only the earlier
wrong checkout’s generated `build/` directory resolved it; retry passed without
source changes. The final Android production APK installed and cold-launched
with no app error logs. The final iOS production app installed and launched.
The initial interactive attempt stopped when the Mac was locked. After the user
unlocked it, the same ordinary production Runner.app was installed and launched
on a new dedicated iPhone 17 simulator named **DayMaker Current UI Review**
(iOS 26.3 runtime, `CCD7644A-265B-49D6-B868-84219E8E3BF3`). No additional build or
production source changes were made for this follow-up.

The real iOS calendar prompt was denied, producing a clear disconnected state
while weather remained usable. After a permission reset, the real Allow Full
Access action showed Calendar, Birthdays, and US Holidays with all checkboxes
initially off. Selecting only Calendar produced one authorized selection and a
real bounded empty-store query. Today, Tomorrow, and This week showed empty
states. No accounts or calendar events were seeded.

Notifications stayed off and unrequested until their own switch was enabled.
Their separate OS prompt was denied; the switch remained off/denied while
calendar content remained available. Read my day exercised the offline-voice-
unavailable fallback with the text briefing retained; successful audio playback
is not claimed.

Calendar revocation with `simctl privacy` followed by relaunch returned PlanCast
to its denied/disconnected state. Protected preferences existed before revocation
(442 bytes) and were absent afterward; the queue file was absent before and
after. After reconnecting Calendar alone, the explicit Disconnect and delete
confirmation again left both files absent without revoking OS calendar access.
`ios-review-storage.json` records only existence and byte counts, never contents.
An absent queue file is not proof of cancellation of existing OS notifications;
this review did not create a populated pending queue.

The ordinary backend loaded Overland Park weather, Overcast at 57 F. The corrected
forecast presentation, forecast swap, both full See all views, and the hourly
Karen roast were visually verified. Dark/Celsius Today and forecast screenshots
were checked, then Light/Fahrenheit was restored. Actual native screenshots are
saved as `native-ios-*.png`.

`native-animation.mp4` passed AVFoundation playback/decoding and motion checks:
24.775 seconds, 1206 × 2622, about 58.874 fps, and 30 sampled frames decoded.
Sun and rain crops showed changing pixels while adjacent temperature controls
remained unchanged; visual crop inspection confirmed rotation and falling drops.
The native report includes thresholds/timestamps and identifies the evidence logs.

The full first-connection View my PlanCast action was exercised after reconnecting.
A cold terminate/launch verified that the Calendar-only connection persisted.

The earlier disposable Android AVD and iOS test simulator were deleted. Existing
devices, including `F4803BFF-BEBD-4942-B495-0CAFDF367BE6`, were preserved. The new
DayMaker Current UI Review simulator is intentionally retained and visibly open
on PlanCast Today at the user's request: Light/Fahrenheit, Calendar only selected,
notifications off/denied. No accounts or calendar events were created. Exact
commands, lock hashes, results, cleanup proof, and current review evidence are in
the task's `outputs/new-ui-correction/` directory.

## Remaining device checks

No physical-device calendar or background-delivery test is claimed. Remaining
coverage includes populated/multiple calendar accounts; recurrence exceptions,
moves and deletions; all-day/date-line/DST semantics; restricted/write-only and
iOS 13–16 permission paths; successful offline voices in airplane mode;
lock-screen privacy; notification grant, channel disablement, scheduling, actual
delivery, quiet hours, process termination, Doze/restart/timezone changes;
changed-event deep links; and cancellation of existing OS pending/delivered
notifications while unrelated notices remain intact. File protection after
lock/first unlock, backup restoration, and Android key invalidation require
device verification. iOS planned-delivery validation and opportunistic
maintenance cannot guarantee revalidation at the instant the OS delivers a
local notification.
