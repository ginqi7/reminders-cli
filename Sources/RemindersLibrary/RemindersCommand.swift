import EventKit
import Foundation

public final class RemindersCommand {

  private let reminders = Reminders()

  var outputFormat: OutputFormat = .plain

  public func newList(with name: String, source requestedSourceName: String?) {
    do {
      let newList = try reminders.newList(with: name, source: requestedSourceName)
      printOutput(data: newList, action: "New List: ")
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }
  }

  func showLists() {
    let lists = reminders.getLists()
    printOutput(data: lists)
  }

  func showAllReminders(displayOptions: DisplayOptions) {
    let items = reminders.allReminders(displayOptions: displayOptions)
    printOutput(data: items)
  }

  func showListItems(
    query: String,
    displayOptions: DisplayOptions
  ) {
    do {
      let items = try reminders.getListItems(
        query: query,
        displayOptions: displayOptions)
      printOutput(data: items)
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }
  }

  func edit(
    query: String, listQuery: String, newText: String?, newNotes: String?,
    url: String?, isCompleted: Bool?, priority: Int?
  ) {
    do {
      let reminder = try reminders.updateItem(
        query: query, listQuery: listQuery, newText: newText, newNotes: newNotes, url: url,
        isCompleted: isCompleted, priority: priority)
      printOutput(data: reminder, action: "Edit Reminder: ")
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }
  }

  func setComplete(
    _ complete: Bool, query: String, listQuery: String

  ) {
    do {
      let reminder = try reminders.updateItem(
        query: query, listQuery: listQuery, newText: nil, newNotes: nil, url: nil,
        isCompleted: complete, priority: nil)
      printOutput(data: reminder, action: "Complete Reminder: ")
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }

  }

  func delete(query: String, listQuery: String) {
    do {
      try _ = reminders.delete(query: query, listQuery: listQuery)
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }
  }

  func addReminder(
    string: String,
    notes: String?,
    listQuery: String,
    dueDateComponents: DateComponents?,
    priority: Priority,
    url: String?
  ) {
    do {
      let reminder = try reminders.addReminder(
        string: string,
        notes: notes,
        listQuery: listQuery,
        dueDateComponents: dueDateComponents,
        priority: priority,
        url: url)
      printOutput(data: reminder, action: "Add Reminder: ")
    } catch let error {
      print("Failed to save reminder with error: \(error)")
      exit(1)
    }
  }

  private func encodeToLisp(data: Encodable) -> String {
    let encoder = LispEncoder()
    let encoded = try! encoder.encode(data)
    return encoded
  }

  private func encodeToJson(data: Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(data)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

  private func encodeToPain(data: Encodable) -> String {
    if let array = data as? [Encodable] {
      return array.enumerated()
        .map { "[\($0.offset)] \(encodeToPain(data: $0.element))" }
        .joined(separator: "\n")
    } else if let reminder = data as? EKReminder {
      return reminder.toStr()
    } else if let canlendar = data as? EKCalendar {
      return canlendar.toStr()
    }
    return ""
  }

  private func printOutput(data: Encodable, action: String = "") {
    switch outputFormat {
    case .json:
      print(encodeToJson(data: data))
    case .lisp:
      print(encodeToLisp(data: data))
    default:
      print("\(action)" + encodeToPain(data: data))
    }
  }

}
