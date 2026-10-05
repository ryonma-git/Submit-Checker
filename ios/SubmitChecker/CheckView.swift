import SwiftUI
import SubmitCore

struct CheckView: View {
    @EnvironmentObject private var store: CheckerStore
    let record: SubmissionRecord
    var export: () -> Void
    @State private var missingOnly = false
    @State private var columns = 0
    var body: some View {
        GeometryReader { geometry in
            let automatic = geometry.size.width > geometry.size.height ? (record.count > 30 ? 8 : 6) : 5
            let actualColumns = min(geometry.size.width < 500 ? 5 : 8, columns == 0 ? automatic : columns)
            let rows = (record.count + actualColumns - 1) / actualColumns
            let seatHeight = max(60, min(100, (geometry.size.height - 330) / CGFloat(rows) - 12))
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(record.classLabel) · \(record.date) · \(record.count)人").font(.subheadline).foregroundStyle(.secondary)
                            Text(record.assignment).font(.largeTitle.bold())
                        }
                        Spacer()
                        Button(action: export) { Label("CSV", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                    }
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(record.submittedCount)").font(.system(size: 40, weight: .semibold, design: .rounded)).foregroundStyle(Palette.green).monospacedDigit()
                            Text("/ \(record.count)人 提出済み").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text("未提出 \(record.count - record.submittedCount)人").font(.subheadline.weight(.semibold))
                        }
                        ProgressView(value: Double(record.submittedCount), total: Double(record.count))
                        Label("この端末に保存済み", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                    }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 14))
                    ViewThatFits(in: .horizontal) {
                        HStack { filter; Spacer(); controls }
                        VStack(alignment: .leading, spacing: 12) { filter; controls }
                    }
                    VStack(spacing: 18) {
                        Text("───　黒板・教卓　───").font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: geometry.size.width < 500 ? 6 : 12), count: actualColumns), spacing: geometry.size.width < 500 ? 6 : 12) {
                            ForEach(record.students, id: \.number) { student in seat(student, compact: geometry.size.width < 500, height: seatHeight) }
                        }
                        Text("番号をタップして提出済みに。もう一度タップで取り消せます。").font(.caption).foregroundStyle(.secondary)
                    }.padding(geometry.size.width < 500 ? 12 : 22).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    if record.submittedCount == record.count {
                        Label("全員の提出がそろいました。おつかれさまでした！", systemImage: "checkmark.seal.fill").font(.subheadline).padding(18).frame(maxWidth: .infinity).background(Palette.pale, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("大切な記録はCSVやバックアップでも保管してください。").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(geometry.size.width < 500 ? 16 : 28).frame(maxWidth: 1200).frame(maxWidth: .infinity)
            }.background(Palette.background)
        }
    }
    private var filter: some View {
        Picker("表示対象", selection: $missingOnly) { Text("全員").tag(false); Text("未提出を確認").tag(true) }.pickerStyle(.segmented).frame(maxWidth: 280)
    }
    private var controls: some View {
        HStack {
            Picker("列数", selection: $columns) { Text("自動").tag(0); ForEach([4, 5, 6, 8], id: \.self) { Text("\($0)列").tag($0) } }.pickerStyle(.menu)
            Button("ひとつ戻す", systemImage: "arrow.uturn.backward") { store.undoLast() }.buttonStyle(.bordered).disabled(store.undo?.recordID != record.id)
        }
    }
    private func seat(_ student: Student, compact: Bool, height: CGFloat) -> some View {
        let done = record.submitted[String(student.number)] != nil
        return Button { store.toggle(id: record.id, number: student.number) } label: {
            VStack(spacing: 4) {
                Text(String(format: "%02d", student.number)).font(.system(size: compact ? 25 : 34, weight: .semibold, design: .rounded)).monospacedDigit()
                if let reading = student.reading, !reading.isEmpty { Text(reading).font(.system(size: 9)) }
                if let name = student.name, !name.isEmpty { Text(name).font(.caption) }
                Text(done ? "提出済み" : "未提出").font(.system(size: compact ? 8 : 10))
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(done ? .white : Palette.green)
            .background(done ? Color(red: 0.33, green: 0.51, blue: 0.40) : Palette.background, in: RoundedRectangle(cornerRadius: 11))
            .overlay(alignment: .topTrailing) { if done { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).padding(7) } }
            .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.green.opacity(done ? 0 : 0.15)) }
        }.buttonStyle(.plain).opacity(missingOnly && done ? 0.25 : 1).disabled(store.blocked || (missingOnly && done))
            .accessibilityLabel("\(student.number)番 \(student.name ?? "") \(done ? "提出済み" : "未提出")")
            .accessibilityAddTraits(done ? .isSelected : [])
    }
}
