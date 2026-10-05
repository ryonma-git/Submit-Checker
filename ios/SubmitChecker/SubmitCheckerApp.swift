import SwiftUI
import SubmitCore
import UniformTypeIdentifiers

@main
struct SubmitCheckerApp: App {
    @StateObject private var store = CheckerStore()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store).tint(Palette.green) }
    }
}

enum Palette {
    static let green = Color(red: 0.13, green: 0.37, blue: 0.31)
    static let background = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let pale = Color(red: 0.91, green: 0.94, blue: 0.87)
}

@MainActor
final class CheckerStore: ObservableObject {
    @Published private(set) var archive = Archive()
    @Published var error: String?
    @Published private(set) var blocked = false
    @Published var undo: UndoAction?
    struct UndoAction { let recordID: String; let number: Int; let previous: String? }
    private let repository: FileArchiveRepository
    var records: [SubmissionRecord] { archive.records.sorted { $0.updatedAt > $1.updatedAt } }
    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = FileArchiveRepository(url: root.appendingPathComponent("SubmitChecker/archive.json"))
        do { archive = try repository.load() }
        catch { blocked = true; self.error = "保存データを読み込めません。元のデータは上書きしていません。バックアップを保管し、正常なバックアップを読み込んでください。" }
    }
    func record(_ id: String) -> SubmissionRecord? { archive.records.first { $0.id == id } }
    @discardableResult
    private func commit(_ next: Archive) -> Bool {
        guard !blocked else { error = "保存データを復旧するまで変更できません。"; return false }
        do { try repository.save(next); archive = next; return true }
        catch { self.error = "保存できませんでした。変更は反映していません。\(error.localizedDescription)"; return false }
    }
    func start(grade: Int, classNumber: Int, date: Date, assignment: String, count: Int) -> String? {
        do {
            let candidate = try SubmissionRecord(grade: grade, classNumber: classNumber, date: SubmissionRecord.day(date), assignment: assignment, count: count)
            if let old = archive.records.first(where: { $0.identity == candidate.identity }) { undo = nil; return old.id }
            var next = archive; next.records.append(candidate)
            if commit(next) { undo = nil; return candidate.id }
        } catch { self.error = error.localizedDescription }
        return nil
    }
    func toggle(id: String, number: Int) {
        guard let i = archive.records.firstIndex(where: { $0.id == id }) else { return }
        var next = archive; let previous = next.records[i].submitted[String(number)]
        do {
            try next.records[i].toggle(number)
            if commit(next) { undo = UndoAction(recordID: id, number: number, previous: previous) }
        } catch { self.error = error.localizedDescription }
    }
    func undoLast() {
        guard let action = undo, let i = archive.records.firstIndex(where: { $0.id == action.recordID }) else { return }
        var next = archive; next.records[i].submitted[String(action.number)] = action.previous
        next.records[i].updatedAt = SubmissionRecord.timestamp(Date())
        if commit(next) { undo = nil }
    }
    func backup() throws -> Data {
        if blocked { return try Data(contentsOf: repository.url) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(archive)
    }
    func restore(_ data: Data) throws {
        let next = try JSONDecoder().decode(Archive.self, from: data); try next.validate(); try repository.save(next)
        archive = next; blocked = false; undo = nil
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct ContentView: View {
    @EnvironmentObject private var store: CheckerStore
    @State private var tab = 0
    @State private var selectedID: String?
    @State private var exportDocument = ExportDocument(data: Data())
    @State private var exportType: UTType = .commaSeparatedText
    @State private var exportName = "提出記録"
    @State private var showExport = false
    @State private var showImport = false
    @State private var pendingRestore: Data?
    @State private var showRestoreConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let id = selectedID, let record = store.record(id) {
                    CheckView(record: record, export: { exportCSV([record]) })
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) { Button("設定に戻る", systemImage: "chevron.left") { selectedID = nil; store.undo = nil } }
                        }
                } else {
                    TabView(selection: $tab) {
                        SetupView { selectedID = $0 }.tabItem { Label("提出チェック", systemImage: "square.grid.3x3") }.tag(0)
                        HistoryView(open: { store.undo = nil; selectedID = $0 }, export: exportCSV)
                            .tabItem { Label("保存した記録", systemImage: "clock.arrow.circlepath") }.tag(1)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("バックアップを書き出す", systemImage: "square.and.arrow.up") {
                                    do { exportDocument = ExportDocument(data: try store.backup()); exportType = .json; exportName = "提出チェッカー_backup_\(SubmissionRecord.day(Date()))"; showExport = true }
                                    catch { store.error = error.localizedDescription }
                                }
                                Button("バックアップを読み込む", systemImage: "square.and.arrow.down") { showImport = true }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
            }
            .navigationTitle("提出チェッカー").navigationBarTitleDisplayMode(.inline)
            .background(Palette.background)
        }
        .alert("確認してください", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("閉じる", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .fileExporter(isPresented: $showExport, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
            if case .failure(let error) = result { store.error = error.localizedDescription }
        }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count <= 20 * 1024 * 1024 else { throw CheckerError.invalid("20MB以下のバックアップを選んでください。") }
                let archive = try JSONDecoder().decode(Archive.self, from: data); try archive.validate()
                pendingRestore = data; showRestoreConfirmation = true
            } catch { store.error = error.localizedDescription }
        }
        .confirmationDialog("現在の記録をバックアップの内容で置き換えます。現在の記録は先に書き出してください。", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            Button("記録を置き換える", role: .destructive) {
                guard let data = pendingRestore else { return }
                do { try store.restore(data); selectedID = nil; tab = 1 } catch { store.error = error.localizedDescription }
                pendingRestore = nil
            }
            Button("キャンセル", role: .cancel) { pendingRestore = nil }
        }
    }
    private func exportCSV(_ records: [SubmissionRecord]) {
        exportDocument = ExportDocument(data: Data(CSVExporter.export(records).utf8)); exportType = .commaSeparatedText
        if let r = records.first, records.count == 1 {
            exportName = "\(r.date)_\(r.classLabel)_\(r.assignment)".components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|\n\r")).joined(separator: "_")
        } else { exportName = "提出記録_\(SubmissionRecord.day(Date()))" }
        showExport = true
    }
}
