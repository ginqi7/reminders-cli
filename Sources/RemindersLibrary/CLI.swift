import ArgumentParser
import Foundation

private let reminders = RemindersCommand()

private struct ShowLists: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Print the name of lists to pass to other commands")
  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  func run() {
    reminders.outputFormat = self.format
    reminders.showLists()
  }
}

private struct ShowAll: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Print all reminders")

  @Flag(help: "Show completed items only")
  var onlyCompleted = false

  @Flag(help: "Include completed items in output")
  var includeCompleted = false

  @Flag(help: "When using --due-date, also include items due before the due date")
  var includeOverdue = false

  @Option(
    name: .shortAndLong,
    help: "Show only reminders due on this date")
  var dueDate: DateComponents?

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  func validate() throws {
    if self.onlyCompleted && self.includeCompleted {
      throw ValidationError(
        "Cannot specify both --show-completed and --only-completed")
    }
  }

  func run() {
    reminders.outputFormat = self.format
    var displayOptions = DisplayOptions.incomplete
    if self.onlyCompleted {
      displayOptions = .complete
    } else if self.includeCompleted {
      displayOptions = .all
    }

    reminders.showAllReminders(
      dueOn: self.dueDate, includeOverdue: self.includeOverdue,
      displayOptions: displayOptions)
  }
}

private struct Show: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Print the items on the given list")

  @Argument(
    help: "The list to print items from, see 'show-lists' for names",
    completion: .custom(listNameCompletion))
  var listName: String

  @Flag(help: "Show completed items only")
  var onlyCompleted = false

  @Flag(help: "Include completed items in output")
  var includeCompleted = false

  @Flag(help: "When using --due-date, also include items due before the due date")
  var includeOverdue = false

  @Option(
    name: .shortAndLong,
    help: "Show the reminders in a specific order, one of: \(Sort.commaSeparatedCases)")
  var sort: Sort = .none

  @Option(
    name: [.customShort("o"), .long],
    help: "How the sort order should be applied, one of: \(CustomSortOrder.commaSeparatedCases)")
  var sortOrder: CustomSortOrder = .ascending

  @Option(
    name: .shortAndLong,
    help: "Show only reminders due on this date")
  var dueDate: DateComponents?

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  func validate() throws {
    if self.onlyCompleted && self.includeCompleted {
      throw ValidationError(
        "Cannot specify both --show-completed and --only-completed")
    }
  }

  func run() {
    reminders.outputFormat = self.format
    var displayOptions = DisplayOptions.incomplete
    if self.onlyCompleted {
      displayOptions = .complete
    } else if self.includeCompleted {
      displayOptions = .all
    }

    reminders.showListItems(
      withName: self.listName, dueOn: self.dueDate, includeOverdue: self.includeOverdue,
      displayOptions: displayOptions, sort: sort, sortOrder: sortOrder)
  }
}

private struct Add: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Add a reminder to a list")

  @Argument(
    help: "The list to add to, see 'show-lists' for names",
    completion: .custom(listNameCompletion))
  var listName: String

  @Argument(
    parsing: .remaining,
    help: "The reminder contents")
  var reminder: [String]

  @Option(
    name: .shortAndLong,
    help: "The date the reminder is due")
  var dueDate: DateComponents?

  @Option(
    name: .shortAndLong,
    help: "The priority of the reminder")
  var priority: Priority = .none

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  @Option(
    name: .shortAndLong,
    help: "URL, unvisible in Reminders GUI")
  var url: String?

  @Option(
    name: .shortAndLong,
    help: "The notes to add to the reminder")
  var notes: String?

  func run() {
    reminders.outputFormat = self.format
    reminders.addReminder(
      string: self.reminder.joined(separator: " "),
      notes: self.notes,
      listId: self.listName,
      dueDateComponents: self.dueDate,
      priority: priority,
      url: self.url
    )
  }
}

private struct Complete: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Complete a reminder")

  @Argument(
    help: "The list to complete a reminder on, see 'show-lists' for names",
    completion: .custom(listNameCompletion))
  var listId: String

  @Argument(
    help: "The index or id of the reminder to delete, see 'show' for indexes")
  var index: String

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  func run() {
    reminders.outputFormat = self.format

    reminders.setComplete(
      true, itemAtIndex: self.index, onListId: self.listId)
  }
}

private struct Uncomplete: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Uncomplete a reminder")

  @Argument(
    help: "The list to uncomplete a reminder on, see 'show-lists' for names",
    completion: .custom(listNameCompletion))
  var listId: String

  @Argument(
    help: "The index or id of the reminder to delete, see 'show' for indexes")
  var index: String

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  func run() {
    reminders.outputFormat = self.format

    reminders.setComplete(
      false, itemAtIndex: self.index, onListId: self.listId)
  }
}

private struct Delete: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Delete a reminder")

  @Argument(
    help: "The list to delete a reminder on, see 'show-lists' for names",
    completion: .custom(listNameCompletion))
  var listName: String

  @Argument(
    help: "The index or id of the reminder to delete, see 'show' for indexes")
  var index: String

  func run() {
    // reminders.outputFormat = self.format
    reminders.delete(indexOrId: self.index, listId: self.listName)
  }
}

func listNameCompletion(_ arguments: [String]) -> [String] {
  // NOTE: A list name with ':' was separated in zsh completion, there might be more of these or
  // this might break other shells
  // return reminders.getListNames().map { $0.replacingOccurrences(of: ":", with: "\\:") }
  return []
}

private struct Edit: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Edit the text of a reminder")

  @Argument(
    help: "The list to edit a reminder on, see 'show-lists' for names",
    completion: .custom(listNameCompletion))
  var listName: String

  @Argument(
    help: "The index or id of the reminder to delete, see 'show' for indexes")
  var index: String

  @Option(
    name: .shortAndLong,
    help: "The notes to set on the reminder, overwriting previous notes")
  var notes: String?

  @Argument(
    parsing: .remaining,
    help: "The new reminder contents")
  var reminder: [String] = []

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  @Option(
    name: .shortAndLong,
    help: "URL, unvisible in Reminders GUI")
  var url: String?

  func validate() throws {
    if self.reminder.isEmpty && self.notes == nil {
      throw ValidationError("Must specify either new reminder content or new notes")
    }
  }

  func run() {
    reminders.outputFormat = self.format

    let newText = self.reminder.joined(separator: " ")
    reminders.edit(
      itemAtIndex: self.index,
      onListId: self.listName,
      newText: newText.isEmpty ? nil : newText,
      newNotes: self.notes,
      url: self.url,
      isCompleted: false,
      priority: 0
    )
  }
}

private struct NewList: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Create a new list")

  @Argument(
    help: "The name of the new list")
  var listName: String

  @Option(
    name: .shortAndLong,
    help:
      "The name of the source of the list, if all your lists use the same source it will default to that"
  )
  var source: String?

  func run() {
    // reminders.outputFormat = self.format
    reminders.newList(with: self.listName, source: self.source)
  }
}

public struct CLI: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "Interact with macOS Reminders from the command line",
    subcommands: [
      Add.self,
      Complete.self,
      Uncomplete.self,
      Delete.self,
      Edit.self,
      Show.self,
      ShowLists.self,
      NewList.self,
      ShowAll.self,
    ]
  )

  public init() {}
}
