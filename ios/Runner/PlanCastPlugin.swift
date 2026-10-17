import Flutter
import UIKit
import EventKit
import UserNotifications
import BackgroundTasks
import AVFAudio
import CryptoKit

/// Native read-only device calendars and local-only services. Never serializes
/// descriptions, attendees, attachments or meeting URLs. Calendar source titles
/// are displayed locally to distinguish calendars; they are never uploaded.
final class PlanCastPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static weak var active: PlanCastPlugin?
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var pendingChange: DispatchWorkItem?
  private let synthesizer = AVSpeechSynthesizer()
  private var route: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = PlanCastPlugin()
    active = plugin
    let channel = FlutterMethodChannel(name: "grumpy_skies/plancast", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
    FlutterEventChannel(name: "grumpy_skies/plancast/changes", binaryMessenger: registrar.messenger()).setStreamHandler(plugin)
    plugin.lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak plugin] _ in
      PlanCastNative.queue.async { try? PlanCastNative.maintain() }
      if PlanCastNative.permission() != "authorized" { plugin?.stopObserving(); plugin?.synthesizer.stopSpeaking(at: .immediate) }
    })
    plugin.lifecycleObservers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak plugin] _ in
      PlanCastNative.queue.async { try? PlanCastNative.maintain(timezoneChanged: true) }
      plugin?.sink?("timezoneChanged")
    })
  }
  static func registerBackgroundTask() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: PlanCastNative.backgroundID, using: nil) { task in
      let operation = BlockOperation { PlanCastNative.queue.sync { try? PlanCastNative.maintain(); PlanCastNative.scheduleMaintenance() } }
      operation.completionBlock = { [weak operation] in task.setTaskCompleted(success: operation?.isCancelled == false) }
      task.expirationHandler = { operation.cancel() }
      PlanCastNative.backgroundOperations.addOperation(operation)
    }
  }
  static func receive(_ response: UNNotificationResponse) -> Bool {
    let request = response.notification.request
    guard request.identifier.hasPrefix("plancast."), let route = request.content.userInfo["route"] as? String, PlanCastNative.validRoute(route) else { return false }
    // Flutter engine can initialize after the notification response is received.
    if let plugin = active { plugin.route = route; plugin.sink?("notificationOpened") }
    else { PlanCastNative.pendingRoute = route }
    return true
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
  private func work(_ result: @escaping FlutterResult, _ body: @escaping () throws -> Any?) {
    PlanCastNative.queue.async {
      do { let value = try body(); DispatchQueue.main.async { result(value) } }
      catch { DispatchQueue.main.async { result(FlutterError(code: "plancast_unavailable", message: "PlanCast could not complete this device operation.", details: nil)) } }
    }
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "calendarPermission": work(result) { if PlanCastNative.permission() != "authorized" { PlanCastNative.purge() }; return PlanCastNative.permission() }
    case "requestCalendarPermission":
      let completion: EKEventStoreRequestAccessCompletionHandler = { _, _ in DispatchQueue.main.async { result(PlanCastNative.permission()) } }
      if #available(iOS 17.0, *) { PlanCastNative.store.requestFullAccessToEvents(completion: completion) }
      else { PlanCastNative.store.requestAccess(to: .event, completion: completion) }
    case "calendars": work(result) { try PlanCastNative.calendars() }
    case "events": work(result) { try PlanCastNative.events(args) }
    case "startObserving": startObserving(); result(nil)
    case "stopObserving": stopObserving(); result(nil)
    case "secureRead": work(result) { try PlanCastNative.read("preferences") }
    case "secureWrite": work(result) { try PlanCastNative.write("preferences", args["value"] as? String ?? ""); return nil }
    case "secureDelete": work(result) { PlanCastNative.delete("preferences"); return nil }
    case "disconnect": stopObserving(); synthesizer.stopSpeaking(at: .immediate); work(result) { PlanCastNative.purge(); return nil }
    case "notificationPermission": notificationPermission(result)
    case "requestNotificationPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in self.notificationPermission(result) }
    case "replaceNotifications": work(result) { try PlanCastNative.replace(args["notices"] as? [[String: Any]] ?? []); return nil }
    case "speechStatus": result(offlineVoice() == nil ? "unavailable" : "available")
    case "speak":
      guard let voice = offlineVoice(), let text = args["text"] as? String else { result(false); return }
      synthesizer.stopSpeaking(at: .immediate)
      let utterance = AVSpeechUtterance(string: String(text.prefix(12000))); utterance.voice = voice
      synthesizer.speak(utterance); result(true)
    case "stopSpeaking": synthesizer.stopSpeaking(at: .immediate); result(nil)
    case "consumeNotificationRoute": result(route ?? PlanCastNative.pendingRoute); route = nil; PlanCastNative.pendingRoute = nil
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func notificationPermission(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let state: String
      switch settings.authorizationStatus { case .authorized, .provisional, .ephemeral: state = "authorized"; case .notDetermined: state = "notDetermined"; default: state = "denied" }
      DispatchQueue.main.async { result(state) }
    }
  }
  private func offlineVoice() -> AVSpeechSynthesisVoice? {
    let language = Locale(identifier: Locale.preferredLanguages.first ?? Locale.current.identifier).languageCode
    // Only installed Apple compact voices. No Personal Voice, third-party
    // extension, download, language fallback or remote speech synthesis.
    return AVSpeechSynthesisVoice.speechVoices().first {
      Locale(identifier: $0.language).languageCode == language &&
      ($0.identifier.hasPrefix("com.apple.voice.compact.") || ($0.identifier.hasPrefix("com.apple.ttsbundle.") && $0.identifier.hasSuffix("-compact")))
    }
  }
  private func startObserving() {
    guard observer == nil, PlanCastNative.permission() == "authorized" else { return }
    observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: PlanCastNative.store, queue: .main) { [weak self] _ in
      guard let self else { return }
      self.pendingChange?.cancel()
      let change = DispatchWorkItem { [weak self] in self?.sink?("calendarChanged"); PlanCastNative.queue.async { try? PlanCastNative.maintain() } }
      self.pendingChange = change; DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: change)
    }
  }
  private func stopObserving() { if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil; pendingChange?.cancel(); pendingChange = nil }
  deinit { stopObserving(); lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }; synthesizer.stopSpeaking(at: .immediate) }
}

private enum PlanCastNative {
  static let backgroundID = "com.grumpyskies.plancast.maintenance"
  static let queue = DispatchQueue(label: "grumpyskies.plancast", qos: .utility)
  static let backgroundOperations = OperationQueue()
  static let store = EKEventStore()
  static var pendingRoute: String?
  static func permission() -> String {
    let state = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) { if state == .fullAccess { return "authorized" }; if state == .writeOnly { return "writeOnly" } }
    else if state == .authorized { return "authorized" }
    switch state { case .notDetermined: return "notDetermined"; case .restricted: return "restricted"; default: return "denied" }
  }
  static func validRoute(_ value: String) -> Bool { value.range(of: #"^/plancast(?:\?(?:event|day)=[A-Za-z0-9_-]{1,128})?$"#, options: .regularExpression) != nil }
  static func requireAccess() throws { if permission() != "authorized" { purge(); throw NSError(domain: "PlanCastPermission", code: 1) } }
  static func calendars() throws -> [[String: Any]] {
    try requireAccess()
    return store.calendars(for: .event).map { calendar in
      var row: [String: Any] = ["id": calendar.calendarIdentifier, "name": calendar.title]
      let sourceTitle = calendar.source.title.trimmingCharacters(in: .whitespacesAndNewlines)
      if !sourceTitle.isEmpty { row["accountName"] = sourceTitle }
      if let cgColor = calendar.cgColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(cgColor: cgColor).getRed(&r, green: &g, blue: &b, alpha: &a) {
          func byte(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
          row["colorArgb"] = (byte(a) << 24) | (byte(r) << 16) | (byte(g) << 8) | byte(b)
        }
      }
      return row
    }
  }
  static func events(_ args: [String: Any]) throws -> [[String: Any]] {
    try requireAccess()
    guard let ids = args["calendarIds"] as? [String], ids.count <= 200, let startMs = args["startMs"] as? NSNumber, let endMs = args["endMs"] as? NSNumber else { throw NSError(domain: "PlanCastRange", code: 1) }
    let start = Date(timeIntervalSince1970: startMs.doubleValue / 1000), end = Date(timeIntervalSince1970: endMs.doubleValue / 1000)
    guard end > start, end.timeIntervalSince(start) <= 16 * 86400 else { throw NSError(domain: "PlanCastRange", code: 1) }
    let selected = store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
    guard !selected.isEmpty else { return [] }
    // EventKit's predicate expands occurrences and recurring exceptions, and
    // includes events overlapping the start (including already in progress).
    let found = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: selected))
    var seen = Set<String>()
    return found.sorted { $0.startDate < $1.startDate }.compactMap { event in
      guard event.status != .canceled, event.endDate > start, event.startDate < end else { return nil }
      // Read only the current user's response; never retain guest identities.
      let ownStatus = event.attendees?.first(where: { $0.isCurrentUser })?.participantStatus
      guard ownStatus != .declined else { return nil }
      let occurrence = event.occurrenceDate ?? event.startDate!
      let id = "\(event.calendarItemIdentifier)_\(Int64(occurrence.timeIntervalSince1970 * 1000))"
      guard seen.insert("\(event.calendar.calendarIdentifier)/\(id)").inserted else { return nil }
      let zone = event.timeZone ?? TimeZone.current
      let recurring = event.hasRecurrenceRules || event.isDetached || event.occurrenceDate != nil
      let location = (event.location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? event.location : event.structuredLocation?.title) ?? ""
      var row: [String: Any] = ["id": id, "nativeEventId": event.eventIdentifier ?? id, "calendarId": event.calendar.calendarIdentifier, "title": event.title ?? "Calendar event", "startMs": Int64(event.startDate.timeIntervalSince1970 * 1000), "endMs": Int64(event.endDate.timeIntervalSince1970 * 1000), "isAllDay": event.isAllDay, "timeZone": zone.identifier, "location": location, "status": event.status == .tentative || ownStatus == .tentative ? "tentative" : "confirmed", "isRecurring": recurring, "isDetached": event.isDetached, "originalStartMs": Int64(occurrence.timeIntervalSince1970 * 1000)]
      // Migration only: old saved venue choices used this ID and raw location.
      // Keep them separate from the corrected cross-occurrence series identity.
      row["legacyRecurringId"] = event.calendarItemIdentifier
      row["legacyLocation"] = event.location ?? ""
      if recurring {
        // Apple's external ID is shared by recurring occurrences and detached
        // exceptions. Scope it to the calendar and keep the server ID opaque.
        let externalSeries: String? = event.calendarItemExternalIdentifier
        let series = externalSeries.flatMap { $0.isEmpty ? nil : $0 } ?? event.calendarItemIdentifier
        row["recurringId"] = SHA256.hash(data: Data("\(event.calendar.calendarIdentifier)|\(series)".utf8)).map { String(format: "%02x", $0) }.joined()
      }
      // Only supported map metadata crosses the bridge. Never fetch event URLs
      // or expose arbitrary meeting URLs, descriptions or guest information.
      if let mapURL = supportedMapURL(event.url?.absoluteString) ?? supportedMapURL(location) { row["mapUrl"] = mapURL }
      if let coordinate = event.structuredLocation?.geoLocation?.coordinate { row["latitude"] = coordinate.latitude; row["longitude"] = coordinate.longitude }
      if event.isAllDay {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = zone; formatter.dateFormat = "yyyy-MM-dd"
        row["allDayStart"] = formatter.string(from: event.startDate); row["allDayEnd"] = formatter.string(from: event.endDate)
      }
      let signature = ["title", "location", "mapUrl", "startMs", "endMs", "originalStartMs", "isAllDay", "timeZone", "status", "latitude", "longitude", "recurringId", "isRecurring", "isDetached", "legacyRecurringId", "legacyLocation"].map { String(describing: row[$0] ?? "") }.joined(separator: "\u{001f}")
      row["nativeFingerprint"] = SHA256.hash(data: Data(signature.utf8)).map { String(format: "%02x", $0) }.joined()
      return row
    }
  }
  static func supportedMapURL(_ value: String?) -> String? {
    guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), raw.count <= 2048,
          let url = URLComponents(string: raw), url.user == nil, url.password == nil else { return nil }
    if url.scheme?.lowercased() == "geo" { return raw }
    guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host?.lowercased() else { return nil }
    let supported = ["maps.apple.com", "maps.google.com", "openstreetmap.org", "www.openstreetmap.org"].contains(host) ||
      (["google.com", "www.google.com"].contains(host) && (url.path == "/maps" || url.path.hasPrefix("/maps/")))
    return supported ? raw : nil
  }
  static func directory() throws -> URL {
    var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PlanCast", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    var values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
    return directory
  }
  static func write(_ name: String, _ value: String) throws {
    // Recheck on the native serial queue, not only before Dart enqueues work.
    // A revoked grant must not recreate preferences or a pending notice queue.
    try requireAccess()
    guard let data = value.data(using: .utf8), data.count <= 1048576 else { throw NSError(domain: "PlanCastStorage", code: 1) }
    let file = try directory().appendingPathComponent(name)
    try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    try requireAccess()
  }
  static func read(_ name: String) throws -> String? {
    let file = try directory().appendingPathComponent(name)
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    return try String(contentsOf: file, encoding: .utf8)
  }
  static func delete(_ name: String) { if let folder = try? directory() { try? FileManager.default.removeItem(at: folder.appendingPathComponent(name)) } }
  static func pending() -> [UNNotificationRequest] {
    let semaphore = DispatchSemaphore(value: 0); var result: [UNNotificationRequest] = []
    UNUserNotificationCenter.current().getPendingNotificationRequests { result = $0; semaphore.signal() }
    _ = semaphore.wait(timeout: .now() + 5); return result
  }
  static func purge() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: pending().filter { $0.identifier.hasPrefix("plancast.") }.map(\.identifier))
    let semaphore = DispatchSemaphore(value: 0)
    center.getDeliveredNotifications { center.removeDeliveredNotifications(withIdentifiers: $0.filter { $0.request.identifier.hasPrefix("plancast.") }.map { $0.request.identifier }); semaphore.signal() }
    _ = semaphore.wait(timeout: .now() + 5)
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundID)
    delete("preferences"); delete("queue")
  }
  static func notificationsAllowed() -> Bool {
    let semaphore = DispatchSemaphore(value: 0); var allowed = false
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      if #available(iOS 14.0, *) { allowed = allowed || settings.authorizationStatus == .ephemeral }
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 5); return allowed
  }
  static func number(_ n: [String: Any], _ key: String) -> Double { (n[key] as? NSNumber)?.doubleValue ?? 0 }
  static func fresh(_ n: [String: Any], at time: Double) -> Bool {
    let forecast = number(n, "forecastUpdatedAtMs"), synced = number(n, "calendarSyncedAtMs")
    return forecast > 0 && synced > 0 && time >= forecast && time - forecast <= 21600000 && time >= synced && time - synced <= 21600000 && time <= number(n, "expiresAtMs")
  }
  static func generic(_ n: inout [String: Any]) { n["title"] = "PlanCast"; n["body"] = "Open PlanCast for your plans and the latest available weather."; n["detailed"] = false }
  static func savedQueue() throws -> [[String: Any]] {
    guard let raw = try read("queue"), let data = raw.data(using: .utf8) else { return [] }
    return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
  }
  static func saveQueue(_ rows: [[String: Any]]) throws { let data = try JSONSerialization.data(withJSONObject: rows); try write("queue", String(decoding: data, as: UTF8.self)) }
  static func replace(_ requested: [[String: Any]]) throws {
    let center = UNUserNotificationCenter.current(), pending = pending()
    let ours = pending.filter { $0.identifier.hasPrefix("plancast.") }; center.removePendingNotificationRequests(withIdentifiers: ours.map(\.identifier))
    // Reserve 8 slots for other app features, within iOS's total pending budget.
    let budget = max(0, min(32, 56 - (pending.count - ours.count)))
    try requireAccess()
    guard notificationsAllowed() else { delete("queue"); BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundID); return }
    let now = Date().timeIntervalSince1970 * 1000
    var seen = Set<String>(), kept: [[String: Any]] = []
    for var n in requested.sorted(by: { number($0, "fireAtMs") < number($1, "fireAtMs") }) {
      guard kept.count < budget, let id = n["id"] as? String, id.range(of: #"^[A-Za-z0-9_-]{1,128}$"#, options: .regularExpression) != nil, seen.insert(id).inserted, let route = n["route"] as? String, validRoute(route) else { continue }
      let fire = number(n, "fireAtMs")
      guard fire > now, fire <= now + 7 * 86400000, number(n, "expiresAtMs") >= fire else { continue }
      if n["detailed"] as? Bool == true && !fresh(n, at: fire) { generic(&n) }
      n["scheduledTimeZone"] = TimeZone.current.identifier
      if n["nativeEventId"] == nil {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        n["wallClock"] = formatter.string(from: Date(timeIntervalSince1970: fire / 1000))
      }
      kept.append(n)
    }
    try saveQueue(kept)
    try schedule(kept)
    if kept.isEmpty { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundID) } else { scheduleMaintenance() }
  }
  static func schedule(_ rows: [[String: Any]]) throws {
    for n in rows {
      try requireAccess()
      guard let id = n["id"] as? String, let route = n["route"] as? String else { continue }
      let content = UNMutableNotificationContent(); content.title = n["title"] as? String ?? "PlanCast"; content.body = n["body"] as? String ?? "Open PlanCast for the latest available weather."; content.sound = .default
      content.userInfo = ["route": route]; content.threadIdentifier = "plancast"; content.categoryIdentifier = "plancast"
      let date = Date(timeIntervalSince1970: number(n, "fireAtMs") / 1000)
      var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
      var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date); components.timeZone = calendar.timeZone
      let request = UNNotificationRequest(identifier: "plancast.\(id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
      let semaphore = DispatchSemaphore(value: 0); var schedulingError: Error?
      UNUserNotificationCenter.current().add(request) { schedulingError = $0; semaphore.signal() }
      if semaphore.wait(timeout: .now() + 5) == .timedOut { throw NSError(domain: "PlanCastNotification", code: 1) }
      if let schedulingError { throw schedulingError }
    }
    try requireAccess()
  }
  static func eventValid(_ n: [String: Any]) throws -> Bool {
    guard let id = n["nativeEventId"] as? String, let calendar = n["nativeCalendarId"] as? String, let start = n["nativeStartMs"] as? NSNumber else { return true }
    let rows = try events(["calendarIds": [calendar], "startMs": start.doubleValue - 1, "endMs": start.doubleValue + 1])
    return rows.contains { ($0["nativeEventId"] as? String == id || $0["id"] as? String == id) && number($0, "startMs") == start.doubleValue && (n["nativeFingerprint"] == nil || $0["nativeFingerprint"] as? String == n["nativeFingerprint"] as? String) }
  }
  static func maintain(timezoneChanged: Bool = false) throws {
    // No fresh weather is claimed here. OS background opportunities only prune
    // invalid calendar instances and stale queue entries; foreground refresh
    // recomputes weather and briefing content.
    if permission() != "authorized" { purge(); return }
    guard notificationsAllowed() else {
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pending().filter { $0.identifier.hasPrefix("plancast.") }.map(\.identifier))
      delete("queue"); BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundID); return
    }
    let rows = try savedQueue(); guard !rows.isEmpty else { return }; let now = Date().timeIntervalSince1970 * 1000
    var kept: [[String: Any]] = []
    for var n in rows {
      let currentZone = TimeZone.current.identifier
      if timezoneChanged || (n["scheduledTimeZone"] as? String ?? currentZone) != currentZone, let wallClock = n["wallClock"] as? String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: wallClock) { let old = number(n, "fireAtMs"); let fire = date.timeIntervalSince1970 * 1000; n["fireAtMs"] = fire; n["expiresAtMs"] = number(n, "expiresAtMs") + fire - old; generic(&n) }
      }
      n["scheduledTimeZone"] = currentZone
      guard number(n, "fireAtMs") > now, number(n, "expiresAtMs") >= now, try eventValid(n) else { continue }
      if n["detailed"] as? Bool == true && !fresh(n, at: number(n, "fireAtMs")) { generic(&n) }
      kept.append(n)
    }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: rows.compactMap { ($0["id"] as? String).map { "plancast.\($0)" } })
    try saveQueue(kept); try schedule(kept)
    if kept.isEmpty { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundID) }
  }
  static func scheduleMaintenance() {
    guard permission() == "authorized", ((try? savedQueue().isEmpty) == false) else { return }
    let request = BGAppRefreshTaskRequest(identifier: backgroundID); request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
    try? BGTaskScheduler.shared.submit(request)
  }
}
