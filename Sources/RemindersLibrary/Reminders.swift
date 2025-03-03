import ArgumentParser
import EventKit
import Foundation

private let Store = EKEventStore()

extension EKReminder {
  var mappedPriority: EKReminderPriority {
    UInt(exactly: self.priority).flatMap(EKReminderPriority.init) ?? EKReminderPriority.none
  }
}

enum RemindersError: Error {
  case listSourceError(message: String)
  case listError(message: String)
  case reminderError(message: String)
  case outOfRange(message: String)
  case unknown(message: String)
}

public enum DisplayOptions: String, Decodable {
  case all
  case incomplete
  case complete
}

public enum Priority: String, ExpressibleByArgument {
  case none
  case low
  case medium
  case high

  var value: EKReminderPriority {
    switch self {
    case .none: return .none
    case .low: return .low
    case .medium: return .medium
    case .high: return .high
    }
  }

  init?(_ priority: EKReminderPriority) {
    switch priority {
    case .none: return nil
    case .low: self = .low
    case .medium: self = .medium
    case .high: self = .high
    @unknown default:
      return nil
    }
  }
}

public final class Reminders {
  public init() {}

  /// Checks for access to Reminders.
  /// - Parameters:
  ///
  /// - Returns: Bool
  public static func requestAccess() -> (Bool, Error?) {
    let semaphore = DispatchSemaphore(value: 0)
    var grantedAccess = false
    var returnError: Error? = nil
    if #available(macOS 14.0, *) {
      Store.requestFullAccessToReminders { granted, error in
        grantedAccess = granted
        returnError = error
        semaphore.signal()
      }
    } else {
      Store.requestAccess(to: .reminder) { granted, error in
        grantedAccess = granted
        returnError = error
        semaphore.signal()
      }
    }

    semaphore.wait()
    return (grantedAccess, returnError)
  }

  /// Fetch all reminders.
  /// - Parameter displayOptions: .all or .incomplete or .complete
  /// - Returns: EKReminder array
  public func allReminders(displayOptions: DisplayOptions) -> [EKReminder] {
    let semaphore = DispatchSemaphore(value: 0)
    var matchingReminders = [EKReminder]()
    self.reminders(on: self.getCalendars(), displayOptions: displayOptions) { reminders in
      for reminder in reminders {
        matchingReminders.append(reminder)
      }
      semaphore.signal()
    }
    semaphore.wait()
    return matchingReminders
  }

  public func getLists() -> [EKCalendar] {
    return self.getCalendars()
  }

  /// Create a new Reminders List
  /// - Parameters:
  ///   - name: list name
  ///   - requestedSourceName: Source Name
  ///
  /// - Throws:
  /// - Returns: an optional EKCalendar
  public func newList(with name: String, source requestedSourceName: String?) throws -> EKCalendar?
  {
    let store = EKEventStore()
    let sources = store.sources
    guard var source = sources.first else {
      throw RemindersError.listSourceError(
        message: "No existing list sources were found, please create a list in Reminders.app")
    }

    if let requestedSourceName = requestedSourceName {
      guard let requestedSource = sources.first(where: { $0.title == requestedSourceName }) else {
        throw RemindersError.listSourceError(
          message: "No source named '\(requestedSourceName)'")
      }

      source = requestedSource
    } else {
      let uniqueSources = Set(sources.map { $0.title })
      if uniqueSources.count > 1 {

        throw RemindersError.listSourceError(
          message: "Multiple sources were found, please specify one with --source: \(uniqueSources)"
        )
      }
    }

    let newList = EKCalendar(for: .reminder, eventStore: store)
    newList.title = name
    newList.source = source

    do {
      try store.saveCalendar(newList, commit: true)
      return newList
    } catch let error {
      throw RemindersError.listError(message: "Failed create new list with error: \(error)")
    }
  }

  func getListItems(
    withName name: String, dueOn dueDate: DateComponents?, includeOverdue: Bool,
    displayOptions: DisplayOptions, sort: Sort,
    sortOrder: CustomSortOrder
  ) throws -> [EKReminder] {
    var matchingReminders = [EKReminder]()

    let semaphore = DispatchSemaphore(value: 0)
    let calendar = Calendar.current
    let calendars = [try self.calendar(withName: name)]
    self.reminders(on: calendars, displayOptions: displayOptions) {
      reminders in

      let reminders =
        sort == .none ? reminders : reminders.sorted(by: sort.sortFunction(order: sortOrder))
      for (_, reminder) in reminders.enumerated() {
        // let index = sort == .none ? i : nil
        guard let dueDate = dueDate?.date else {
          matchingReminders.append(reminder)
          continue
        }

        guard let reminderDueDate = reminder.dueDateComponents?.date else {
          continue
        }

        let sameDay =
          calendar.compare(
            reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
        let earlierDay =
          calendar.compare(
            reminderDueDate, to: dueDate, toGranularity: .day) == .orderedAscending

        if sameDay || (includeOverdue && earlierDay) {
          matchingReminders.append(reminder)
        }
      }

      semaphore.signal()
    }

    semaphore.wait()
    return matchingReminders
  }

  func delete(indexOrId: String, listId: String) throws -> EKReminder? {
    let calendar = try self.calendar(id: listId)
    let semaphore = DispatchSemaphore(value: 0)
    var matchedReminder: EKReminder? = nil
    self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
      guard let reminder = self.getReminder(from: reminders, at: indexOrId) else {
        print("No reminder at index or ID \(indexOrId) on \(listId)")
        return
      }

      do {
        try Store.remove(reminder, commit: true)
        matchedReminder = reminder
        print("Deleted '\(reminder.title!)'")
      } catch let error {
        print("Failed to delete reminder with error: \(error)")
        return
      }
      semaphore.signal()
    }
    semaphore.wait()
    return matchedReminder
  }

  func addReminder(
    string: String,
    notes: String?,
    listId: String,
    dueDateComponents: DateComponents?,
    priority: Priority,
    url: String?
  ) throws -> EKReminder? {

    let calendar = try self.calendar(id: listId)
    let reminder = EKReminder(eventStore: Store)
    reminder.calendar = calendar
    reminder.title = string
    reminder.notes = notes
    if let unwrappedURL = url {
      reminder.url = URL(string: unwrappedURL)
    }
    reminder.dueDateComponents = dueDateComponents
    reminder.priority = Int(priority.value.rawValue)
    if let dueDate = dueDateComponents?.date, dueDateComponents?.hour != nil {
      reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
    }

    do {
      try Store.save(reminder, commit: true)
    } catch let error {
      throw RemindersError.reminderError(message: "Failed to save reminder with error: \(error)")
    }
    return reminder
  }

  /// Update an exist item.
  /// - Parameters:
  ///   - index: The index or external ID of the reminder.
  ///   - listId: List Id
  ///   - newText: new text of reminder
  ///   - newNotes: new notes of reminder
  ///   - url: new url of reminder
  ///   - isCompleted: isCompleted
  ///   - priority: priority
  ///
  /// - Throws:
  /// - Returns: an optional EKReminder
  public func updateItem(
    itemAtIndex index: String,
    listId: String,
    newText: String?,
    newNotes: String?,
    url: String?,
    isCompleted: Bool?,
    priority: Int?
  ) throws -> EKReminder? {

    let calendar = try self.calendar(id: listId)
    var result: EKReminder? = nil
    let semaphore = DispatchSemaphore(value: 0)

    self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
      guard let reminder = self.getReminder(from: reminders, at: index) else {
        print("No reminder at index \(index) on \(listId)")
        return
      }
      result = reminder

      do {
        reminder.title = newText ?? reminder.title
        reminder.notes = newNotes ?? reminder.notes
        reminder.isCompleted = isCompleted ?? reminder.isCompleted
        reminder.priority = priority ?? reminder.priority
        if let unwrappedURL = url {
          reminder.url = URL(string: unwrappedURL)
        }
        try Store.save(reminder, commit: true)

      } catch let error {
        print("Failed to update reminder with error: \(error)")
        return
      }
      semaphore.signal()
    }
    semaphore.wait()
    return result
  }

  // MARK: - Private functions

  private func reminders(
    on calendars: [EKCalendar],
    displayOptions: DisplayOptions,
    completion: @escaping (_ reminders: [EKReminder]) -> Void
  ) {
    let predicate = Store.predicateForReminders(in: calendars)
    Store.fetchReminders(matching: predicate) { reminders in
      let reminders = reminders?
        .filter { self.shouldDisplay(reminder: $0, displayOptions: displayOptions) }
      completion(reminders ?? [])
    }
  }

  private func shouldDisplay(reminder: EKReminder, displayOptions: DisplayOptions) -> Bool {
    switch displayOptions {
    case .all:
      return true
    case .incomplete:
      return !reminder.isCompleted
    case .complete:
      return reminder.isCompleted
    }
  }

  /// Get Reminder List by ID
  /// - Parameter id: String
  /// - Throws:
  /// - Returns: EKCalendar
  private func calendar(id: String) throws -> EKCalendar {
    if let calendar = self.getCalendars().find(where: {
      $0.calendarIdentifier.lowercased() == id.lowercased()
    }
    ) {
      return calendar
    } else {
      throw RemindersError.listError(message: "No reminders list matching id: \(id)")
    }
  }

  /// Get Reminder List by Name
  /// - Parameter name: String
  /// - Throws:
  /// - Returns: EKCalendar
  private func calendar(withName name: String) throws -> EKCalendar {
    if let calendar = self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() }
    ) {
      return calendar
    } else {
      throw RemindersError.listError(message: "No reminders list matching \(name)")
    }
  }

  /// Get all Lists of Reminders.
  /// - Parameters:
  ///
  /// - Returns: EKCalendar array
  private func getCalendars() -> [EKCalendar] {
    return Store.calendars(for: .reminder)
      .filter { $0.allowsContentModifications }
  }

  /// Get Reminder by index or external ID
  /// - Parameters:
  ///   - reminders: EKReminder array
  ///   - index: index or external Id
  ///
  /// - Returns: An optional EKReminder
  private func getReminder(from reminders: [EKReminder], at index: String) -> EKReminder? {
    precondition(!index.isEmpty, "Index cannot be empty, argument parser must be misconfigured")
    if let index = Int(index) {
      return reminders[safe: index]
    } else {
      return reminders.first { $0.calendarItemExternalIdentifier == index }
    }
  }
}
