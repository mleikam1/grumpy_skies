package com.example.grumpy_skies

import android.Manifest
import android.app.*
import android.app.job.*
import android.content.*
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.*
import android.provider.CalendarContract
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import android.util.AtomicFile
import io.flutter.plugin.common.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.security.KeyStore
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Read-only CalendarContract bridge. No event descriptions, attendees, or writes. */
class PlanCastPlugin(private val activity: MainActivity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var observer: ContentObserver? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var permissionKind = ""
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speechGeneration = 0
    private var disposed = false
    private val speechWaiters = mutableListOf<(Boolean) -> Unit>()
    private var route: String? = null
    private val changeSignal = Runnable { sink?.success("calendarChanged"); PlanCastNative.executor.execute { runCatching { PlanCastNative.maintain(activity) } } }

    init {
        MethodChannel(messenger, "grumpy_skies/plancast").setMethodCallHandler(this)
        EventChannel(messenger, "grumpy_skies/plancast/changes").setStreamHandler(this)
        acceptIntent(activity.intent)
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }
    private fun permission(): String = if (PlanCastNative.calendarAllowed(activity)) "authorized" else if (activity.getSharedPreferences("plancast_permission", Context.MODE_PRIVATE).getBoolean("asked", false)) "denied" else "notDetermined"
    private fun work(result: MethodChannel.Result, block: () -> Any?) {
        PlanCastNative.executor.execute {
            try { val value = block(); main.post { result.success(value) } }
            catch (_: SecurityException) { PlanCastNative.purge(activity); main.post { result.error("permission_denied", "Calendar permission is unavailable.", null) } }
            catch (_: Exception) { main.post { result.error("plancast_unavailable", "PlanCast could not complete this device operation.", null) } }
        }
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "calendarPermission" -> work(result) { if (!PlanCastNative.calendarAllowed(activity)) PlanCastNative.purge(activity); permission() }
            "requestCalendarPermission" -> ask(Manifest.permission.READ_CALENDAR, "calendar", result)
            "calendars" -> work(result) { PlanCastNative.calendars(activity) }
            "events" -> work(result) { PlanCastNative.events(activity, call.argument<List<String>>("calendarIds") ?: emptyList(), call.argument<Number>("startMs")!!.toLong(), call.argument<Number>("endMs")!!.toLong()) }
            "startObserving" -> { observe(); result.success(null) }
            "stopObserving" -> { stopObserving(); result.success(null) }
            "secureRead" -> work(result) { PlanCastNative.read(activity, "preferences") }
            "secureWrite" -> work(result) { PlanCastNative.write(activity, "preferences", call.argument<String>("value") ?: ""); null }
            "secureDelete" -> work(result) { AtomicFile(File(activity.noBackupFilesDir, "plancast_preferences")).delete(); null }
            "disconnect" -> { stopObserving(); cancelSpeech(); work(result) { PlanCastNative.purge(activity); null } }
            "notificationPermission" -> result.success(notificationPermission())
            "requestNotificationPermission" -> if (Build.VERSION.SDK_INT >= 33) ask(Manifest.permission.POST_NOTIFICATIONS, "notification", result) else result.success(notificationPermission())
            "replaceNotifications" -> work(result) { PlanCastNative.replace(activity, JSONArray(call.argument<List<Map<String, Any?>>>("notices") ?: emptyList<Map<String, Any?>>())); null }
            "speechStatus" -> initializeSpeech { result.success(if (it && offlineVoice() != null) "available" else "unavailable") }
            "speak" -> {
                val generation = ++speechGeneration
                initializeSpeech { ready ->
                // Initialization is asynchronous. Stop, disconnect, inactivity or
                // a newer utterance must invalidate this pending private text.
                if (generation != speechGeneration || disposed) {
                    result.success(false)
                    return@initializeSpeech
                }
                val voice = if (ready) offlineVoice() else null
                if (voice == null) result.success(false) else {
                    tts?.stop()
                    // Verify selection succeeded before handing private text to an engine.
                    // A failed setVoice must never fall back to its default network voice.
                    val selected = tts?.setVoice(voice) == TextToSpeech.SUCCESS
                    val current = tts?.voice
                    if (!selected || current?.name != voice.name || current.isNetworkConnectionRequired) result.success(false)
                    else result.success(tts?.speak((call.argument<String>("text") ?: "").take(12000), TextToSpeech.QUEUE_FLUSH, Bundle(), "plancast") == TextToSpeech.SUCCESS)
                }
                }
            }
            "stopSpeaking" -> { cancelSpeech(); result.success(null) }
            "consumeNotificationRoute" -> { result.success(route); route = null }
            else -> result.notImplemented()
        }
    }
    private fun notificationPermission(): String {
        if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return "denied"
        val manager = activity.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return "denied"
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(PlanCastNative.CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return "denied"
        return "authorized"
    }
    private fun ask(permission: String, kind: String, result: MethodChannel.Result) {
        if (activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) { result.success(if (kind == "calendar") "authorized" else notificationPermission()); return }
        if (pendingPermission != null) { result.error("busy", "A permission request is already open.", null); return }
        pendingPermission = result; permissionKind = kind
        if (kind == "calendar") activity.getSharedPreferences("plancast_permission", Context.MODE_PRIVATE).edit().putBoolean("asked", true).apply()
        activity.requestPermissions(arrayOf(permission), 7031)
    }
    fun permissionResult(requestCode: Int) {
        if (requestCode != 7031) return
        pendingPermission?.success(if (permissionKind == "calendar") permission() else notificationPermission()); pendingPermission = null
    }
    private fun observe() {
        if (observer != null || !PlanCastNative.calendarAllowed(activity)) return
        observer = object : ContentObserver(main) {
            override fun onChange(selfChange: Boolean) {
                main.removeCallbacks(changeSignal); main.postDelayed(changeSignal, 700)
            }
        }
        activity.contentResolver.registerContentObserver(CalendarContract.CONTENT_URI, true, observer!!)
    }
    private fun stopObserving() { observer?.let { activity.contentResolver.unregisterContentObserver(it) }; observer = null; main.removeCallbacks(changeSignal) }
    fun pause() { cancelSpeech() }
    fun resume() {
        if (!PlanCastNative.calendarAllowed(activity)) { stopObserving(); cancelSpeech() }
        PlanCastNative.executor.execute { runCatching { PlanCastNative.maintain(activity) } }
    }
    fun acceptIntent(intent: Intent?) {
        val value = intent?.getStringExtra("plancast_route") ?: return
        if (PlanCastNative.validRoute(value)) { route = value; sink?.success("notificationOpened") }
        intent.removeExtra("plancast_route")
    }
    private fun offlineVoice(): Voice? = tts?.voices?.filter { !it.isNetworkConnectionRequired && !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) && it.locale.language == Locale.getDefault().language }?.sortedByDescending { it.quality }?.firstOrNull()
    private fun cancelSpeech() {
        speechGeneration++
        tts?.stop()
        // Release queued private utterances even if the engine never initializes.
        val waiters = speechWaiters.toList()
        speechWaiters.clear()
        waiters.forEach { it(false) }
    }
    private fun initializeSpeech(done: (Boolean) -> Unit) {
        if (disposed) { done(false); return }
        if (tts != null) { if (ttsReady) done(true) else speechWaiters.add(done); return }
        speechWaiters.add(done)
        tts = TextToSpeech(activity.applicationContext) { status ->
            main.post { ttsReady = !disposed && status == TextToSpeech.SUCCESS; val waiters = speechWaiters.toList(); speechWaiters.clear(); waiters.forEach { it(ttsReady) }; if (!ttsReady) { tts?.shutdown(); tts = null } }
        }
    }
    fun dispose() { disposed = true; stopObserving(); cancelSpeech(); tts?.shutdown(); tts = null; val waiters = speechWaiters.toList(); speechWaiters.clear(); waiters.forEach { it(false) }; pendingPermission?.error("cancelled", "The activity closed.", null); pendingPermission = null }
}

internal object PlanCastNative {
    val executor = Executors.newSingleThreadExecutor()
    const val CHANNEL = "plancast"
    private const val JOB = 0x504c414e
    private const val DAY = 86400000L
    fun calendarAllowed(context: Context) = context.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
    private fun notificationsAllowed(context: Context): Boolean = (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) && context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    fun validRoute(route: String) = route.matches(Regex("/plancast(?:\\?(?:event|day)=[A-Za-z0-9_-]{1,128})?"))
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("plancast.v1", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("plancast.v1", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    fun write(context: Context, name: String, value: String) {
        // Runs on the native serial executor. Recheck around persistence so a
        // revoked grant cannot recreate preferences or a pending notice queue.
        checkPermission(context)
        require(value.length <= 1048576)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val bytes = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val atomic = AtomicFile(File(context.noBackupFilesDir, "plancast_$name")); val stream = atomic.startWrite()
        try { stream.write(bytes); atomic.finishWrite(stream) } catch (e: Exception) { atomic.failWrite(stream); throw e }
        checkPermission(context)
    }
    fun read(context: Context, name: String): String? {
        val file = AtomicFile(File(context.noBackupFilesDir, "plancast_$name"))
        val bytes = try { file.readFully() } catch (_: FileNotFoundException) { return null }; require(bytes.size >= 28)
        return Cipher.getInstance("AES/GCM/NoPadding").run { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12))); String(doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8) }
    }
    fun calendars(context: Context): List<Map<String, Any?>> {
        checkPermission(context)
        val rows = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(CalendarContract.Calendars.CONTENT_URI, arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, CalendarContract.Calendars.CALENDAR_COLOR, CalendarContract.Calendars.ACCOUNT_NAME), "visible = 1", null, "calendar_displayName ASC")?.use { cursor ->
            while (cursor.moveToNext()) rows.add(mapOf("id" to cursor.getLong(0).toString(), "name" to (cursor.getString(1) ?: "Calendar"), "colorArgb" to (if (cursor.isNull(2)) null else cursor.getInt(2).toLong() and 0xffffffffL), "accountName" to cursor.getString(3)?.trim()?.takeIf { it.isNotEmpty() }))
        }
        return rows
    }
    private fun checkPermission(context: Context) { if (!calendarAllowed(context)) { purge(context); throw SecurityException() } }
    fun events(context: Context, ids: List<String>, start: Long, end: Long): List<Map<String, Any?>> {
        checkPermission(context); require(end > start && end - start <= 16 * DAY && ids.size <= 200)
        if (ids.isEmpty()) return emptyList()
        val selected = ids.mapNotNull { it.toLongOrNull() }; if (selected.isEmpty()) return emptyList()
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon(); ContentUris.appendId(builder, start); ContentUris.appendId(builder, end)
        val columns = arrayOf("event_id", "calendar_id", "title", "begin", "end", "allDay", "eventTimezone", "eventLocation", "eventStatus", "selfAttendeeStatus", "original_id", "originalInstanceTime", "rrule", "rdate")
        val selection = "calendar_id IN (${selected.joinToString(",") { "?" }}) AND (eventStatus IS NULL OR eventStatus != ?) AND (selfAttendeeStatus IS NULL OR selfAttendeeStatus != ?) AND deleted = 0"
        val args = selected.map { it.toString() } + CalendarContract.Events.STATUS_CANCELED.toString() + CalendarContract.Attendees.ATTENDEE_STATUS_DECLINED.toString()
        val result = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(builder.build(), columns, selection, args.toTypedArray(), "begin ASC")?.use { cursor ->
            while (cursor.moveToNext()) {
                val begin = cursor.getLong(3); val finish = cursor.getLong(4)
                if (finish <= start || begin >= end) continue
                val allDay = cursor.getInt(5) != 0
                val detached = !cursor.isNull(10)
                val recurring = detached || !cursor.getString(12).isNullOrBlank() || !cursor.getString(13).isNullOrBlank()
                val series = if (detached) cursor.getLong(10).toString() else cursor.getLong(0).toString()
                val original = if (cursor.isNull(11)) begin else cursor.getLong(11)
                val row = mutableMapOf<String, Any?>("id" to "${series}_$original", "nativeEventId" to cursor.getLong(0).toString(), "calendarId" to cursor.getLong(1).toString(), "title" to (cursor.getString(2) ?: "Calendar event"), "startMs" to begin, "endMs" to finish, "isAllDay" to allDay, "timeZone" to (cursor.getString(6) ?: TimeZone.getDefault().id), "location" to (cursor.getString(7) ?: ""), "status" to if (cursor.getInt(8) == CalendarContract.Events.STATUS_TENTATIVE || cursor.getInt(9) == CalendarContract.Attendees.ATTENDEE_STATUS_TENTATIVE) "tentative" else "confirmed", "isRecurring" to recurring, "isDetached" to detached, "originalStartMs" to original)
                if (recurring) row["recurringId"] = series
                supportedMapUrl(cursor.getString(7))?.let { row["mapUrl"] = it }
                // Android all-day DTSTART/DTEND are UTC dates with an exclusive end.
                if (allDay) { val format = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }; row["allDayStart"] = format.format(Date(begin)); row["allDayEnd"] = format.format(Date(finish)) }
                val signature = listOf(row["title"], row["location"], row["mapUrl"], begin, finish, original, allDay, row["timeZone"], row["status"], row["recurringId"], recurring, detached).joinToString("\u001f")
                row["nativeFingerprint"] = MessageDigest.getInstance("SHA-256").digest(signature.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
                result.add(row)
            }
        }
        return result.distinctBy { "${it["calendarId"]}/${it["id"]}" }
    }
    private fun supportedMapUrl(value: String?): String? {
        val raw = value?.trim() ?: return null
        if (raw.length > 2048) return null
        val uri = Uri.parse(raw)
        if (uri.userInfo != null) return null
        if (uri.scheme?.lowercase(Locale.ROOT) == "geo") return raw
        if (uri.scheme?.lowercase(Locale.ROOT) !in setOf("https", "http")) return null
        val host = uri.host?.lowercase(Locale.ROOT) ?: return null
        val supported = host in setOf("maps.apple.com", "maps.google.com", "openstreetmap.org", "www.openstreetmap.org") ||
            (host in setOf("google.com", "www.google.com") && (uri.path == "/maps" || uri.path?.startsWith("/maps/") == true))
        return if (supported) raw else null
    }
    private fun queue(context: Context): JSONArray {
        val rows = read(context, "queue")?.let { JSONArray(it) } ?: JSONArray()
        // Idempotent display-copy upgrade for our exact old generic invitation.
        // Preserve reminder IDs, delivery times, event content and permissions.
        for (i in 0 until rows.length()) {
            val notice = rows.getJSONObject(i)
            if (!notice.has("nativeEventId") && !notice.optBoolean("detailed") && notice.optString("body") == "Your plans. The sky’s opinion. Open PlanCast to refresh your day.") {
                notice.put("body", "Weather for your plans. Open PlanCast to refresh your day.")
            }
        }
        return rows
    }
    private fun pending(context: Context, id: String): PendingIntent = PendingIntent.getBroadcast(context, 0, Intent(context, PlanCastReceiver::class.java).setAction("plancast.deliver").setData(Uri.parse("plancast://notice/$id")), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancelQueue(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val old = runCatching { queue(context) }.getOrDefault(JSONArray())
        for (i in 0 until old.length()) alarm.cancel(pending(context, old.getJSONObject(i).optString("id")))
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.activeNotifications.filter { it.tag?.startsWith("plancast.") == true }.forEach { manager.cancel(it.tag, it.id) }
        AtomicFile(File(context.noBackupFilesDir, "plancast_queue")).delete()
    }
    fun purge(context: Context) {
        cancelQueue(context); context.getSystemService(JobScheduler::class.java).cancel(JOB)
        AtomicFile(File(context.noBackupFilesDir, "plancast_preferences")).delete()
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }; if (store.containsAlias("plancast.v1")) store.deleteEntry("plancast.v1")
    }
    fun replace(context: Context, requested: JSONArray) {
        cancelQueue(context)
        if (!calendarAllowed(context)) { purge(context); return }
        if (!notificationsAllowed(context)) { context.getSystemService(JobScheduler::class.java).cancel(JOB); return }
        val now = System.currentTimeMillis(); val result = JSONArray(); val seen = mutableSetOf<String>()
        val rows = (0 until requested.length()).map { requested.getJSONObject(it) }.sortedBy { it.optLong("fireAtMs") }
        for (notice in rows) {
            val id = notice.optString("id"); val fire = notice.optLong("fireAtMs")
            if (result.length() >= 32 || !id.matches(Regex("[A-Za-z0-9_-]{1,128}")) || !seen.add(id) || !validRoute(notice.optString("route")) || fire <= now || fire > now + 7 * DAY) continue
            if (notice.optLong("expiresAtMs", fire + 3600000) < fire) continue
            if (notice.optBoolean("detailed") && !fresh(notice, fire)) generic(notice)
            notice.put("scheduledTimeZone", TimeZone.getDefault().id)
            // Briefing notices stay at the chosen wall clock when timezone changes.
            if (!notice.has("nativeEventId")) notice.put("wallClock", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date(fire)))
            result.put(notice)
        }
        write(context, "queue", result.toString()); schedule(context, result)
        if (result.length() > 0) context.getSystemService(JobScheduler::class.java).schedule(JobInfo.Builder(JOB, ComponentName(context, PlanCastMaintenanceService::class.java)).setPersisted(true).setPeriodic(6 * 3600000L).build())
        else context.getSystemService(JobScheduler::class.java).cancel(JOB)
    }
    private fun fresh(n: JSONObject, time: Long): Boolean = n.optLong("forecastUpdatedAtMs") > 0 && n.optLong("calendarSyncedAtMs") > 0 && time - n.optLong("forecastUpdatedAtMs") in 0..21600000 && time - n.optLong("calendarSyncedAtMs") in 0..21600000 && time <= n.optLong("expiresAtMs")
    private fun generic(n: JSONObject) { n.put("title", "PlanCast"); n.put("body", "Open PlanCast for your plans and the latest available weather."); n.put("detailed", false) }
    private fun schedule(context: Context, notices: JSONArray) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (i in 0 until notices.length()) { checkPermission(context); val n = notices.getJSONObject(i); alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, maxOf(n.getLong("fireAtMs"), System.currentTimeMillis() + 1000), pending(context, n.getString("id"))) }
        checkPermission(context)
    }
    private fun eventValid(context: Context, notice: JSONObject): Boolean {
        if (!notice.has("nativeEventId") || !notice.has("nativeCalendarId") || !notice.has("nativeStartMs")) return true
        val start = notice.getLong("nativeStartMs")
        return events(context, listOf(notice.getString("nativeCalendarId")), start - 1, start + 1).any { (it["nativeEventId"] == notice.getString("nativeEventId") || it["id"] == notice.getString("nativeEventId")) && it["startMs"] == start && (!notice.has("nativeFingerprint") || it["nativeFingerprint"] == notice.getString("nativeFingerprint")) }
    }
    private fun hasStoredFile(context: Context, name: String): Boolean = listOf("", ".bak", ".new").any { File(context.noBackupFilesDir, "plancast_$name$it").exists() }
    fun maintain(context: Context, timezoneChanged: Boolean = false) {
        if (!hasStoredFile(context, "queue") && !hasStoredFile(context, "preferences")) return
        if (!calendarAllowed(context)) { purge(context); return }
        if (!notificationsAllowed(context)) { cancelQueue(context); context.getSystemService(JobScheduler::class.java).cancel(JOB); return }
        val old = queue(context); val now = System.currentTimeMillis(); val kept = JSONArray()
        val alarm = context.getSystemService(AlarmManager::class.java)
        for (i in 0 until old.length()) {
            val n = old.getJSONObject(i); alarm.cancel(pending(context, n.getString("id")))
            val currentZone = TimeZone.getDefault().id
            if ((timezoneChanged || n.optString("scheduledTimeZone", currentZone) != currentZone) && n.has("wallClock")) {
                val oldFire = n.optLong("fireAtMs")
                val newFire = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).parse(n.getString("wallClock"))?.time ?: oldFire
                n.put("fireAtMs", newFire); n.put("expiresAtMs", n.optLong("expiresAtMs") + newFire - oldFire); generic(n)
            }
            n.put("scheduledTimeZone", currentZone)
            // Inexact alarms can be pending after their requested time. Do not
            // erase an unexpired notice just because maintenance ran first.
            if (n.optLong("expiresAtMs", Long.MAX_VALUE) <= now || (n.has("nativeStartMs") && now >= n.getLong("nativeStartMs")) || !eventValid(context, n)) continue
            if (n.optBoolean("detailed") && !fresh(n, maxOf(now, n.getLong("fireAtMs")))) generic(n)
            kept.put(n)
        }
        write(context, "queue", kept.toString()); schedule(context, kept)
        if (kept.length() == 0) context.getSystemService(JobScheduler::class.java).cancel(JOB)
    }
    fun deliver(context: Context, id: String) {
        if (!calendarAllowed(context)) { purge(context); return }
        val old = queue(context); val kept = JSONArray(); var notice: JSONObject? = null
        for (i in 0 until old.length()) { val n = old.getJSONObject(i); if (n.optString("id") == id) notice = n else kept.put(n) }
        write(context, "queue", kept.toString()) // Consume once, including denial/failure.
        val n = notice ?: return; val now = System.currentTimeMillis()
        if (now >= n.optLong("expiresAtMs", 0) || (n.has("nativeStartMs") && now >= n.getLong("nativeStartMs")) || !eventValid(context, n)) return
        if (n.optBoolean("detailed") && !fresh(n, now)) generic(n)
        // AlarmManager is inexact: a permitted planned time can arrive during
        // quiet hours. Consume silently rather than waking the user late.
        val local = Calendar.getInstance().apply { timeInMillis = now }
        val minute = local.get(Calendar.HOUR_OF_DAY) * 60 + local.get(Calendar.MINUTE)
        val quietStart = n.optInt("quietStartMinute", 1320).coerceIn(0, 1439)
        val quietEnd = n.optInt("quietEndMinute", 420).coerceIn(0, 1439)
        val quiet = if (quietStart == quietEnd) false else if (quietStart < quietEnd) minute >= quietStart && minute < quietEnd else minute >= quietStart || minute < quietEnd
        if (quiet) return
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "PlanCast", NotificationManager.IMPORTANCE_DEFAULT).apply { description = "Optional briefings and event weather heads-ups"; lockscreenVisibility = Notification.VISIBILITY_PRIVATE })
        val intent = Intent(context, MainActivity::class.java).setAction("plancast.open").setData(Uri.parse("plancast://open/$id")).putExtra("plancast_route", n.optString("route", "/plancast")).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val contentIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.mipmap.ic_launcher).setContentTitle(n.optString("title", "PlanCast")).setContentText(n.optString("body")).setStyle(Notification.BigTextStyle().bigText(n.optString("body"))).setContentIntent(contentIntent).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build()
        manager.notify("plancast.$id", 1, notification)
    }
}

class PlanCastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val completion = goAsync()
        PlanCastNative.executor.execute {
            try { if (intent.action == "plancast.deliver") PlanCastNative.deliver(context, intent.data?.lastPathSegment ?: "") else PlanCastNative.maintain(context, intent.action == Intent.ACTION_TIMEZONE_CHANGED || intent.action == Intent.ACTION_TIME_CHANGED) }
            catch (_: SecurityException) { PlanCastNative.purge(context) }
            catch (_: Exception) { /* Retry on next foreground sync; no private log output. */ }
            finally { completion.finish() }
        }
    }
}

class PlanCastMaintenanceService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        PlanCastNative.executor.execute { val success = runCatching { PlanCastNative.maintain(this) }.isSuccess; jobFinished(params, !success) }
        return true
    }
    override fun onStopJob(params: JobParameters) = true
}
