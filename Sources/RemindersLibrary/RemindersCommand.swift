import ArgumentParser
import EventKit
import Foundation

public enum OutputFormat: String, ExpressibleByArgument {
  case json, lisp, plain
}

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

  func showAllReminders(
    dueOn dueDate: DateComponents?, includeOverdue: Bool,
    displayOptions: DisplayOptions
  ) {
    let items = reminders.allReminders(displayOptions: displayOptions)
    printOutput(data: items)
  }

  func showListItems(
    withName name: String, dueOn dueDate: DateComponents?, includeOverdue: Bool,
    displayOptions: DisplayOptions, sort: Sort,
    sortOrder: CustomSortOrder
  ) {
    do {
      let items = try reminders.getListItems(
        withName: name, dueOn: dueDate, includeOverdue: includeOverdue,
        displayOptions: displayOptions, sort: sort, sortOrder: sortOrder)
      printOutput(data: items)
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }
  }

  func edit(
    itemAtIndex index: String, onListId listId: String, newText: String?, newNotes: String?,
    url: String?, isCompleted: Bool?, priority: Int?
  ) {
    do {
      let reminder = try reminders.updateItem(
        itemAtIndex: index, listId: listId, newText: newText, newNotes: newNotes, url: url,
        isCompleted: isCompleted, priority: priority)
      printOutput(data: reminder, action: "Edit Reminder: ")
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }
  }

  func setComplete(
    _ complete: Bool, itemAtIndex index: String, onListId listId: String

  ) {
    do {
      let reminder = try reminders.updateItem(
        itemAtIndex: index, listId: listId, newText: nil, newNotes: nil, url: nil,
        isCompleted: complete, priority: nil)
      printOutput(data: reminder, action: "Complete Reminder: ")
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }

  }

  func delete(indexOrId: String, listId: String) {
    do {
      try _ = reminders.delete(indexOrId: indexOrId, listId: listId)
    } catch let error {
      print("Failed create new list with error: \(error)")
      exit(1)
    }
  }

  func addReminder(
    string: String,
    notes: String?,
    listId: String,
    dueDateComponents: DateComponents?,
    priority: Priority,
    url: String?
  ) {
    do {
      let reminder = try reminders.addReminder(
        string: string,
        notes: notes,
        listId: listId,
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
