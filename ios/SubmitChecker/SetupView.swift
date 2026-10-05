import SwiftUI
import SubmitCore

struct SetupView: View {
    @EnvironmentObject private var store: CheckerStore
    var open: (String) -> Void
    @State private var grade = 1
    @State private var classNumber = 1
    @State private var date = Date()
    @State private var assignment = ""
    @State private var count = 30
    private let defaults = ["漢字ノート", "計算ドリル", "音読カード", "自主学習", "プリント"]
    private var assignments: [String] { Array(Set(defaults + store.records.map(\.assignment))).sorted() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("READY FOR CLASS").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Palette.green)
                    Text("提出チェックを、\nもっとかんたんに。").font(.largeTitle.bold())
                    Text("クラスと課題を選んだら、番号をタップするだけ。").font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 22) {
                    Label("チェックの準備", systemImage: "checklist").font(.title3.bold())
                    HStack {
                        Picker("学年", selection: $grade) { ForEach(1...6, id: \.self) { Text("\($0)年").tag($0) } }
                        Picker("組", selection: $classNumber) { ForEach(1...20, id: \.self) { Text("\($0)組").tag($0) } }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        DatePicker("提出日", selection: $date, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                        Button("今日") { date = Date() }.buttonStyle(.bordered)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("課題名").font(.subheadline.weight(.semibold))
                            Spacer()
                            Menu("課題を選ぶ") { ForEach(assignments, id: \.self) { item in Button(item) { assignment = item } } }
                        }
                        TextField("課題名を入力", text: $assignment).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                        Text("新しい課題名も、そのまま入力できます。").font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("クラスの人数", selection: $count) { ForEach(1...40, id: \.self) { Text("\($0)人").tag($0) } }.pickerStyle(.menu)
                    Button {
                        if let id = store.start(grade: grade, classNumber: classNumber, date: date, assignment: assignment, count: count) { open(id) }
                    } label: {
                        HStack { Text("提出チェックを始める").fontWeight(.semibold); Spacer(); Image(systemName: "arrow.right") }.padding(12).frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).disabled(assignment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.blocked)
                    Text("同じクラス・提出日・課題の記録は、保存時の人数で再開します。").font(.caption).foregroundStyle(.secondary)
                }.padding(26).background(.white, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近の記録").font(.headline)
                    if store.records.isEmpty {
                        Text("まだ記録はありません。最初の提出チェックを始めましょう。").font(.subheadline).foregroundStyle(.secondary).padding(.vertical)
                    }
                    ForEach(store.records.prefix(3)) { record in RecordRow(record: record) { open(record.id) } }
                }
                Label("名簿なしで使えます。提出データはこの端末に保存します。", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Palette.background)
    }
}

struct RecordRow: View {
    let record: SubmissionRecord
    var open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 16) {
                Image(systemName: "doc.text").padding(12).background(Palette.pale, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.assignment).font(.headline).foregroundStyle(.primary)
                    Text("\(record.classLabel) · \(record.date)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(record.submittedCount) / \(record.count)人").font(.subheadline.monospacedDigit())
                Image(systemName: "chevron.right").font(.caption)
            }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: CheckerStore
    var open: (String) -> Void
    var export: ([SubmissionRecord]) -> Void
    @State private var search = ""
    private var records: [SubmissionRecord] { store.records.filter { search.isEmpty || "\($0.classLabel) \($0.assignment) \($0.date)".contains(search) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("保存した記録").font(.largeTitle.bold())
                TextField("クラス・課題名・日付で検索", text: $search).textFieldStyle(.roundedBorder)
                Button("表示中の記録をCSVに", systemImage: "square.and.arrow.up") { export(records) }.buttonStyle(.bordered).disabled(records.isEmpty)
                if records.isEmpty { ContentUnavailableView("記録がありません", systemImage: "tray", description: Text("提出チェックを始めると、ここに記録が残ります。")) }
                ForEach(records) { record in RecordRow(record: record) { open(record.id) } }
            }.padding(28).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(Palette.background)
    }
}
