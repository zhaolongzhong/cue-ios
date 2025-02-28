//
//  AppDatabase.swift
//  CueApp
//

import Foundation
import GRDB
import os.log
import Dependencies
import CueCommon

/// The type that provides access to the application database.
final class AppDatabase: Sendable {
    /// Access to the database.
    let dbWriter: any DatabaseWriter

    /// Creates a `AppDatabase`, and makes sure the database schema
    /// is ready.
    init(_ dbWriter: any GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    /// The DatabaseMigrator that defines the database schema.
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("createMessageModels") { db in
            try db.create(table: MessageModelRecord.databaseTableName, ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("conversationId", .text).notNull().indexed()
                table.column("author", .blob).notNull()
                table.column("content", .blob).notNull()
                table.column("metadata", .blob)
                table.column("createdAt", .datetime).notNull().indexed()
                table.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("createConversationModels") { db in
            try db.create(table: ConversationModelRecord.databaseTableName, ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("assistantId", .text).indexed()
                table.column("metadata", .blob)
                table.column("createdAt", .datetime).notNull().indexed()
                table.column("updatedAt", .datetime).notNull()
            }
        }

        // Future migrations will go here

        return migrator
    }
}

// MARK: - Database Configuration

extension AppDatabase {
    private static let sqlLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SQL")

    /// Returns a database configuration suited for `AppDatabase`.
    static func makeConfiguration(_ config: Configuration = Configuration()) -> Configuration {
        var config = config

        // Configure for better performance and concurrency
        config.busyMode = .timeout(5.0)  // Wait up to 5 seconds for locks

        #if DEBUG
        // Enable SQL logging in debug builds
        // config.prepareDatabase { db in
        //     db.trace { event in
        //        sqlLogger.debug("\(db.description): \(event)")
        //     }
        // }

        // Protect sensitive information by enabling verbose debugging in
        // DEBUG builds only.
        config.publicStatementArguments = true
        #endif

        return config
    }
}

// MARK: - Shared Database

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()

    private static func makeShared() -> AppDatabase {
        do {
            // Create the "Application Support/Database" directory if needed
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let directoryURL = appSupportURL.appendingPathComponent("Database", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            // Open or create the database
            let databaseURL = directoryURL.appendingPathComponent("app.sqlite")
            let config = AppDatabase.makeConfiguration()
            let dbPool = try DatabasePool(path: databaseURL.path, configuration: config)

            // Create the AppDatabase
            return try AppDatabase(dbPool)
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            print("Failed to initialize shared AppDatabase: \(error)")
            fatalError("Unresolved error \(error)")
        }
    }

    /// Creates an empty database for testing or SwiftUI previews
    static func empty() -> AppDatabase {
        // Connect to an in-memory database
        let dbQueue = try! DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try! AppDatabase(dbQueue)
    }
}

// MARK: - Dependency Injection

extension AppDatabase: DependencyKey {
    public static var liveValue: AppDatabase {
        return shared
    }

    public static var testValue: AppDatabase {
        return empty()
    }
}

extension DependencyValues {
    var database: AppDatabase {
        get { self[AppDatabase.self] }
        set { self[AppDatabase.self] = newValue }
    }
}

// MARK: - Database Access: General Operations

extension AppDatabase {
    /// Provides a read-only access to the database.
    var reader: any GRDB.DatabaseReader {
        dbWriter
    }

    /// Clears all database data.
    func resetDatabase() async throws {
        try await dbWriter.write { db in
            try MessageModelRecord.deleteAll(db)
            try ConversationModelRecord.deleteAll(db)
        }
    }
}
