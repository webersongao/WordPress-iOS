import Foundation
import TracksMini

/// Characterizes the types of service extension events we're interested in tracking.
/// The raw value corresponds to the event name in Tracks.
///
/// - launched: the service extension was successfully entered & launched
/// - discarded: the service extension launched, but encountered an unsupported notification type
/// - failed: the service extension failed to retrieve the payload
/// - assembled: the service extension successfully prepared content
///
private enum ServiceExtensionEvents: String {
    case launched = "notification_service_extension_launched"
    case discarded = "notification_service_extension_discarded"
    case failed = "notification_service_extension_failed"
    case assembled = "notification_service_extension_assembled"
    case malformed = "notification_service_extension_malformed_payload"
    case timedOut = "notification_service_extension_timed_out"
}

// MARK: - Supports tracking notification service extension events.

extension Tracks {
    /// Tracks the successful launch of the notification service extension.
    ///
    /// - Parameter wpcomAvailable: `true` if an OAuth token exists, `false` otherwise
    func trackExtensionLaunched(_ wpcomAvailable: Bool) {
        let properties = [
            "is_configured_dotcom": wpcomAvailable
        ]
        trackEvent(ServiceExtensionEvents.launched, properties: properties as [String: AnyObject]?)
    }

    /// Tracks that a notification type was discarded due to lack of support.
    /// It will still be delivered as before, but not as a rich notification.
    ///
    /// - Parameter notificationType: the value of the `note_id` from the APNS payload
    func trackNotificationDiscarded(notificationType: String) {
        let properties = [
            "type": notificationType
        ]
        trackEvent(ServiceExtensionEvents.discarded, properties: properties as [String: AnyObject]?)
    }

    /// Tracks the failure to retrieve a notification via the REST API.
    ///
    /// - Parameters:
    ///   - notificationIdentifier: the value of the `note_id` from the APNS payload
    ///   - errorDescription: description of the error encountered, ideally localized
    func trackNotificationRetrievalFailed(notificationIdentifier: String, errorDescription: String) {
        let properties = [
            "note_id": notificationIdentifier,
            "error": errorDescription
        ]
        trackEvent(ServiceExtensionEvents.failed, properties: properties as [String: AnyObject]?)
    }

    /// Tracks the successful retrieval & assembly of a rich notification.
    func trackNotificationAssembled() {
        trackEvent(ServiceExtensionEvents.assembled)
    }

    /// Tracks the unsuccessful unwrapping of push notification payload data.
    func trackNotificationMalformed(hasToken: Bool, notificationBody: String) {
        let properties: [String: AnyObject] = [
            "have_token": hasToken as AnyObject,
            "content": notificationBody as AnyObject
        ]

        trackEvent(ServiceExtensionEvents.malformed, properties: properties)
    }

    /// Tracks the timeout of service extension processing.
    func trackNotificationTimedOut() {
        trackEvent(ServiceExtensionEvents.timedOut)
    }

    /// Utility method to capture an event & submit it to Tracks.
    ///
    /// - Parameters:
    ///   - event: the event to track
    ///   - properties: any accompanying metadata
    private func trackEvent(_ event: ServiceExtensionEvents, properties: [String: AnyObject]? = nil) {
        track(event.rawValue, properties: properties)
    }
}
