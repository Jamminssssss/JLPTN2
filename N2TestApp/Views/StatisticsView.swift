import SwiftUI

struct StatisticsView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var readingProgress: Double = 0.0
    @State private var listeningProgress: Double = 0.0
    @State private var grammarProgress: Double = 0.0
    @State private var wordProgress: Double = 0.0
    @State private var isCalculating: Bool = true
    
    private var overallProgress: Double { (readingProgress + listeningProgress + grammarProgress + wordProgress) / 4.0 }
    private var cardBackgroundColor: Color { colorScheme == .dark ? Color(white: 0.12) : .white }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Text("학습 통계").font(.system(size: 24, weight: .bold)).frame(maxWidth: .infinity, alignment: .center).padding(.top, 10)
                
                if isCalculating {
                    ProgressView("데이터 집계 중...").frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    donutChartCard
                    progressBarsCard
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .background(colorScheme == .dark ? Color(white: 0.05) : Color(white: 0.96))
        .onAppear { calculateStatistics() }
        .onReceive(NotificationCenter.default.publisher(for: .jlptCloudRestoreCompleted)) { _ in calculateStatistics() }
    }
    
    private var donutChartCard: some View {
        VStack(spacing: 16) {
            Text("종합 달성률").font(.system(size: 16, weight: .semibold)).foregroundColor(.secondary)
            ZStack {
                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 18)
                Circle().trim(from: 0, to: overallProgress).stroke(AngularGradient(gradient: Gradient(colors: [.blue, .purple, .blue]), center: .center, startAngle: .degrees(0), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: 18, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.easeOut(duration: 1.0), value: overallProgress)
                VStack(spacing: 4) {
                    Text("\(Int(overallProgress * 100))%").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundColor(colorScheme == .dark ? .white : .black)
                    Text("완료").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                }
            }.frame(width: 180, height: 180).padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24).background(cardBackgroundColor).cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var progressBarsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("영역별 학습 현황").font(.system(size: 18, weight: .bold)).padding(.bottom, 4)
            VStack(spacing: 24) {
                // 🌟 수정: 통계 4대 영역을 기존에 등록된 다국어 규격 키로 연결
                StatProgressRow(title: "menu.reading", progress: readingProgress, icon: "book.fill", color: .blue)
                StatProgressRow(title: "menu.listening", progress: listeningProgress, icon: "headphones", color: .green)
                StatProgressRow(title: "menu.grammar", progress: grammarProgress, icon: "graduationcap", color: .purple)
                StatProgressRow(title: "menu.wordlist", progress: wordProgress, icon: "pencil", color: .pink)
            }
        }.padding(20).background(cardBackgroundColor).cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func calculateStatistics() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Reading (1~5)
            var rTotal: Double = 0; var rCount: Double = 0
            for set in 1...5 {
                let q = DataLoader.load(set: set)
                if q.isEmpty { continue }
                let groups = DataLoader.groupQuestions(q)
                let saved = DatabaseManager.shared.loadProgress(level: "JLPTN5", quizGroup: "Group1_set\(set)")
                rTotal += Double(min(saved, max(groups.count - 1, 1))) / Double(max(groups.count - 1, 1))
                rCount += 1
            }
            let rRate = rCount > 0 ? rTotal / rCount : 0
            
            // Listening (1~5)
            var lTotal: Double = 0; var lCount: Double = 0
            for set in 1...5 {
                let aq = AudioDataLoader.load(set: set)
                if aq.isEmpty { continue }
                let saved = DatabaseManager.shared.loadProgress(level: "JLPTN5Audio", quizGroup: "Group2_set\(set)")
                lTotal += Double(min(saved, max(aq.count - 1, 1))) / Double(max(aq.count - 1, 1))
                lCount += 1
            }
            let lRate = lCount > 0 ? lTotal / lCount : 0
            
            // Grammar & Word
            let gProg = ProgressManager.shared.getLastGrammarProgress()
            let gRate = gProg != nil ? min(Double(gProg! + 1) / Double(max(VocabDataLoader.shared.grammarExamples.count, 1)), 1.0) : 0.0
            
            let wProg = ProgressManager.shared.getLastWordProgress()
            let wRate = wProg != nil ? min(Double(wProg! + 1) / Double(max(VocabDataLoader.shared.words.count, 1)), 1.0) : 0.0
            
            DispatchQueue.main.async {
                self.readingProgress = rRate; self.listeningProgress = lRate
                self.grammarProgress = gRate; self.wordProgress = wRate
                withAnimation(.easeOut(duration: 0.8)) { self.isCalculating = false }
            }
        }
    }
}

struct StatProgressRow: View {
    // 🌟 수정: title 파라미터 String -> LocalizedStringKey
    let title: LocalizedStringKey; let progress: Double; let icon: String; let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(max(1, Int(progress * 100)))%").font(.system(size: 15, weight: .bold)).foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule().fill(color).frame(width: max(0, geo.size.width * CGFloat(progress)))
                }
            }.frame(height: 8)
        }
    }
}
