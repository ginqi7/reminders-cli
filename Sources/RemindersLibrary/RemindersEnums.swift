import ArgumentParser
import EventKit
import Foundation

public enum OutputFormat: String, ExpressibleByArgument {
  case json, lisp, plain
}

public enum RemindersError: Error {
  case listSourceError(message: String)
  case listError(message: String)
  case reminderError(message: String)
  case outOfRange(message: String)
  case unknown(message: String)
}

public enum DisplayOptions: String, Decodable, ExpressibleByArgument {
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
