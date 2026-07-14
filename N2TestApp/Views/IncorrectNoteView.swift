// IncorrectNoteView.swift

import SwiftUI
import AVFoundation
import UIKit

private extension Color {
    static func noteBackground(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.09, green: 0.09, blue: 0.10) : Color(red: 0.95, green: 0.94, blue: 0.97)
    }
    static func noteCard(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.13, green: 0.13, blue: 0.16) : Color(red: 0.993, green: 0.990, blue: 0.998)
    }
    static func noteBorder(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.28, green: 0.28, blue: 0.38) : Color(red: 0.52, green: 0.50, blue: 0.65)
    }
    static var noteBlue: Color { Color(red: 0.09, green: 0.26, blue: 0.68) }
    static var noteGold: Color { Color(red: 0.70, green: 0.48, blue: 0.08) }
}

extension View {
    @ViewBuilder func transparentScrollBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self.onAppear { UITableView.appearance().backgroundColor = .clear }
        }
    }
}

private enum NoteSubject: String, CaseIterable, Identifiable {
    case reading = "Reading"
    case listening = "Listening"
    var id: String { rawValue }

    // 🌟 다국어 번역을 위한 뷰 전용 프로퍼티 추가
    var titleKey: LocalizedStringKey {
        switch self {
        case .reading: return "note.subject.reading"
        case .listening: return "note.subject.listening"
        }
    }
}

// MARK: - Data Models
private struct ReadingIncorrectItem: Identifiable {
    let note: IncorrectNote
    let setNumber: Int
    let group: QuestionGroup
    let questionIndex: Int
    var id: Int { note.id }

    var question: Question? {
        guard let pos = group.questionIndices.firstIndex(of: questionIndex), pos < group.questions.count else { return nil }
        return group.questions[pos]
    }
    
    var passageText: String? { group.isMulti ? group.sharedPassage : question?.question }
    var passageUnderline: [String] { group.isMulti ? group.sharedUnderline : (question?.underline ?? []) }
    var passageImageName: String? { group.isMulti ? group.sharedImageName : question?.imageName }
    
    var promptText: String? { guard group.isMulti, let q = question else { return nil }; return q.subQuestion ?? q.question }
    var promptImageName: String? { group.isMulti ? question?.imageName : nil }
    
    var previewText: String { (promptText ?? passageText ?? question?.options.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
}

private struct ListeningIncorrectItem: Identifiable {
    let note: IncorrectNote
    let setNumber: Int
    let question: AudioQuestion
    var id: Int { note.id }

    var scriptText: String? {
        let text = question.localizedScript()?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (text?.isEmpty ?? true) ? nil : text
    }
}

class SimpleAudioDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.onFinish() }
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Main View
struct IncorrectNoteView: View {
    @Binding var isTabBarHidden: Bool
    
    @State private var subject: NoteSubject = .reading
    @State private var readingItems: [ReadingIncorrectItem] = []
    @State private var listeningItems: [ListeningIncorrectItem] = []

    @State private var selectedReadingItem: ReadingIncorrectItem?
    @State private var selectedListeningItem: ListeningIncorrectItem?

    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showPurchaseView = false

    @Environment(\.colorScheme) private var colorScheme
    private var cs: ColorScheme { colorScheme }

    var body: some View {
        VStack(spacing: 0) {
            AdaptiveTopBannerView()
            
            VStack(spacing: 0) {
                header

                Picker("", selection: $subject) {
                    // 🌟 수정: s.rawValue -> s.titleKey
                    ForEach(NoteSubject.allCases) { s in Text(s.titleKey).tag(s) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)

                Group {
                    if subject == .reading {
                        if readingItems.isEmpty { emptyState } else { readingList }
                    } else {
                        if listeningItems.isEmpty { emptyState } else { listeningList }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !storeManager.isSubscribed {
                    premiumBanner.padding(16)
                }
            }
            .background(Color.noteBackground(cs).ignoresSafeArea())
            
            AdaptiveBottomBannerView()
        }
        .onAppear {
            if storeManager.isSubscribed { UserDefaults.standard.set(true, forKey: "hasEverSubscribed") }
            reload()
        }
        .onChange(of: subject) { _, _ in reload() }
        .onChange(of: storeManager.isSubscribed) { _, isSub in
            if isSub { UserDefaults.standard.set(true, forKey: "hasEverSubscribed") }
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("incorrectNotesDidUpdate"))) { _ in reload() }
        // 🌟 복원 후 즉시 갱신
        .onReceive(NotificationCenter.default.publisher(for: .jlptCloudRestoreCompleted)) { _ in reload() }
        .fullScreenCover(item: $selectedReadingItem) { item in ReadingNoteDetailView(item: item) }
        .fullScreenCover(item: $selectedListeningItem) { item in ListeningNoteDetailView(item: item) }
        .fullScreenCover(isPresented: $showPurchaseView) { PurchaseView() }
    }

    private var header: some View {
        Text("오답 노트")
            .font(.system(size: 22, weight: .bold)).foregroundColor(cs == .dark ? .white : .black)
            .frame(maxWidth: .infinity, alignment: .center).padding(.horizontal, 16).padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal").font(.system(size: 44, weight: .light))
                .foregroundColor(cs == .dark ? .white.opacity(0.25) : .black.opacity(0.18))
            Text("저장된 오답이 없습니다").font(.system(size: 15, weight: .medium))
                .foregroundColor(cs == .dark ? .white.opacity(0.5) : .black.opacity(0.4))
        }
    }

    private var readingList: some View {
        List {
            ForEach(readingItems) { item in
                Button { selectedReadingItem = item } label: {
                    noteRow(badge: "\(item.setNumber)회", subtitle: "\(item.questionIndex + 1)번", preview: item.previewText, timestamp: item.note.timestamp)
                }
                .buttonStyle(.plain).listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden).listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { deleteReadingItem(item) } label: { Label("삭제", systemImage: "trash") }
                }
            }
        }
        .listStyle(.plain).transparentScrollBackground().padding(.top, 8)
    }

    private var listeningList: some View {
        List {
            ForEach(listeningItems) { item in
                Button { selectedListeningItem = item } label: {
                    noteRow(badge: "\(item.setNumber)회", subtitle: "음성 문항", preview: item.question.question, timestamp: item.note.timestamp)
                }
                .buttonStyle(.plain).listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden).listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { deleteListeningItem(item) } label: { Label("삭제", systemImage: "trash") }
                }
            }
        }
        .listStyle(.plain).transparentScrollBackground().padding(.top, 8)
    }

    private func noteRow(badge: String, subtitle: String, preview: String, timestamp: Date) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(badge).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.noteBlue).clipShape(RoundedRectangle(cornerRadius: 4))
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundColor(cs == .dark ? .white.opacity(0.5) : .black.opacity(0.4))
            }.frame(width: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.isEmpty ? "내용을 불러올 수 없습니다" : preview).font(.custom("Hiragino Sans", size: 14, relativeTo: .body))
                    .foregroundColor(cs == .dark ? .white.opacity(0.88) : .black.opacity(0.82)).lineLimit(2).multilineTextAlignment(.leading)
                Text(Self.relativeDateText(timestamp)).font(.system(size: 11)).foregroundColor(cs == .dark ? .white.opacity(0.4) : .black.opacity(0.35))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(cs == .dark ? .white.opacity(0.3) : .black.opacity(0.25))
        }
        .padding(14).background(Color.noteCard(cs)).clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.noteBorder(cs).opacity(0.4), lineWidth: 1))
    }

    private static func relativeDateText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter(); formatter.locale = Locale(identifier: "ko_KR"); formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var premiumBanner: some View {
        Button(action: { showPurchaseView = true }) {
            HStack(spacing: 16) {
                Image(systemName: "crown.fill").font(.system(size: 32)).foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("프리미엄 기능 잠금 해제").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Text("구독 시 모든 모의고사 및 오답노트를 무제한으로 학습할 수 있습니다.").font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.7))
            }
            .padding(16).background(LinearGradient(colors: [Color(red: 0.1, green: 0.2, blue: 0.4), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(16).shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }.buttonStyle(.plain)
    }

    // 🌟 수정됨: 읽기, 듣기 목록을 항상 모두 업데이트
    private func reload() {
        readingItems = Self.fetchReadingItems(isSubscribed: storeManager.isSubscribed)
        listeningItems = Self.fetchListeningItems(isSubscribed: storeManager.isSubscribed)
    }

    private func deleteReadingItem(_ item: ReadingIncorrectItem) {
        DatabaseManager.shared.deleteIncorrectAnswer(level: item.note.level, quizGroup: item.note.quizGroup, questionIndex: item.questionIndex)
        readingItems.removeAll { $0.id == item.id }
    }

    private func deleteListeningItem(_ item: ListeningIncorrectItem) {
        DatabaseManager.shared.deleteIncorrectAnswer(level: item.note.level, quizGroup: item.note.quizGroup, questionIndex: item.note.questionIndex)
        listeningItems.removeAll { $0.id == item.id }
    }

    private static func setNumber(from quizGroup: String, prefix: String) -> Int? {
        guard quizGroup.hasPrefix(prefix) else { return nil }
        return Int(quizGroup.dropFirst(prefix.count))
    }

    private static func fetchReadingItems(isSubscribed: Bool) -> [ReadingIncorrectItem] {
        let notes = DatabaseManager.shared.fetchIncorrectNotes(level: "JLPTN3")
        var cache: [Int: (questions: [Question], groups: [QuestionGroup])] = [:]
        var items: [ReadingIncorrectItem] = []

        for note in notes {
            guard let setNum = setNumber(from: note.quizGroup, prefix: "Group1_set") else { continue }

            let isFreeScope = (setNum == 1 && note.questionIndex <= 4)
            if !isSubscribed && (!isFreeScope || note.requiresSubscription) { continue }

            let cached: (questions: [Question], groups: [QuestionGroup])
            if let c = cache[setNum] { cached = c } else {
                let qs = DataLoader.load(set: setNum); let gs = DataLoader.groupQuestions(qs)
                cached = (qs, gs); cache[setNum] = cached
            }

            guard note.questionIndex < cached.questions.count,
                  let group = cached.groups.first(where: { $0.questionIndices.contains(note.questionIndex) }) else { continue }
            items.append(ReadingIncorrectItem(note: note, setNumber: setNum, group: group, questionIndex: note.questionIndex))
        }
        return items
    }

    private static func fetchListeningItems(isSubscribed: Bool) -> [ListeningIncorrectItem] {
        let notes = DatabaseManager.shared.fetchIncorrectNotes(level: "JLPTN3Audio")
        var cache: [Int: [AudioQuestion]] = [:]
        var items: [ListeningIncorrectItem] = []

        for note in notes {
            guard let setNum = setNumber(from: note.quizGroup, prefix: "Group2_set") else { continue }

            let isFreeScope = (setNum == 1 && note.questionIndex <= 2)
            if !isSubscribed && (!isFreeScope || note.requiresSubscription) { continue }

            let qs: [AudioQuestion]
            if let c = cache[setNum] { qs = c } else { qs = AudioDataLoader.load(set: setNum); cache[setNum] = qs }
            guard note.questionIndex < qs.count else { continue }
            items.append(ListeningIncorrectItem(note: note, setNumber: setNum, question: qs[note.questionIndex]))
        }
        return items
    }
}

// MARK: - Reading Detail View
private struct ReadingNoteDetailView: View {
    let item: ReadingIncorrectItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var cs: ColorScheme { colorScheme }

    @State private var showExplanation = true
    @State private var fullscreenImageItem: IdentifiableImage?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .center, spacing: 16) {
                        Spacer()
                        let pText = item.passageText ?? ""
                        let pImage = item.passageImageName
                        if !pText.isEmpty || (pImage != nil && !pImage!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                            sectionBox(title: "지  문", content: pText, underline: item.passageUnderline, imageName: pImage, accent: .noteBlue)
                        }
                        
                        let prText = item.promptText ?? ""
                        let prImage = item.promptImageName
                        if !prText.isEmpty || (prImage != nil && !prImage!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                            sectionBox(title: "문  제", content: prText, underline: item.question?.underline ?? [], imageName: prImage, accent: .noteBlue)
                        }

                        if let q = item.question {
                            if let expl = q.localizedExplanation, !expl.isEmpty {
                                explanationPanel(text: expl, showExpl: $showExplanation, accent: .noteGold)
                            }
                            examOptions(question: q)
                        } else {
                            Text("문제 데이터를 불러올 수 없습니다.").font(.system(size: 14)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
                        }
                        Spacer()
                    }
                    .padding(16).frame(minHeight: proxy.size.height)
                }
            }
            .background(Color.noteBackground(cs).ignoresSafeArea())
            .navigationTitle("\(item.setNumber)회 · \(item.questionIndex + 1)번")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(cs == .dark ? .white.opacity(0.8) : .black.opacity(0.7)).padding(4)
                    }
                }
            }
            .fullScreenCover(item: $fullscreenImageItem) { item in
                FullscreenImageView(image: item.image) { fullscreenImageItem = nil }
            }
        }
    }

    private func applyUnderline(to text: String, underlinedWords: [String]) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        for word in underlinedWords {
            var range = (text as NSString).range(of: word)
            while range.location != NSNotFound {
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                attributed.addAttribute(.underlineColor, value: UIColor.systemBlue, range: range)
                let next = range.location + range.length
                guard next < text.count else { break }
                range = (text as NSString).range(of: word, options: [], range: NSRange(location: next, length: text.count - next))
            }
        }
        return attributed
    }

    @ViewBuilder private func sectionBox(title: String, content: String, underline: [String], imageName: String? = nil, accent: Color) -> some View {
        VStack(alignment: .center, spacing: 10) {
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 4)
                Text(title).font(.system(size: 9, weight: .bold)).foregroundColor(accent).kerning(2).padding(.leading, 10)
                Spacer()
            }
            .frame(height: 18)

            if !content.isEmpty {
                Text(AttributedString(applyUnderline(to: content, underlinedWords: underline)))
                    .font(.custom("Hiragino Sans", size: 16, relativeTo: .body))
                    .foregroundColor(cs == .dark ? .white.opacity(0.88) : Color(red: 0.08, green: 0.06, blue: 0.12))
                    .lineSpacing(9).multilineTextAlignment(.center).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .center).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
            }
            
            if let name = imageName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let img = UIImage(named: name) {
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 4)
                    .onTapGesture {
                        fullscreenImageItem = IdentifiableImage(image: img)
                    }
            }
        }
        .padding(14).background(Color.noteCard(cs)).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.noteBorder(cs), lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Rectangle().fill(accent).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    @ViewBuilder private func examOptions(question: Question) -> some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { idx, option in
                let isCorrect = option == question.answer

                Button { } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(AttributedString(applyUnderline(to: option, underlinedWords: question.underline)))
                            .font(.custom("Hiragino Sans", size: 15, relativeTo: .body))
                            .foregroundColor(isCorrect ? Color.green : cs == .dark ? .white.opacity(0.88) : Color(red: 0.08, green: 0.06, blue: 0.12))
                            .multilineTextAlignment(.center).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .center).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(isCorrect ? Color.green.opacity(0.06) : Color.clear)
                    .contentShape(Rectangle())
                    .overlay(alignment: .trailing) {
                        if isCorrect { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.green).padding(.trailing, 12) }
                    }
                }
                .disabled(true).buttonStyle(.plain)

                if idx < question.options.count - 1 {
                    Rectangle().fill(Color.noteBorder(cs).opacity(0.22)).frame(height: 1).padding(.horizontal, 12)
                }
            }
        }
        .background(Color.noteCard(cs)).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.noteBorder(cs), lineWidth: 1.5))
    }

    @ViewBuilder private func explanationPanel(text: String, showExpl: Binding<Bool>, accent: Color) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showExpl.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text("해  설").font(.system(size: 10, weight: .bold)).foregroundColor(.white).kerning(2)
                        .padding(.horizontal, 9).padding(.vertical, 4).background(Color(red: 0.52, green: 0.37, blue: 0.06)).clipShape(RoundedRectangle(cornerRadius: 2))
                    Spacer()
                    Image(systemName: showExpl.wrappedValue ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundColor(cs == .dark ? accent.opacity(0.7) : accent)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(cs == .dark ? Color(red: 0.18, green: 0.15, blue: 0.07) : Color(red: 1.0, green: 0.97, blue: 0.88))
            }
            .buttonStyle(.plain)

            if showExpl.wrappedValue {
                VStack(alignment: .center, spacing: 0) {
                    Rectangle().fill(accent.opacity(0.35)).frame(height: 1)
                    Text(text)
                        .font(.custom("Hiragino Sans", size: 13, relativeTo: .body))
                        .foregroundColor(cs == .dark ? .white.opacity(0.82) : Color(red: 0.15, green: 0.12, blue: 0.04))
                        .lineSpacing(6).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true).padding(14)
                }
                .background(cs == .dark ? Color(red: 0.14, green: 0.12, blue: 0.05) : Color(red: 1.0, green: 0.98, blue: 0.92))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(cs == .dark ? 0.45 : 0.55), lineWidth: 1.5))
    }
}

// MARK: - Listening Detail View
private struct ListeningNoteDetailView: View {
    let item: ListeningIncorrectItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var cs: ColorScheme { colorScheme }

    @State private var isPlaying: Bool = false
    @State private var audioProgress: Float = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var updateTimer: Timer?
    @State private var endTimeTimer: Timer?
    @State private var isScrubbing: Bool = false
    @State private var wasPlayingBeforeScrub: Bool = false
    @State private var audioDelegate: SimpleAudioDelegate?

    @State private var showScript = true
    @State private var fullscreenImageItem: IdentifiableImage?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .center, spacing: 16) {
                        Spacer()
                        audioPlayerPanel
                        
                        let qText = item.question.question
                        let qImage = item.question.imageName
                        if !qText.isEmpty || (qImage != nil && !qImage!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                            sectionBox(title: "문  제", content: qText, imageName: qImage, accent: .noteBlue)
                        }

                        if let script = item.scriptText {
                            scriptPanel(text: script, showScript: $showScript, accent: .noteGold)
                        }
                        examOptions(question: item.question)
                        Spacer()
                    }
                    .padding(16).frame(minHeight: proxy.size.height)
                }
            }
            .background(Color.noteBackground(cs).ignoresSafeArea())
            .navigationTitle("\(item.setNumber)회 · 음성 문항")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(cs == .dark ? .white.opacity(0.8) : .black.opacity(0.7)).padding(4)
                    }
                }
            }
            .fullScreenCover(item: $fullscreenImageItem) { item in
                FullscreenImageView(image: item.image) { fullscreenImageItem = nil }
            }
            .onAppear { setupAudio() }
            .onDisappear { stopAudio() }
        }
    }

    private var audioPlayerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.noteBlue).frame(width: 4)
                Text("음  성").font(.system(size: 9, weight: .bold)).foregroundColor(Color.noteBlue).kerning(2).padding(.leading, 10)
                Spacer()
                if isPlaying {
                    HStack(spacing: 3) {
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 1).fill(Color.noteBlue)
                                .frame(width: 3, height: CGFloat([6, 10, 7][i]))
                                .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.13), value: isPlaying)
                        }
                    }
                    .padding(.trailing, 14)
                }
            }
            .frame(height: 22).padding(.top, 12)

            GeometryReader { g in
                let width = max(g.size.width, 1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.noteBorder(cs).opacity(0.30)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(Color.noteBlue.opacity(0.75))
                        .frame(width: width * CGFloat(audioProgress), height: 4)
                        .animation(.linear(duration: 0.1), value: audioProgress)
                    Circle().fill(Color.noteBlue).frame(width: 10, height: 10)
                        .offset(x: width * CGFloat(audioProgress) - 5)
                        .animation(.linear(duration: 0.1), value: audioProgress)
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard let player = audioPlayer else { return }
                            let x = min(max(0, value.location.x), width)
                            let ratio = Double(x / width)
                            let (start, end): (Double, Double) = {
                                if let s = item.question.startTime, let e = item.question.endTime, e > s { return (s, e) }
                                return (0, player.duration)
                            }()
                            let duration = max(end - start, 0.0001)
                            let newTime = start + ratio * duration
                            player.currentTime = min(max(newTime, start), end)
                            audioProgress = Float((player.currentTime - start) / duration)
                            if isPlaying { startProgressUpdateTimer(); setupEndTimeTimer() }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = min(max(0, value.location.x), width)
                            let ratio = Double(x / width)
                            let (start, end): (Double, Double) = {
                                if let s = item.question.startTime, let e = item.question.endTime, e > s { return (s, e) }
                                if let d = audioPlayer?.duration { return (0, d) }
                                return (0, 1)
                            }()
                            _ = max(end - start, 0.0001)

                            if !isScrubbing {
                                wasPlayingBeforeScrub = isPlaying
                                if isPlaying { audioPlayer?.pause() }
                                updateTimer?.invalidate(); updateTimer = nil
                                endTimeTimer?.invalidate(); endTimeTimer = nil
                                isScrubbing = true
                            }
                            audioProgress = Float(min(max(ratio, 0.0), 1.0))
                        }
                        .onEnded { value in
                            guard let player = audioPlayer else { isScrubbing = false; return }
                            let x = min(max(0, value.location.x), width)
                            let ratio = Double(x / width)
                            let (start, end): (Double, Double) = {
                                if let s = item.question.startTime, let e = item.question.endTime, e > s { return (s, e) }
                                return (0, player.duration)
                            }()
                            let duration = max(end - start, 0.0001)
                            let newTime = start + ratio * duration
                            player.currentTime = min(max(newTime, start), end)
                            audioProgress = Float((player.currentTime - start) / duration)

                            if wasPlayingBeforeScrub {
                                player.play(); isPlaying = true
                                startProgressUpdateTimer(); setupEndTimeTimer()
                            } else {
                                isPlaying = false
                            }
                            wasPlayingBeforeScrub = false
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 10)
            HStack {
                Text(formatTime(audioProgress: audioProgress)).font(.system(size: 10, design: .monospaced))
                    .foregroundColor(cs == .dark ? .white.opacity(0.45) : .black.opacity(0.35))
                Spacer()
                Text(totalDurationText).font(.system(size: 10, design: .monospaced))
                    .foregroundColor(cs == .dark ? .white.opacity(0.45) : .black.opacity(0.35))
            }
            .padding(.horizontal, 14).padding(.top, 10)

            HStack(spacing: 12) {
                Button { togglePlayPause() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: 13, weight: .medium))
                        Text(isPlaying ? "일시정지" : "재  생").font(.custom("Hiragino Sans", size: 12)).kerning(isPlaying ? 0 : 2)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.noteBlue).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Button { restartCurrentAudio() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 13, weight: .medium))
                        Text("처음부터").font(.custom("Hiragino Sans", size: 12))
                    }
                    .foregroundColor(cs == .dark ? .white.opacity(0.65) : Color.noteBorder(cs))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.noteCard(cs)).clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.noteBorder(cs), lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 14)
        }
        .background(Color.noteCard(cs)).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.noteBorder(cs), lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Rectangle().fill(Color.noteBlue).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch { print("오디오 세션 설정 실패: \(error)") }
    }

    private func setupAudio() {
        let name = (item.question.audioFileName as NSString).deletingPathExtension
        let ext = (item.question.audioFileName as NSString).pathExtension.isEmpty ? "mp3" : (item.question.audioFileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        do {
            configureAudioSession()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            if let s = item.question.startTime, let e = item.question.endTime, e > s {
                audioPlayer?.currentTime = s
                setupEndTimeTimer()
            } else {
                audioPlayer?.currentTime = 0
                endTimeTimer?.invalidate()
            }

            audioDelegate = SimpleAudioDelegate {
                self.isPlaying = false
                self.audioProgress = 0
                if let start = self.item.question.startTime { self.audioPlayer?.currentTime = start }
                else { self.audioPlayer?.currentTime = 0 }
            }
            audioPlayer?.delegate = audioDelegate

        } catch { print("오디오 플레이어 초기화 실패: \(error)") }
    }

    private func togglePlayPause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause(); isPlaying = false; endTimeTimer?.invalidate()
        } else {
            if let s = item.question.startTime, let e = item.question.endTime {
                if player.currentTime < s || player.currentTime >= e { player.currentTime = s }
            } else {
                if player.currentTime >= player.duration { player.currentTime = 0 }
            }
            player.play(); isPlaying = true
            startProgressUpdateTimer(); setupEndTimeTimer()
        }
    }

    private func restartCurrentAudio() {
        guard let player = audioPlayer else { return }
        if let s = item.question.startTime, let e = item.question.endTime, e > s {
            player.currentTime = s; setupEndTimeTimer()
        } else { player.currentTime = 0; endTimeTimer?.invalidate() }
        player.play(); isPlaying = true
        startProgressUpdateTimer()
    }

    private func stopAudio() {
        audioPlayer?.stop()
        if let s = item.question.startTime { audioPlayer?.currentTime = s }
        else { audioPlayer?.currentTime = 0 }
        updateTimer?.invalidate(); updateTimer = nil
        endTimeTimer?.invalidate(); endTimeTimer = nil
        isPlaying = false
        audioProgress = 0
    }

    private func setupEndTimeTimer() {
        endTimeTimer?.invalidate(); endTimeTimer = nil
        guard let player = audioPlayer,
              let s = item.question.startTime, let e = item.question.endTime, e > s else { return }
        if player.currentTime < s { player.currentTime = s }
        let remaining = e - player.currentTime
        if remaining > 0 {
            endTimeTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { _ in
                self.audioPlayer?.pause(); self.isPlaying = false
                if let start = self.item.question.startTime { self.audioPlayer?.currentTime = start }
            }
        }
    }

    private func startProgressUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.audioPlayer else { return }
            if let s = item.question.startTime, let e = item.question.endTime, e > s {
                let duration = e - s; let offset = player.currentTime - s
                self.audioProgress = duration > 0 ? Float(max(0, min(offset / duration, 1.0))) : 0
                if player.currentTime >= e { self.audioPlayer?.pause(); self.isPlaying = false }
            } else {
                self.audioProgress = player.duration > 0 ? Float(player.currentTime / player.duration) : 0
                if !player.isPlaying && player.currentTime >= player.duration { self.isPlaying = false; self.updateTimer?.invalidate() }
            }
            self.isPlaying = player.isPlaying
        }
    }

    private func formatTime(audioProgress: Float) -> String {
        guard let player = audioPlayer else { return "0:00" }
        let duration: Double
        if let s = item.question.startTime, let e = item.question.endTime, e > s { duration = e - s }
        else { duration = player.duration }
        let elapsed = Double(audioProgress) * duration
        return String(format: "%d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
    }

    private var totalDurationText: String {
        guard let player = audioPlayer else { return "0:00" }
        let duration: Double
        if let s = item.question.startTime, let e = item.question.endTime, e > s { duration = e - s }
        else { duration = player.duration }
        return String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)
    }

    @ViewBuilder private func sectionBox(title: String, content: String, imageName: String? = nil, accent: Color) -> some View {
        VStack(alignment: .center, spacing: 10) {
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 4)
                Text(title).font(.system(size: 9, weight: .bold)).foregroundColor(accent).kerning(2).padding(.leading, 10)
                Spacer()
            }
            .frame(height: 18)

            if !content.isEmpty {
                Text(content)
                    .font(.custom("Hiragino Sans", size: 16, relativeTo: .body))
                    .foregroundColor(cs == .dark ? .white.opacity(0.88) : Color(red: 0.08, green: 0.06, blue: 0.12))
                    .lineSpacing(9).multilineTextAlignment(.center).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .center).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
            }
            
            if let name = imageName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let img = UIImage(named: name) {
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 4)
                    .onTapGesture {
                        fullscreenImageItem = IdentifiableImage(image: img)
                    }
            }
        }
        .padding(14).background(Color.noteCard(cs)).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.noteBorder(cs), lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Rectangle().fill(accent).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    @ViewBuilder private func scriptPanel(text: String, showScript: Binding<Bool>, accent: Color) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showScript.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text("스크립트").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color(red: 0.52, green: 0.37, blue: 0.06)).clipShape(RoundedRectangle(cornerRadius: 2))
                    Spacer()
                    Image(systemName: showScript.wrappedValue ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundColor(cs == .dark ? accent.opacity(0.7) : accent)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(cs == .dark ? Color(red: 0.18, green: 0.15, blue: 0.07) : Color(red: 1.0, green: 0.97, blue: 0.88))
            }
            .buttonStyle(.plain)

            if showScript.wrappedValue {
                VStack(alignment: .center, spacing: 0) {
                    Rectangle().fill(accent.opacity(0.35)).frame(height: 1)
                    Text(text)
                        .font(.custom("Hiragino Sans", size: 13, relativeTo: .body))
                        .foregroundColor(cs == .dark ? .white.opacity(0.82) : Color(red: 0.15, green: 0.12, blue: 0.04))
                        .lineSpacing(7).multilineTextAlignment(.center).frame(maxWidth: .infinity, alignment: .center).fixedSize(horizontal: false, vertical: true).padding(14)
                }
                .background(cs == .dark ? Color(red: 0.14, green: 0.12, blue: 0.05) : Color(red: 1.0, green: 0.98, blue: 0.92))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(cs == .dark ? 0.45 : 0.55), lineWidth: 1.5))
    }

    @ViewBuilder private func examOptions(question: AudioQuestion) -> some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { idx, option in
                let isCorrect = option == question.answer

                Button { } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(option)
                            .font(.custom("Hiragino Sans", size: 15, relativeTo: .body))
                            .foregroundColor(isCorrect ? Color.green : cs == .dark ? .white.opacity(0.88) : Color(red: 0.08, green: 0.06, blue: 0.12))
                            .multilineTextAlignment(.center).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .center).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(isCorrect ? Color.green.opacity(0.06) : Color.clear)
                    .contentShape(Rectangle())
                    .overlay(alignment: .trailing) {
                        if isCorrect { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.green).padding(.trailing, 12) }
                    }
                }
                .disabled(true).buttonStyle(.plain)

                if idx < question.options.count - 1 {
                    Rectangle().fill(Color.noteBorder(cs).opacity(0.22)).frame(height: 1).padding(.horizontal, 12)
                }
            }
        }
        .background(Color.noteCard(cs)).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.noteBorder(cs), lineWidth: 1.5))
    }
}
