import EventKit

extension EKCalendar: @retroactive Encodable {
  private enum EncodingKeys: String, CodingKey {
    case id
    case title
    case source
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)
    try container.encode(self.calendarIdentifier, forKey: .id)
    try container.encode(self.title, forKey: .title)
    // try container.encodeIfPresent(self.source, forKey: .source)
  }

  public func toJson() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(self)
    return String(data: encoded, encoding: .utf8) ?? ""
  }

  public func toStr() -> String {
    return "\(self.title) (id: \(self.calendarIdentifier))"
  }

}
