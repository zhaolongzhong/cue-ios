//
//  CalendarTool.swift
//  CueApp
//

import Foundation
import GoogleSignIn
import CueOpenAI

// MARK: - Tool Definition

struct CalendarParameters: ToolParameters, Sendable {
    let schema: [String: Property] = [
        "action": Property(
            type: "string",
            description: "Action: listCalendars, listEvents, getEvent, createEvent, updateEvent, deleteEvent"
        ),
        "calendarId": Property(
            type: "string",
            description: "Calendar ID (required for all actions except listCalendars)"
        ),
        "eventId": Property(
            type: "string",
            description: "Event ID (required for getEvent, updateEvent, and deleteEvent)"
        ),
        "maxResults": Property(
            type: "integer",
            description: "Max events to return (for listEvents only), default is 10"
        ),
        "summary": Property(
            type: "string",
            description: "Event summary/title (for createEvent and updateEvent)"
        ),
        "description": Property(
            type: "string",
            description: "Event description (for createEvent and updateEvent)"
        ),
        "startDateTime": Property(
            type: "string",
            description: "Event start date and time in ISO 8601 format (for createEvent and updateEvent)"
        ),
        "endDateTime": Property(
            type: "string",
            description: "Event end date and time in ISO 8601 format (for createEvent and updateEvent)"
        )
    ]

    let required: [String] = ["action"]
}

struct CalendarTool: LocalTool, Sendable {
    let name: String = "manage_calendar"
    let description: String = "Manage Google Calendar: list calendars, create, read, update, and delete events."
    let parameterDefinition: ToolParameters = CalendarParameters()

    func call(_ args: ToolArguments) async throws -> String {
        guard let action = args.getString("action") else {
            throw ToolError.invalidArguments("Missing action")
        }
        return try await handleAction(action, args)
    }

    private func handleAction(_ action: String, _ args: ToolArguments) async throws -> String {
        switch action {
        case "listCalendars":
            return try await CalendarService.listCalendars()
        case "listEvents":
            return try await handleListEvents(args)
        case "getEvent":
            return try await handleGetEvent(args)
        case "createEvent":
            return try await handleCreateEvent(args)
        case "updateEvent":
            return try await handleUpdateEvent(args)
        case "deleteEvent":
            return try await handleDeleteEvent(args)
        default:
            throw ToolError.invalidArguments("Invalid action: \(action)")
        }
    }

    private func handleListEvents(_ args: ToolArguments) async throws -> String {
        guard let calendarId = args.getString("calendarId") else {
            throw ToolError.invalidArguments("Missing calendarId")
        }
        let maxResults = args.getInt("maxResults") ?? 10
        return try await CalendarService.listEvents(calendarId: calendarId, maxResults: maxResults)
    }

    private func handleGetEvent(_ args: ToolArguments) async throws -> String {
        guard let calendarId = args.getString("calendarId"),
              let eventId = args.getString("eventId") else {
            throw ToolError.invalidArguments("Missing calendarId or eventId")
        }
        return try await CalendarService.getEvent(calendarId: calendarId, eventId: eventId)
    }

    private func handleCreateEvent(_ args: ToolArguments) async throws -> String {
        guard let calendarId = args.getString("calendarId"),
              let summary = args.getString("summary"),
              let startDateTimeString = args.getString("startDateTime"),
              let endDateTimeString = args.getString("endDateTime") else {
            throw ToolError.invalidArguments("Missing required parameters for creating an event")
        }

        let description = args.getString("description") ?? ""

        guard let startDateTime = ISO8601DateFormatter().date(from: startDateTimeString),
              let endDateTime = ISO8601DateFormatter().date(from: endDateTimeString) else {
            throw ToolError.invalidArguments("Invalid date format. Use ISO 8601 format (e.g., 2025-03-09T15:30:00Z)")
        }

        return try await CalendarService.createEvent(
            calendarId: calendarId,
            summary: summary,
            description: description,
            startDateTime: startDateTime,
            endDateTime: endDateTime
        )
    }

    private func handleUpdateEvent(_ args: ToolArguments) async throws -> String {
        guard let calendarId = args.getString("calendarId"),
              let eventId = args.getString("eventId") else {
            throw ToolError.invalidArguments("Missing calendarId or eventId")
        }

        let summary = args.getString("summary")
        let description = args.getString("description")

        var startDateTime: Date? = nil
        if let startDateTimeString = args.getString("startDateTime") {
            guard let date = ISO8601DateFormatter().date(from: startDateTimeString) else {
                throw ToolError.invalidArguments("Invalid startDateTime format. Use ISO 8601 format (e.g., 2025-03-09T15:30:00Z)")
            }
            startDateTime = date
        }

        var endDateTime: Date? = nil
        if let endDateTimeString = args.getString("endDateTime") {
            guard let date = ISO8601DateFormatter().date(from: endDateTimeString) else {
                throw ToolError.invalidArguments("Invalid endDateTime format. Use ISO 8601 format (e.g., 2025-03-09T15:30:00Z)")
            }
            endDateTime = date
        }

        // Ensure at least one field is being updated
        if summary == nil && description == nil && startDateTime == nil && endDateTime == nil {
            throw ToolError.invalidArguments("At least one field (summary, description, startDateTime, endDateTime) must be provided for update")
        }

        return try await CalendarService.updateEvent(
            calendarId: calendarId,
            eventId: eventId,
            summary: summary,
            description: description,
            startDateTime: startDateTime,
            endDateTime: endDateTime
        )
    }

    private func handleDeleteEvent(_ args: ToolArguments) async throws -> String {
        guard let calendarId = args.getString("calendarId"),
              let eventId = args.getString("eventId") else {
            throw ToolError.invalidArguments("Missing calendarId or eventId")
        }
        return try await CalendarService.deleteEvent(calendarId: calendarId, eventId: eventId)
    }
}
