import Foundation

protocol AnyOptional {
    var unwrapped: Any? { get }
}
extension Optional: AnyOptional {
    var unwrapped: Any? {
        switch self {
        case .some(let value): return value
        case .none: return nil
        }
    }
}

class LispEncoder: Encoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    fileprivate var singleValue: String? = nil
    fileprivate var storage: [String: Any] = [:]
    fileprivate var unkeyedStorage: [Any] = []

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = LispKeyedEncodingContainer<Key>(encoder: self)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = LispUnkeyedEncodingContainer(encoder: self)
        return container
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        let container = LispSingleValueContainer(encoder: self)
        return container
    }

    func encode<T: Encodable>(_ value: T) throws -> String {
        try value.encode(to: self)
        var result = "()"
        if let value = singleValue {
            result = value
            singleValue = nil
        } else if !storage.isEmpty {
            result =  "(" + storage.map { "\($0.key) \($0.value)"}.joined(separator: " ") + ")"
            storage = [:]
        } else if !unkeyedStorage.isEmpty {
            result = "(" + unkeyedStorage.map { "\($0)" }.joined(separator: "\n") + ")"
            unkeyedStorage = []
        }
        return result
    }
}

private struct LispKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    private var encoder: LispEncoder
    init(encoder: LispEncoder) {
        self.encoder = encoder
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let encoded =  try! encoder.encode(value)
        encoder.storage[key.stringValue] = encoded
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        if value {
            encoder.storage[key.stringValue] = "t"
        }
    }

    mutating func encodeNil(forKey key: Key) throws {

    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        fatalError("Nested containers are not supported by LispEncoder.")
    }
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("Nested unkeyed containers are not supported by LispEncoder.")
    }
    mutating func superEncoder() -> Encoder {
        return encoder
    }
    mutating func superEncoder(forKey key: Key) -> Encoder {
        return encoder
    }
}

private struct LispUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [CodingKey] = []
    var count: Int { encoder.unkeyedStorage.count }
    private var encoder: LispEncoder
    init(encoder: LispEncoder) {
        self.encoder = encoder
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let encoded =  try! encoder.encode(value)
        encoder.unkeyedStorage.append(encoded)
    }

    mutating func encodeNil() throws {

    }
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        fatalError("Nested keyed containers are not supported by LispEncoder.")
    }
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Nested unkeyed containers are not supported by LispEncoder.")
    }
    mutating func superEncoder() -> Encoder {
        return encoder
    }
}

private struct LispSingleValueContainer: SingleValueEncodingContainer {
    var encoder: LispEncoder

    init(encoder: LispEncoder) {
        self.encoder = encoder
    }

    var codingPath: [CodingKey] {
        return []
    }

    mutating func encodeNil() throws {
        encoder.singleValue = nil
    }
    mutating func encode(_ value: Bool) throws {
        if value {
            encoder.singleValue = "t"
        }
    }

    mutating func encode(_ value: String) throws {
        encoder.singleValue = "\"\(value)\""
    }

    mutating func encode(_ value: Int) throws {
        encoder.singleValue = String(describing: value)
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        encoder.singleValue = "\"\(String(describing: value))\""
    }
}
