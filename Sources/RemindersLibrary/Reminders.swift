import EventKit
import Foundation

private let Store = EKEventStore()

extension EKReminder {
  var mappedPriority: EKReminderPriority {
    UInt(exactly: self.priority).flatMap(EKReminderPriority.init) ?? EKReminderPriority.none
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
    try store.saveCalendar(newList, commit: true)
    return newList
  }

  public func deleteList(query: String) throws -> EKCalendar {
    let store = EKEventStore()
    let calendar = try getCalendar(query: query)
    try store.removeCalendar(calendar, commit: true)
    return calendar
  }

  public func editList(query: String, title: String) throws -> EKCalendar {
    let store = EKEventStore()
    let calendar = try getCalendar(query: query)
    calendar.title = title
    try store.saveCalendar(calendar, commit: true)
    return calendar
  }

  func getListItems(query: String, displayOptions: DisplayOptions = .all) throws -> [EKReminder] {
    var matchingReminders = [EKReminder]()
    let semaphore = DispatchSemaphore(value: 0)
    let calendar = try self.getCalendar(query: query)
    self.reminders(on: [calendar], displayOptions: displayOptions) {
      matchingReminders.append(contentsOf: $0)
      semaphore.signal()
    }
    semaphore.wait()
    return matchingReminders
  }

  public func delete(
    query: String, listQuery: String, displayOptions: DisplayOptions = .all
  ) throws -> EKReminder? {
    let calendar = try self.getCalendar(query: listQuery)
    let semaphore = DispatchSemaphore(value: 0)
    var matchedReminder: EKReminder? = nil
    var error: Error? = nil
    self.reminders(on: [calendar], displayOptions: displayOptions) { reminders in
      do {
        let reminder = try self.getReminder(from: reminders, on: calendar, query: query)
        try Store.remove(reminder, commit: true)
        matchedReminder = reminder
      } catch (let err) {
        error = err
      }
      semaphore.signal()
    }
    semaphore.wait()
    if let error = error {
      throw error
    }
    return matchedReminder
  }

  public func addReminder(
    string: String,
    notes: String?,
    listQuery: String,
    dueDateComponents: DateComponents?,
    priority: Priority,
    url: String?
  ) throws -> EKReminder? {

    let calendar = self.calendar(query: listQuery)
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
    try Store.save(reminder, commit: true)
    return reminder
  }

  /// Update an exist item.
  /// - Parameters:
  ///   - index: The index or external ID of the reminder.
  ///   - listQuery: List Id
  ///   - newText: new text of reminder
  ///   - newNotes: new notes of reminder
  ///   - url: new url of reminder
  ///   - isCompleted: isCompleted
  ///   - priority: priority
  ///
  /// - Throws:
  /// - Returns: an optional EKReminder
  public func updateItem(
    query: String,
    listQuery: String,
    newText: String?,
    newNotes: String?,
    url: String?,
    isCompleted: Bool?,
    priority: Int?,
    dueDateComponents: DateComponents?,
    listId: String? = nil
  ) throws -> EKReminder? {

    let calendar = try self.getCalendar(query: listQuery)
    var result: EKReminder? = nil
    let semaphore = DispatchSemaphore(value: 0)
    var error: Error? = nil
    self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
      do {
        let reminder = try self.getReminder(from: reminders, on: calendar, query: query)
        result = reminder
        if let listId = listId {
          let calendar = try self.getCalendar(query: listId)
          reminder.calendar = calendar
        }
        reminder.title = newText ?? reminder.title
        reminder.notes = newNotes ?? reminder.notes
        reminder.isCompleted = isCompleted ?? reminder.isCompleted
        reminder.priority = priority ?? reminder.priority
        if let unwrappedURL = url {
          reminder.url = URL(string: unwrappedURL)
        }
        reminder.dueDateComponents = dueDateComponents ?? reminder.dueDateComponents
        if let dueDate = dueDateComponents?.date, dueDateComponents?.hour != nil {
          reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }
        try Store.save(reminder, commit: true)
      } catch let err {
        error = err
      }
      semaphore.signal()
    }
    if let error = error {
      throw error
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

  private func calendar(query: String) -> EKCalendar? {
    let calendars = self.getCalendars()
    if let number = Int(query) {
      if number < calendars.count {
        return calendars[number]
      }
    }
    let calendar = self.getCalendars().first {
      $0.calendarIdentifier.lowercased() == query.lowercased()
        || $0.title.lowercased() == query.lowercased()
    }
    return calendar
  }

  private func getCalendar(query: String) throws -> EKCalendar {
    guard let calendar = calendar(query: query) else {
      throw RemindersError.listError(message: "No reminders list matching: \(query)")
    }
    return calendar
  }

  /// Get all Lists of Reminders.
  /// - Parameters:
  ///
  /// - Returns: EKCalendar array
  private func getCalendars() -> [EKCalendar] {
    return Store.calendars(for: .reminder)
      .filter { $0.allowsContentModifications }
  }

  /// Get Reminder by index or external ID or title
  /// - Parameters:
  ///   - reminders: EKReminder array
  ///   - index: index or external Id
  ///
  /// - Returns: An optional EKReminder
  private func getReminder(from reminders: [EKReminder], query: String) -> EKReminder? {
    precondition(!query.isEmpty, "Index cannot be empty, argument parser must be misconfigured")
    if let index = Int(query) {
      if index < reminders.count {
        return reminders[index]
      }
    }
    return reminders.first { $0.calendarItemExternalIdentifier == query || $0.title == query }
  }

  private func getReminder(from reminders: [EKReminder], on calendar: EKCalendar, query: String)
    throws -> EKReminder
  {
    guard let reminder = getReminder(from: reminders, query: query) else {
      throw RemindersError.reminderError(
        message: "No reminder at \(query) on \(calendar.title) (\(calendar.calendarIdentifier))")
    }
    return reminder
  }

}
