import Foundation

/// Future OCR/Foundation Models adapters return candidates, not silently committed rosters.
public protocol RosterImporting: Sendable {
    func candidates(from data: Data) async throws -> [Student]
}
public protocol PhotoAssetResolving: Sendable {
    func localURL(for assetID: String) async throws -> URL?
}

/// Deliberately strict UTF-8 CSV. Quoted fields/embedded commas are rejected with a useful error.
/// Header: number,name,reading (optional fourth column: photoAssetID).
public struct StrictCSVRosterImporter: RosterImporting {
    public init() {}
    public func candidates(from data: Data) async throws -> [Student] { try parse(data) }
    public func parse(_ data: Data) throws -> [Student] {
        guard var text = String(data: data, encoding: .utf8) else { throw CheckerError.invalid("名簿はUTF-8のCSVにしてください。") }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while lines.last == "" { lines.removeLast() }
        guard let header = lines.first, ["number,name,reading", "number,name,reading,photoAssetID"].contains(header) else {
            throw CheckerError.invalid("見出しは number,name,reading または number,name,reading,photoAssetID にしてください。")
        }
        let columns = header.split(separator: ",").count
        let students = try lines.dropFirst().enumerated().map { offset, line -> Student in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard !line.contains("\""), fields.count == columns, let number = Int(fields[0]), String(number) == fields[0],
                  (1...40).contains(number), !fields[1].trimmingCharacters(in: .whitespaces).isEmpty else {
                throw CheckerError.invalid("名簿の\(offset + 2)行目を確認してください。引用符・カンマを含む値は利用できません。")
            }
            return Student(number: number, name: fields[1], reading: fields[2], photoAssetID: columns == 4 && !fields[3].isEmpty ? fields[3] : nil)
        }
        guard !students.isEmpty, students.count <= 40, students.map(\.number).sorted() == Array(1...students.count) else {
            throw CheckerError.invalid("出席番号は1からの連番・重複なし、1〜40人にしてください。")
        }
        return students.sorted { $0.number < $1.number }
    }
}
