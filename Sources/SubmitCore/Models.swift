import Foundation

public enum CheckerError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

/// Stable number identity: optional display information never changes submission identity.
public struct Student: Codable, Equatable, Sendable {
    public var number: Int
    public var name: String?
    public var reading: String?
    /// A local asset ID, never an external image URL.
    public var photoAssetID: String?
    public init(number: Int, name: String? = nil, reading: String? = nil, photoAssetID: String? = nil) {
        self.number = number; self.name = name; self.reading = reading; self.photoAssetID = photoAssetID
    }
}

public struct SubmissionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var grade: Int
    public var classNumber: Int
    public var date: String
    public var assignment: String
    public var students: [Student]
    /// ISO8601 timestamp per submitted attendance number. Missing key means not submitted.
    public var submitted: [String: String]
    public var createdAt: String
    public var updatedAt: String
    public var classLabel: String { "\(grade)年\(classNumber)組" }
    public var count: Int { students.count }
    public var submittedCount: Int { submitted.count }
    public var identity: String { "\(grade)|\(classNumber)|\(date)|\(assignment)" }

    public init(grade: Int, classNumber: Int, date: String, assignment: String, count: Int, now: Date = Date()) throws {
        id = UUID().uuidString; self.grade = grade; self.classNumber = classNumber
        self.date = date; self.assignment = assignment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(count) else { throw CheckerError.invalid("人数は1〜40人で指定してください。") }
        students = (1...count).map { Student(number: $0) }; submitted = [:]
        createdAt = Self.timestamp(now); updatedAt = createdAt
        try validate()
    }
    public func validate() throws {
        guard (1...6).contains(grade), (1...20).contains(classNumber), (1...40).contains(count),
              !assignment.isEmpty, assignment.count <= 100,
              assignment == assignment.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty, Self.validDate(date),
              students.map(\.number).sorted() == Array(1...count),
              submitted.keys.allSatisfy({ key in students.contains { String($0.number) == key } }),
              ([createdAt, updatedAt] + Array(submitted.values)).allSatisfy({ Self.validTimestamp($0) })
        else { throw CheckerError.invalid("提出記録の形式が正しくありません。") }
    }
    public mutating func toggle(_ number: Int, now: Date = Date()) throws {
        guard students.contains(where: { $0.number == number }) else { throw CheckerError.invalid("出席番号が範囲外です。") }
        let key = String(number)
        submitted[key] = submitted[key] == nil ? Self.timestamp(now) : nil
        updatedAt = Self.timestamp(now)
    }
    private static func validTimestamp(_ value: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        if formatter.date(from: value) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) != nil
    }
    public static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    public static func day(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    private static func validDate(_ value: String) -> Bool {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let parsed = formatter.date(from: value) else { return false }
        return formatter.string(from: parsed) == value
    }
}

public struct Archive: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var records: [SubmissionRecord] = []
    public init(records: [SubmissionRecord] = []) { self.records = records }
    public func validate() throws {
        guard schemaVersion == 1, Set(records.map(\.id)).count == records.count,
              Set(records.map(\.identity)).count == records.count else { throw CheckerError.invalid("保存データの形式・バージョンが正しくありません。") }
        for record in records { try record.validate() }
    }
}

public enum CSVExporter {
    private static func cell(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = ["=", "+", "-", "@"].contains(String(trimmed.prefix(1))) || value.hasPrefix("\t") || value.hasPrefix("\r") ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    public static func export(_ records: [SubmissionRecord]) -> String {
        var rows = [["クラス", "提出日", "課題名", "出席番号", "名前", "読み仮名", "提出状況", "提出確認日時"]]
        for record in records {
            for student in record.students.sorted(by: { $0.number < $1.number }) {
                let time = record.submitted[String(student.number)]
                rows.append([record.classLabel, record.date, record.assignment, String(student.number), student.name ?? "", student.reading ?? "", time == nil ? "未提出" : "提出済み", time ?? ""])
            }
        }
        return "\u{FEFF}" + rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
}

/// Atomic writes keep the last committed archive intact if saving fails.
public struct FileArchiveRepository: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Archive {
        guard FileManager.default.fileExists(atPath: url.path) else { return Archive() }
        let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url)); try archive.validate(); return archive
    }
    public func save(_ archive: Archive) throws {
        try archive.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: url, options: .atomic)
    }
}
