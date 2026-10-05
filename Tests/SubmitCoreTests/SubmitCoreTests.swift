import Foundation
import Testing
@testable import SubmitCore

func sample(count: Int = 30, assignment: String = "漢字ノート") throws -> SubmissionRecord {
    try SubmissionRecord(grade: 3, classNumber: 2, date: "2026-10-06", assignment: assignment, count: count)
}
@Test func boundsAndIdentity() throws {
    let record = try sample(); #expect(record.count == 30); #expect(record.classLabel == "3年2組")
    #expect(throws: CheckerError.self) { try sample(count: 0) }
    #expect(throws: CheckerError.self) { try sample(count: 41) }
    #expect(try sample(count: 40).students.last?.number == 40)
    #expect(throws: CheckerError.self) { try sample(assignment: "  ") }
    #expect(throws: CheckerError.self) { try SubmissionRecord(grade: 1, classNumber: 1, date: "2026-02-30", assignment: "test", count: 30) }
}
@Test func toggleAndRoundTrip() throws {
    var record = try sample(count: 40); try record.toggle(40); #expect(record.submittedCount == 1)
    try record.validate()
    let data = try JSONEncoder().encode(Archive(records: [record])); let restored = try JSONDecoder().decode(Archive.self, from: data)
    #expect(restored.records[0] == record); try restored.validate()
    try record.toggle(40); #expect(record.submittedCount == 0)
    #expect(throws: CheckerError.self) { try record.toggle(41) }
}
@Test func atomicPersistenceAndInvalidData() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = FileArchiveRepository(url: root.appendingPathComponent("archive.json")); #expect(try repo.load().records.isEmpty)
    var record = try sample(); try record.toggle(1); let archive = Archive(records: [record]); try repo.save(archive)
    #expect(try repo.load() == archive)
    var bad = archive; bad.schemaVersion = 99
    #expect(throws: CheckerError.self) { try repo.save(bad) }; #expect(try repo.load() == archive)
    try Data("broken".utf8).write(to: repo.url)
    #expect(throws: (any Error).self) { try repo.load() }
    #expect(try String(contentsOf: repo.url, encoding: .utf8) == "broken")
}
@Test func duplicateAndIsolation() throws {
    var first = try sample(); let second = try sample(assignment: "計算ドリル"); try first.toggle(1)
    let archive = Archive(records: [first, second]); try archive.validate(); #expect(second.submittedCount == 0)
    #expect(throws: CheckerError.self) { try Archive(records: [first, first]).validate() }
}
@Test func csvEscapesAndAllStudents() throws {
    var record = try sample(count: 2, assignment: "=SUM(1,2)\"課題"); try record.toggle(2)
    let output = CSVExporter.export([record]); #expect(output.hasPrefix("\u{FEFF}")); #expect(output.contains("\"'=SUM(1,2)\"\"課題\""))
    #expect(output.contains("未提出")); #expect(output.contains("提出済み")); #expect(output.components(separatedBy: "\r\n").count == 4)
}
@Test func strictRoster() throws {
    let parser = StrictCSVRosterImporter()
    let students = try parser.parse(Data("number,name,reading\n1,架空一,かくういち\n2,架空二,かくうに\n".utf8))
    #expect(students.count == 2); #expect(students[1].reading == "かくうに")
    #expect(throws: CheckerError.self) { try parser.parse(Data("number,name,reading\n1,A,a\n1,B,b".utf8)) }
    #expect(throws: CheckerError.self) { try parser.parse(Data("番号,名前\n1,A".utf8)) }
    #expect(throws: CheckerError.self) { try parser.parse(Data("number,name,reading\n2,A,a".utf8)) }
}
