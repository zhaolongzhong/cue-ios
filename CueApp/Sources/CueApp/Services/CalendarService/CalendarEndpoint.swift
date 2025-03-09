//
//  CalendarEndpoint.swift
//  CueApp
//

import Foundation

enum CalendarEndpoint {
    case listCalendars
    case listEvents(calendarId: String, maxResults: Int = 10)
    case getEvent(calendarId: String, eventId: String)
    case createEvent(calendarId: String, summary: String, description: String, startDateTime: Date, endDateTime: Date)
    case updateEvent(calendarId: String, eventId: String, summary: String?, description: String?, startDateTime: Date?, endDateTime: Date?)
    case deleteEvent(calendarId: String, eventId: String)
}

extension CalendarEndpoint: Endpoint {
    var baseURL: String {
        return "https://www.googleapis.com"
    }

    var path: String {
        switch self {
        case .listCalendars:
            return "/calendar/v3/users/me/calendarList"
        case .listEvents(let calendarId, _):
            return "/calendar/v3/calendars/\(calendarId)/events"
        case .getEvent(let calendarId, let eventId):
            return "/calendar/v3/calendars/\(calendarId)/events/\(eventId)"
        case .createEvent(let calendarId, _, _, _, _):
            return "/calendar/v3/calendars/\(calendarId)/events"
        case .updateEvent(let calendarId, let eventId, _, _, _, _):
            return "/calendar/v3/calendars/\(calendarId)/events/\(eventId)"
        case .deleteEvent(let calendarId, let eventId):
            return "/calendar/v3/calendars/\(calendarId)/events/\(eventId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listCalendars, .listEvents, .getEvent:
            return .get
        case .createEvent:
            return .post
        case .updateEvent:
            return .patch
        case .deleteEvent:
            return .delete
        }
    }

    var headers: [String: String]? {
        return [
            "Content-Type": "application/json"
        ]
    }

    var queryParameters: [String: String]? {
        switch self {
        case .listEvents(_, let maxResults):
            return ["maxResults": String(maxResults)]
        default:
            return nil
        }
    }

    var body: Data? {
        switch self {
        case .createEvent(_, let summary, let description, let startDateTime, let endDateTime):
            let event: [String: Any] = [
                "summary": summary,
                "description": description,
                "start": [
                    "dateTime": ISO8601DateFormatter().string(from: startDateTime)
                ],
                "end": [
                    "dateTime": ISO8601DateFormatter().string(from: endDateTime)
                ]
            ]
            return try? JSONSerialization.data(withJSONObject: event)

        case .updateEvent(_, _, let summary, let description, let startDateTime, let endDateTime):
            var event: [String: Any] = [:]

            if let summary = summary {
                event["summary"] = summary
            }

            if let description = description {
                event["description"] = description
            }

            if let startDateTime = startDateTime {
                event["start"] = [
                    "dateTime": ISO8601DateFormatter().string(from: startDateTime)
                ]
            }

            if let endDateTime = endDateTime {
                event["end"] = [
                    "dateTime": ISO8601DateFormatter().string(from: endDateTime)
                ]
            }

            return try? JSONSerialization.data(withJSONObject: event)

        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        return true
    }
}
