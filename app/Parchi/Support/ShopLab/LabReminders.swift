import EventKit
import Foundation
import Observation
import ParchiCore
import UserNotifications

/// The saved home-collection address. Stays on this phone (UserDefaults); the server only gets it inside a booking.
/// Never store the patient's name or phone here.
@Observable
final class AddressStore {
    private static let key = "parchi.address"   // same key Settings writes
    var text: String { didSet { UserDefaults.standard.set(text, forKey: Self.key) } }
    init() { text = UserDefaults.standard.string(forKey: Self.key) ?? "" }
}

/// Calendar (write-only) and local-notification helpers for a confirmed lab slot.
enum LabReminders {
    /// Adds the slot to the default calendar. Needs `NSCalendarsWriteOnlyAccessUsageDescription`. Returns a plain-language result.
    static func addToCalendar(title: String, start: Date, notes: String, location: String?) async -> String {
        let store = EKEventStore()
        do {
            guard try await store.requestWriteOnlyAccessToEvents() else { return "Calendar access was not allowed. You can turn it on in Settings." }
            let event = EKEvent(eventStore: store)
            event.title = title
            event.startDate = start
            event.endDate = start.addingTimeInterval(30 * 60)
            event.notes = notes
            event.location = location
            guard let calendar = store.defaultCalendarForNewEvents else { return "No calendar on this phone to add to." }
            event.calendar = calendar
            try store.save(event, span: .thisEvent)
            return "Added to Calendar: \(ISOTime.slot(start))"
        } catch {
            return "Could not add to Calendar."
        }
    }

    /// Local notification at `fireAt`. In the Simulator it asks for quiet (provisional) permission so no system dialog blocks screenshots;
    /// on a phone it asks normally the first time.
    static func scheduleReminder(id: String, body: String, fireAt: Date) async -> String {
        guard fireAt > Date() else { return "Fasting reminder time (\(ISOTime.slot(fireAt))) has already passed." }
        let center = UNUserNotificationCenter.current()
        do {
            #if targetEnvironment(simulator)
            let options: UNAuthorizationOptions = [.alert, .sound, .provisional]
            #else
            let options: UNAuthorizationOptions = [.alert, .sound]
            #endif
            guard try await center.requestAuthorization(options: options) else { return "Notifications are off, so no reminder was set. You can turn them on in Settings." }
            let content = UNMutableNotificationContent()
            content.title = "Parchi: lab tomorrow"
            content.body = body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try await center.add(UNNotificationRequest(identifier: "parchi.lab.fasting.\(id)", content: content, trigger: trigger))
            return "Fasting reminder set for \(ISOTime.slot(fireAt))"
        } catch {
            return "Could not set the reminder."
        }
    }
}
