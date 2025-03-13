import ArgumentParser
import Foundation

private let reminders = RemindersCommand()

private struct ShowLists: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Print the lists")
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
    reminders.showAllReminders(displayOptions: displayOptions)
  }
}

private struct Show: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Print the items on the given list")

  @Argument(
    help:
      "List to print items from (see 'show-lists' for list information). Input index, ID, or name.",
    completion: .custom(listNameCompletion))
  var query: String

  @Flag(help: "Show completed items only")
  var onlyCompleted = false

  @Flag(help: "Include completed items in output")
  var includeCompleted = false

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
      query: self.query,
      displayOptions: displayOptions)
  }
}

private struct Add: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Add a reminder to a list")

  @Argument(
    help: "The list to add to, (see 'show-lists' for list information). Input index, ID, or name.",
    completion: .custom(listNameCompletion))
  var listQuery: String

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
      listQuery: self.listQuery,
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
    help:
      "The list to complete a reminder on, (see 'show-lists' for list information). Input index, ID, or name.",
    completion: .custom(listNameCompletion))
  var listQuery: String

  @Argument(
    help:
      "The query of the reminder to complete, (see 'show' for reminder information). Input index, ID, or name."
  )
  var query: String

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  func run() {
    reminders.outputFormat = self.format

    reminders.setComplete(
      true, query: query, listQuery: listQuery)
  }
}

private struct Uncomplete: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Uncomplete a reminder")

  @Argument(
    help:
      "The list to uncomplete a reminder on, (see 'show-lists' for list information). Input index, ID, or name.",
    completion: .custom(listNameCompletion))
  var listQuery: String

  @Argument(
    help:
      "The query of the reminder to uncomplete, (see 'show' for reminder information). Input index, ID, or name."
  )
  var query: String

  @Option(
    name: .shortAndLong,
    help: "format, either of 'plain' or 'json'")
  var format: OutputFormat = .plain

  func run() {
    reminders.outputFormat = self.format

    reminders.setComplete(
      false, query: self.query, listQuery: self.listQuery)
  }
}

private struct Delete: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Delete a reminder")

  @Argument(
    help:
      "The list to delete a reminder on, (see 'show-lists' for list information). Input index, ID, or name.",
    completion: .custom(listNameCompletion))
  var listQuery: String

  @Argument(
    help:
      "The query of the reminder to uncomplete, (see 'show' for reminder information). Input index, ID, or name."
  )
  var query: String

  func run() {
    // reminders.outputFormat = self.format
    reminders.delete(query: self.query, listQuery: self.query)
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
    help:
      "The list to edit a reminder on, (see 'show-lists' for list information). Input index, ID, or name.",
    completion: .custom(listNameCompletion))
  var listQuery: String

  @Argument(
    help:
      "The query of the reminder to uncomplete, (see 'show' for reminder information). Input index, ID, or name."
  )
  var query: String

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
      query: self.query,
      listQuery: self.listQuery,
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
    reminders.newList(with: self.listName, source: self.source)
  }
}

private struct DeleteList: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Delete a list")

  @Argument(
    help: "Query a list by index or ID or Name")
  var query: String

  func run() {
    reminders.deleteList(query: query)
  }
}

private struct EditList: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Edit a list")

  @Argument(help: "Query a list by index or ID or Name")
  var query: String

  @Argument(help: "The new name of the list")
  var name: String

  func run() {
    reminders.editList(query: query, with: name)
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
      DeleteList.self,
      EditList.self,
      ShowAll.self,
    ]
  )

  public init() {}
}
