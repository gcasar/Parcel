//  Bundler.swift
//
//  Copyright (c) 2014 - 2017 Ruoyu Fu, Pinglin Tang, Gregor Casar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

// MARK: - Error

///Error domain
public let ErrorDomain: String = "ParcelErrorDomain"

///Error code
public let ErrorUnsupportedType: Int = 999
public let ErrorIndexOutOfBounds: Int = 900
public let ErrorWrongType: Int = 901
public let ErrorNotExist: Int = 500
public let ErrorInvalidJSON: Int = 490

// MARK: - JSON Type

/**
 Parcel supported types. Superset of JSON's type definitions.

 See http://www.json.org
 */
public enum Type :Int{

    case number
    case string
    case bool
    case array
    case dictionary
    case date
    case null
    case unknown

}

public protocol ParcelWrittable{

}

public protocol ParcelReadable{

}

// MARK: - JSON Base
public struct Parcel {

    /**
     Creates a Bundle using the data.

     - parameter data:  The NSData used to convert to json.Top level object in data is an NSArray or NSDictionary
     - parameter opt:   The JSON serialization reading options. `.AllowFragments` by default.
     - parameter error: The NSErrorPointer used to return the error. `nil` by default.

     - returns: The created JSON
     */
    public init(data: Data, options opt: JSONSerialization.ReadingOptions = .allowFragments, error: NSErrorPointer = nil) {
        do {
            let object: Any = try JSONSerialization.jsonObject(with: data, options: opt)
            self.init(jsonObject: object)
        } catch let aError as NSError {
            if error != nil {
                error?.pointee = aError
            }
            self.init(jsonObject: NSNull())
        }
    }

    /**
     Creates a JSON object
     - parameter object: the object
     - note: this does not parse a `String` into JSON, instead use `init(parseJSON: String)`
     - returns: the created JSON object
     */
    public init(_ object: Any) {
        switch object {
        case let object as [Parcel] where object.count > 0:
            self.init(array: object)
        case let object as [String: Parcel] where object.count > 0:
            self.init(dictionary: object)
        case let object as Data:
            self.init(data: object)
        default:
            self.init(jsonObject: object)
        }
    }

    /**
     Parses the JSON string into a JSON object
     - parameter json: the JSON string
     - returns: the created JSON object
     */
    public init(parseJSON jsonString: String) {
        if let data = jsonString.data(using: .utf8) {
            self.init(data)
        } else {
            self.init(NSNull())
        }
    }

    /**
     Creates a JSON from JSON string
     - parameter string: Normal json string like '{"a":"b"}'

     - returns: The created JSON
     */
    @available(*, deprecated: 3.2, message: "Use instead `init(parseJSON: )`")
    public static func parse(_ json: String) -> Parcel {
        return json.data(using: String.Encoding.utf8)
            .flatMap{ Parcel(data: $0) } ?? Parcel(NSNull())
    }

    /**
     Creates a JSON using the object.

     - parameter object:  The object must have the following properties: All objects are NSString/String, NSNumber/Int/Float/Double/Bool, NSArray/Array, NSDictionary/Dictionary, or NSNull; All dictionary keys are NSStrings/String; NSNumbers are not NaN or infinity.

     - returns: The created JSON
     */
    fileprivate init(jsonObject: Any) {
        self.object = jsonObject
    }

    /**
     Creates a JSON from a [JSON]

     - parameter jsonArray: A Swift array of JSON objects

     - returns: The created JSON
     */
    fileprivate init(array: [Parcel]) {
        self.init(array.map { $0.object })
    }

    /**
     Creates a JSON from a [String: JSON]

     - parameter jsonDictionary: A Swift dictionary of JSON objects

     - returns: The created JSON
     */
    fileprivate init(dictionary: [String: Parcel]) {
        var newDictionary = [String: Any](minimumCapacity: dictionary.count)
        for (key, json) in dictionary {
            newDictionary[key] = json.object
        }

        self.init(newDictionary)
    }

    /**
     Merges another JSON into this JSON, whereas primitive values which are not present in this JSON are getting added,
     present values getting overwritten, array values getting appended and nested JSONs getting merged the same way.

     - parameter other: The JSON which gets merged into this JSON
     - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
     */
    public mutating func merge(with other: Parcel) throws {
        try self.merge(with: other, typecheck: true)
    }

    /**
     Merges another JSON into this JSON and returns a new JSON, whereas primitive values which are not present in this JSON are getting added,
     present values getting overwritten, array values getting appended and nested JSONS getting merged the same way.

     - parameter other: The JSON which gets merged into this JSON
     - returns: New merged JSON
     - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
     */
    public func merged(with other: Parcel) throws -> Parcel {
        var merged = self
        try merged.merge(with: other, typecheck: true)
        return merged
    }

    // Private woker function which does the actual merging
    // Typecheck is set to true for the first recursion level to prevent total override of the source JSON
    fileprivate mutating func merge(with other: Parcel, typecheck: Bool) throws {
        if self.type == other.type {
            switch self.type {
            case .dictionary:
                for (key, _) in other {
                    try self[key].merge(with: other[key], typecheck: false)
                }
            case .array:
                self = Parcel(self.arrayValue + other.arrayValue)
            default:
                self = other
            }
        } else {
            if typecheck {
                throw NSError(domain: ErrorDomain, code: ErrorWrongType, userInfo: [NSLocalizedDescriptionKey: "Couldn't merge, because the JSONs differ in type on top level."])
            } else {
                self = other
            }
        }
    }

    /// Private object
    fileprivate var rawArray: [Any] = []
    fileprivate var rawDictionary: [String : Any] = [:]
    fileprivate var rawString: String = ""
    fileprivate var rawNumber: NSNumber = 0
    fileprivate var rawNull: NSNull = NSNull()
    fileprivate var rawBool: Bool = false
    fileprivate var rawDate: Date = Date()
    /// Private type
    fileprivate var _type: Type = .null
    /// prviate error
    fileprivate var _error: NSError? = nil
    /// Metadata - key of this object in the parent
    fileprivate var _key: ParcelKey? = nil;

    /// Object in JSON
    public var object: Any {
        get {
            switch self.type {
            case .array:
                return self.rawArray
            case .dictionary:
                return self.rawDictionary
            case .string:
                return self.rawString
            case .number:
                return self.rawNumber
            case .bool:
                return self.rawBool
            case .date:
                return self.rawDate
            default:
                return self.rawNull
            }
        }
        set {
            _error = nil
            switch newValue {
            case let number as NSNumber:
                if number.isBool {
                    _type = .bool
                    self.rawBool = number.boolValue
                } else {
                    _type = .number
                    self.rawNumber = number
                }
            case let string as String:
                _type = .string
                self.rawString = string
            case _ as NSNull:
                _type = .null
            case _ as [Parcel]:
				_type = .array
			case nil:
				_type = .null
            case let array as [Any]:
                _type = .array
                self.rawArray = array
            case let dictionary as [String : Any]:
                _type = .dictionary
                self.rawDictionary = dictionary
            case let date as Date:
                _type = .date
                self.rawDate = date;
            default:
                _type = .unknown
                _error = NSError(domain: ErrorDomain, code: ErrorUnsupportedType, userInfo: [NSLocalizedDescriptionKey: "It is a unsupported type"])
            }
        }
    }

    /// JSON type
    public var type: Type { get { return _type } }

    /// Error in JSON
    public var error: NSError? { get { return self._error } }

    /// The static null JSON
    @available(*, unavailable, renamed:"null")
    public static var nullJSON: Parcel { get { return null } }
    public static var null: Parcel { get { return Parcel(NSNull()) } }
}

public enum Index<T: Any>: Comparable
{
    case array(Int)
    case dictionary(DictionaryIndex<String, T>)
    case null

    static public func ==(lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):
            return left == right
        case (.dictionary(let left), .dictionary(let right)):
            return left == right
        case (.null, .null): return true
        default:
            return false
        }
    }

    static public func <(lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):
            return left < right
        case (.dictionary(let left), .dictionary(let right)):
            return left < right
        default:
            return false
        }
    }
}

public typealias JSONIndex = Index<Parcel>
public typealias JSONRawIndex = Index<Any>


extension Parcel: Collection
{

    public typealias Index = JSONRawIndex

    public var startIndex: Index
    {
        switch type
        {
        case .array:
            return .array(rawArray.startIndex)
        case .dictionary:
            return .dictionary(rawDictionary.startIndex)
        default:
            return .null
        }
    }

    public var endIndex: Index
    {
        switch type
        {
        case .array:
            return .array(rawArray.endIndex)
        case .dictionary:
            return .dictionary(rawDictionary.endIndex)
        default:
            return .null
        }
    }

    public func index(after i: Index) -> Index
    {
        switch i
        {
        case .array(let idx):
            return .array(rawArray.index(after: idx))
        case .dictionary(let idx):
            return .dictionary(rawDictionary.index(after: idx))
        default:
            return .null
        }

    }

    public subscript (position: Index) -> (String, Parcel)
    {
        switch position
        {
        case .array(let idx):
            return (String(idx), Parcel(self.rawArray[idx]))
        case .dictionary(let idx):
            let (key, value) = self.rawDictionary[idx]
            return (key, Parcel(value))
        default:
            return ("", Parcel.null)
        }
    }


}

// MARK: - Subscript

/**
 *  To mark both String and Int can be used in subscript.
 */
public enum ParcelKey
{
    case index(Int)
    case key(String)
}

public protocol JSONSubscriptType {
    var jsonKey: ParcelKey { get }
}

extension Int: JSONSubscriptType {
    public var jsonKey: ParcelKey {
        return ParcelKey.index(self)
    }
}

extension String: JSONSubscriptType {
    public var jsonKey: ParcelKey {
        return ParcelKey.key(self)
    }
}

extension Parcel {

    /// If `type` is `.Array`, return json whose object is `array[index]`, otherwise return null json with error.
    fileprivate subscript(index index: Int) -> Parcel {
        get {
            if self.type != .array {
                var r = Parcel.null
                r._error = self._error ?? NSError(domain: ErrorDomain, code: ErrorWrongType, userInfo: [NSLocalizedDescriptionKey: "Array[\(index)] failure, It is not an array"])
                return r
            } else if index >= 0 && index < self.rawArray.count {
                return Parcel(self.rawArray[index])
            } else {
                var r = Parcel.null
                r._error = NSError(domain: ErrorDomain, code:ErrorIndexOutOfBounds , userInfo: [NSLocalizedDescriptionKey: "Array[\(index)] is out of bounds"])
                return r
            }
        }
        set {
            if self.type == .array {
                if self.rawArray.count > index && newValue.error == nil {
                    self.rawArray[index] = newValue.object
                }
            }
        }
    }

    /// If `type` is `.Dictionary`, return json whose object is `dictionary[key]` , otherwise return null json with error.
    fileprivate subscript(key key: String) -> Parcel {
        get {
            var r = Parcel.null
            if self.type == .dictionary {
                if let o = self.rawDictionary[key] {
                    r = Parcel(o)
                } else {
                    r._error = NSError(domain: ErrorDomain, code: ErrorNotExist, userInfo: [NSLocalizedDescriptionKey: "Dictionary[\"\(key)\"] does not exist"])
                }
            } else {
                r._error = self._error ?? NSError(domain: ErrorDomain, code: ErrorWrongType, userInfo: [NSLocalizedDescriptionKey: "Dictionary[\"\(key)\"] failure, It is not an dictionary"])
            }
            return r
        }
        set {
            if self.type == .dictionary && newValue.error == nil {
                self.rawDictionary[key] = newValue.object
            }
        }
    }

    /// If `sub` is `Int`, return `subscript(index:)`; If `sub` is `String`,  return `subscript(key:)`.
    fileprivate subscript(sub sub: JSONSubscriptType) -> Parcel {
        get {
            switch sub.jsonKey {
            case .index(let index): return self[index: index]
            case .key(let key): return self[key: key]
            }
        }
        set {
            switch sub.jsonKey {
            case .index(let index): self[index: index] = newValue
            case .key(let key): self[key: key] = newValue
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     - parameter path: The target json's path. Example:

     let json = JSON[data]
     let path = [9,"list","person","name"]
     let name = json[path]

     The same as: let name = json[9]["list"]["person"]["name"]

     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: [JSONSubscriptType]) -> Parcel {
        get {
            return path.reduce(self) { $0[sub: $1] }
        }
        set {
            switch path.count {
            case 0:
                return
            case 1:
                self[sub:path[0]].object = newValue.object
            default:
                var aPath = path; aPath.remove(at: 0)
                var nextJSON = self[sub: path[0]]
                nextJSON[aPath] = newValue
                self[sub: path[0]] = nextJSON
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     - parameter path: The target json's path. Example:

     let name = json[9,"list","person","name"]

     The same as: let name = json[9]["list"]["person"]["name"]

     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: JSONSubscriptType...) -> Parcel {
        get {
            return self[path]
        }
        set {
            self[path] = newValue
        }
    }
}

// MARK: - LiteralConvertible

extension Parcel: Swift.ExpressibleByStringLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self.init(value as Any)
    }

    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self.init(value as Any)
    }

    public init(unicodeScalarLiteral value: StringLiteralType) {
        self.init(value as Any)
    }
}

extension Parcel: Swift.ExpressibleByIntegerLiteral {

    public init(integerLiteral value: IntegerLiteralType) {
        self.init(value as Any)
    }
}

extension Parcel: Swift.ExpressibleByBooleanLiteral {

    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(value as Any)
    }
}

extension Parcel: Swift.ExpressibleByFloatLiteral {

    public init(floatLiteral value: FloatLiteralType) {
        self.init(value as Any)
    }
}

extension Parcel: Swift.ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let array = elements
        self.init(dictionaryLiteral: array)
    }

    public init(dictionaryLiteral elements: [(String, Any)]) {
        let jsonFromDictionaryLiteral: ([String : Any]) -> Parcel = { dictionary in
            let initializeElement = Array(dictionary.keys).flatMap { key -> (String, Any)? in
                if let value = dictionary[key] {
                    return (key, value)
                }
                return nil
            }
            return Parcel(dictionaryLiteral: initializeElement)
        }

        var dict = [String : Any](minimumCapacity: elements.count)

        for element in elements {
            let elementToSet: Any
            if let json = element.1 as? Parcel {
                elementToSet = json.object
            } else if let jsonArray = element.1 as? [Parcel] {
                elementToSet = Parcel(jsonArray).object
            } else if let dictionary = element.1 as? [String : Any] {
                elementToSet = jsonFromDictionaryLiteral(dictionary).object
            } else if let dictArray = element.1 as? [[String : Any]] {
                let jsonArray = dictArray.map { jsonFromDictionaryLiteral($0) }
                elementToSet = Parcel(jsonArray).object
            } else {
                elementToSet = element.1
            }
            dict[element.0] = elementToSet
        }

        self.init(dict)
    }
}

extension Parcel: Swift.ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Any...) {
        self.init(elements as Any)
    }
}

extension Parcel: Swift.ExpressibleByNilLiteral {

    @available(*, deprecated, message: "use JSON.null instead. Will be removed in future versions")
    public init(nilLiteral: ()) {
        self.init(NSNull() as Any)
    }
}

// MARK: - Raw

extension Parcel: Swift.RawRepresentable {

    public init?(rawValue: Any) {
        if Parcel(rawValue).type == .unknown {
            return nil
        } else {
            self.init(rawValue)
        }
    }

    public var rawValue: Any {
        return self.object
    }

    public func rawData(options opt: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions(rawValue: 0)) throws -> Data {
        guard JSONSerialization.isValidJSONObject(self.object) else {
            throw NSError(domain: ErrorDomain, code: ErrorInvalidJSON, userInfo: [NSLocalizedDescriptionKey: "JSON is invalid"])
        }

        return try JSONSerialization.data(withJSONObject: self.object, options: opt)
	}

	public func rawString(_ encoding: String.Encoding = .utf8, options opt: JSONSerialization.WritingOptions = .prettyPrinted) -> String? {
		do {
			return try _rawString(encoding, options: [.jsonSerialization: opt])
		} catch {
			print("Could not serialize object to JSON because:", error.localizedDescription)
			return nil
		}
	}

	public func rawString(_ options: [writingOptionsKeys: Any]) -> String? {
		let encoding = options[.encoding] as? String.Encoding ?? String.Encoding.utf8
		let maxObjectDepth = options[.maxObjextDepth] as? Int ?? 10
		do {
			return try _rawString(encoding, options: options, maxObjectDepth: maxObjectDepth)
		} catch {
			print("Could not serialize object to JSON because:", error.localizedDescription)
			return nil
		}
	}

	fileprivate func _rawString(
		_ encoding: String.Encoding = .utf8,
		options: [writingOptionsKeys: Any],
		maxObjectDepth: Int = 10
	) throws -> String? {
        if (maxObjectDepth < 0) {
            throw NSError(domain: ErrorDomain, code: ErrorInvalidJSON, userInfo: [NSLocalizedDescriptionKey: "Element too deep. Increase maxObjectDepth and make sure there is no reference loop"])
        }
        switch self.type {
		case .dictionary:
			do {
				if !(options[.castNilToNSNull] as? Bool ?? false) {
					let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
					let data = try self.rawData(options: jsonOption)
					return String(data: data, encoding: encoding)
				}

				guard let dict = self.object as? [String: Any?] else {
					return nil
				}
				let body = try dict.keys.map { key throws -> String in
					guard let value = dict[key] else {
						return "\"\(key)\": null"
					}
					guard let unwrappedValue = value else {
						return "\"\(key)\": null"
					}

					let nestedValue = Parcel(unwrappedValue)
					guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
						throw NSError(domain: ErrorDomain, code: ErrorInvalidJSON, userInfo: [NSLocalizedDescriptionKey: "Could not serialize nested JSON"])
					}
					if nestedValue.type == .string {
						return "\"\(key)\": \"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
					} else {
						return "\"\(key)\": \(nestedString)"
					}
				}

				return "{\(body.joined(separator: ","))}"
			} catch _ {
				return nil
			}
		case .array:
            do {
				if !(options[.castNilToNSNull] as? Bool ?? false) {
					let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
					let data = try self.rawData(options: jsonOption)
					return String(data: data, encoding: encoding)
				}

                guard let array = self.object as? [Any?] else {
                    return nil
                }
                let body = try array.map { value throws -> String in
                    guard let unwrappedValue = value else {
                        return "null"
                    }

                    let nestedValue = Parcel(unwrappedValue)
                    guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
                        throw NSError(domain: ErrorDomain, code: ErrorInvalidJSON, userInfo: [NSLocalizedDescriptionKey: "Could not serialize nested JSON"])
                    }
                    if nestedValue.type == .string {
                        return "\"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
                    } else {
                        return nestedString
                    }
                }

                return "[\(body.joined(separator: ","))]"
            } catch _ {
                return nil
            }
        case .string:
            return self.rawString
        case .number:
            return self.rawNumber.stringValue
        case .bool:
            return self.rawBool.description
        case .null:
            return "null"
        default:
            return nil
        }
    }
}

// MARK: - Printable, DebugPrintable

extension Parcel: Swift.CustomStringConvertible, Swift.CustomDebugStringConvertible {

    public var description: String {
        if let string = self.rawString(options:.prettyPrinted) {
            return string
        } else {
            return "unknown"
        }
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - Array

extension Parcel {

    //Optional [JSON]
    public var array: [Parcel]? {
        get {
            if self.type == .array {
                return self.rawArray.map{ Parcel($0) }
            } else {
                return nil
            }
        }
    }

    //Non-optional [JSON]
    public var arrayValue: [Parcel] {
        get {
            return self.array ?? []
        }
    }

    //Optional [Any]
    public var arrayObject: [Any]? {
        get {
            switch self.type {
            case .array:
                return self.rawArray
            default:
                return nil
            }
        }
        set {
            if let array = newValue {
                self.object = array as Any
            } else {
                self.object = NSNull()
            }
        }
    }
}

// MARK: - Dictionary

extension Parcel {

    //Optional [String : JSON]
    public var dictionary: [String : Parcel]? {
        if self.type == .dictionary {
            var d = [String : Parcel](minimumCapacity: rawDictionary.count)
            for (key, value) in rawDictionary {
                d[key] = Parcel(value)
            }
            return d
        } else {
            return nil
        }
    }

    //Non-optional [String : JSON]
    public var dictionaryValue: [String : Parcel] {
        return self.dictionary ?? [:]
    }

    //Optional [String : Any]

    public var dictionaryObject: [String : Any]? {
        get {
            switch self.type {
            case .dictionary:
                return self.rawDictionary
            default:
                return nil
            }
        }
        set {
            if let v = newValue {
                self.object = v as Any
            } else {
                self.object = NSNull()
            }
        }
    }
}

// MARK: - Bool

extension Parcel { // : Swift.Bool

    //Optional bool
    public var bool: Bool? {
        get {
            switch self.type {
            case .bool:
                return self.rawBool
            default:
                return nil
            }
        }
        set {
            if let newValue = newValue {
                self.object = newValue as Bool
            } else {
                self.object = NSNull()
            }
        }
    }

    //Non-optional bool
    public var boolValue: Bool {
        get {
            switch self.type {
            case .bool:
                return self.rawBool
            case .number:
                return self.rawNumber.boolValue
            case .string:
                return ["true", "y", "t"].contains() { (truthyString) in
                    return self.rawString.caseInsensitiveCompare(truthyString) == .orderedSame
                }
            default:
                return false
            }
        }
        set {
            self.object = newValue
        }
    }
}

// MARK: - String

extension Parcel {

    //Optional string
    public var string: String? {
        get {
            switch self.type {
            case .string:
                return self.object as? String
            default:
                return nil
            }
        }
        set {
            if let newValue = newValue {
                self.object = NSString(string:newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    //Non-optional string
    public var stringValue: String {
        get {
            switch self.type {
            case .string:
                return self.object as? String ?? ""
            case .number:
                return self.rawNumber.stringValue
            case .bool:
                return (self.object as? Bool).map { String($0) } ?? ""
            default:
                return ""
            }
        }
        set {
            self.object = NSString(string:newValue)
        }
    }
}

// MARK: - Number
extension Parcel {

    //Optional number
    public var number: NSNumber? {
        get {
            switch self.type {
            case .number:
                return self.rawNumber
            case .bool:
                return NSNumber(value: self.rawBool ? 1 : 0)
            default:
                return nil
            }
        }
        set {
            self.object = newValue ?? NSNull()
        }
    }

    //Non-optional number
    public var numberValue: NSNumber {
        get {
            switch self.type {
            case .string:
                let decimal = NSDecimalNumber(string: self.object as? String)
                if decimal == NSDecimalNumber.notANumber {  // indicates parse error
                    return NSDecimalNumber.zero
                }
                return decimal
            case .number:
                return self.object as? NSNumber ?? NSNumber(value: 0)
            case .bool:
                return NSNumber(value: self.rawBool ? 1 : 0)
            default:
                return NSNumber(value: 0.0)
            }
        }
        set {
            self.object = newValue
        }
    }
}

//MARK: - Null
extension Parcel {

    public var null: NSNull? {
        get {
            switch self.type {
            case .null:
                return self.rawNull
            default:
                return nil
            }
        }
        set {
            self.object = NSNull()
        }
    }
    public func exists() -> Bool{
        if let errorValue = error, errorValue.code == ErrorNotExist ||
            errorValue.code == ErrorIndexOutOfBounds ||
            errorValue.code == ErrorWrongType {
            return false
        }
        return true
    }
}

//MARK: - URL
extension Parcel {

    //Optional URL
    public var url: URL? {
        get {
            switch self.type {
            case .string:
                // Check for existing percent escapes first to prevent double-escaping of % character
                if let _ = self.rawString.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression, range: nil, locale: nil) {
                    return Foundation.URL(string: self.rawString)
                } else if let encodedString_ = self.rawString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                    // We have to use `Foundation.URL` otherwise it conflicts with the variable name.
                    return Foundation.URL(string: encodedString_)
                } else {
                    return nil
                }
            default:
                return nil
            }
        }
        set {
            self.object = newValue?.absoluteString ?? NSNull()
        }
    }
}

// MARK: - Int, Double, Float, Int8, Int16, Int32, Int64

extension Parcel {

    public var double: Double? {
        get {
            return self.number?.doubleValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    public var doubleValue: Double {
        get {
            return self.numberValue.doubleValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var float: Float? {
        get {
            return self.number?.floatValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    public var floatValue: Float {
        get {
            return self.numberValue.floatValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var int: Int?
        {
        get
        {
            return self.number?.intValue
        }
        set
        {
            if let newValue = newValue
            {
                self.object = NSNumber(value: newValue)
            } else
            {
                self.object = NSNull()
            }
        }
    }

    public var intValue: Int {
        get {
            return self.numberValue.intValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var uInt: UInt? {
        get {
            return self.number?.uintValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    public var uIntValue: UInt {
        get {
            return self.numberValue.uintValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var int8: Int8? {
        get {
            return self.number?.int8Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: Int(newValue))
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var int8Value: Int8 {
        get {
            return self.numberValue.int8Value
        }
        set {
            self.object = NSNumber(value: Int(newValue))
        }
    }

    public var uInt8: UInt8? {
        get {
            return self.number?.uint8Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var uInt8Value: UInt8 {
        get {
            return self.numberValue.uint8Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var int16: Int16? {
        get {
            return self.number?.int16Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var int16Value: Int16 {
        get {
            return self.numberValue.int16Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var uInt16: UInt16? {
        get {
            return self.number?.uint16Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var uInt16Value: UInt16 {
        get {
            return self.numberValue.uint16Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var int32: Int32? {
        get {
            return self.number?.int32Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var int32Value: Int32 {
        get {
            return self.numberValue.int32Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var uInt32: UInt32? {
        get {
            return self.number?.uint32Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var uInt32Value: UInt32 {
        get {
            return self.numberValue.uint32Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var int64: Int64? {
        get {
            return self.number?.int64Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var int64Value: Int64 {
        get {
            return self.numberValue.int64Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    public var uInt64: UInt64? {
        get {
            return self.number?.uint64Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    public var uInt64Value: UInt64 {
        get {
            return self.numberValue.uint64Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
}

//MARK: - Comparable
extension Parcel: Swift.Comparable {}

public func ==(lhs: Parcel, rhs: Parcel) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber == rhs.rawNumber
    case (.string, .string):
        return lhs.rawString == rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

public func <=(lhs: Parcel, rhs: Parcel) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber <= rhs.rawNumber
    case (.string, .string):
        return lhs.rawString <= rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

public func >=(lhs: Parcel, rhs: Parcel) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber >= rhs.rawNumber
    case (.string, .string):
        return lhs.rawString >= rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

public func >(lhs: Parcel, rhs: Parcel) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber > rhs.rawNumber
    case (.string, .string):
        return lhs.rawString > rhs.rawString
    default:
        return false
    }
}

public func <(lhs: Parcel, rhs: Parcel) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber < rhs.rawNumber
    case (.string, .string):
        return lhs.rawString < rhs.rawString
    default:
        return false
    }
}

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)

// MARK: - NSNumber: Comparable

extension NSNumber {
    var isBool:Bool {
        get {
            let objCType = String(cString: self.objCType)
            if (self.compare(trueNumber) == .orderedSame && objCType == trueObjCType) || (self.compare(falseNumber) == .orderedSame && objCType == falseObjCType){
                return true
            } else {
                return false
            }
        }
    }
}

func ==(lhs: NSNumber, rhs: NSNumber) -> Bool {
    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == .orderedSame
    }
}

func !=(lhs: NSNumber, rhs: NSNumber) -> Bool {
    return !(lhs == rhs)
}

func <(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == .orderedAscending
    }
}

func >(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == ComparisonResult.orderedDescending
    }
}

func <=(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) != .orderedDescending
    }
}

func >=(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) != .orderedAscending
    }
}

//MARK: - Date
extension Parcel {

    private static func parseDate(fromISO8601 dateStr: String)->Date?{
        let dateFmt = DateFormatter()
        dateFmt.timeZone = TimeZone(abbreviation: "UTC")!;
        dateFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        var result = dateFmt.date(from: dateStr);
        if result == nil{ // fallback
            dateFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            result = dateFmt.date(from: dateStr);
            if result == nil{ // fallback
                dateFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                result = dateFmt.date(from: dateStr);
                if result == nil{
                    dateFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
                    result = dateFmt.date(from: dateStr);
                }
            }
        }
        return result;
    }

    public var date: Date?{
        get{
            if _type == .date{
                return self.rawDate;
            }else{
                return Parcel.parseDate(fromISO8601: self.stringValue);
            }
        }
        set{
            if let newValue = newValue {
                self.object = newValue;
            } else {
                self.object =  NSNull()
            }
        }
    }
}

public enum writingOptionsKeys {
    case jsonSerialization
    case castNilToNSNull
    case maxObjextDepth
    case encoding
}

