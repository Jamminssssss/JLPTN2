import SwiftUI
import AVFoundation
import UIKit

struct ListeningView: View {
    @Binding var isTabBarHidden: Bool
    
    @State private var audioQuestions: [AudioQuestion] = []
    @State private var currentGroupIndex = 0
    @State private var groupAnswers: [UUID: String] = [:] // question.id -> selected option
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var score: Int = 0
    @State private var audioProgress: Float = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var updateTimer: Timer?
    @State private var endTimeTimer: Timer?
    @State private var showFullscreenImage = false
    @State private var fullscreenImageName: String? = nil
    @State private var showNextQuestion = false
    @State private var showMenu = false
    @State private var _delegate: AudioPlayerDelegate?
    @State private var fontScale: CGFloat = 1.2
    @State private var showResultSheet = false
    @State private var showScript = false
    @State private var hasScript: Bool = false
    @State private var currentScriptText: String = ""
    @State private var showPurchaseView: Bool = false      // 구독 시트
    @State private var selectedSet: Int? = nil
    @State private var wrongGroupIndices: [Int] = []
    @State private var isRetryMode = false

    @State private var set1Progress: Double = 0
    @State private var set2Progress: Double = 0


    /// 현재 문제가 잠겨 있는지 여부
    private var isCurrentQuestionLocked: Bool {
        guard let set = selectedSet else { return false }
        if storeManager.isPremium { return false }
        return set != 1
    }

    // 스크립트 권한: 구독 중이거나 1회차 무료 구간인 경우
    private var isScriptEntitled: Bool {
        // 구독자는 항상 스크립트 이용 가능
        if storeManager.isPremium { return true }
        // 비구독자는 1회차의 앞쪽(그룹 기준)만 스크립트 허용
        if let set = selectedSet, set == 1, currentGroupIndex <= 2 {
            return true
        }
        return false
    }

    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @ObservedObject private var appAdManager = AppAdManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private let level: String = "TopikAudio"
    private var quizGroup: String { "Group3_set\(selectedSet ?? 0)" }
    
    private var bannerHeight: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .compact      { return 90  }
        else if horizontalSizeClass == .regular                                   { return 100 }
        else if horizontalSizeClass == .compact && verticalSizeClass == .compact  { return 32  }
        else                                                                       { return 50  }
    }
    
    // MARK: - 묶음(그룹) 문제
    /// 같은 audioFileName + 같은 startTime/endTime을 공유하는 문제들을 하나의 그룹으로 묶음
    private var questionGroups: [[AudioQuestion]] {
        guard !audioQuestions.isEmpty else { return [] }
        var groups: [[AudioQuestion]] = []
        var current: [AudioQuestion] = []

        for question in audioQuestions {
            if current.isEmpty {
                current.append(question)
                continue
            }

            let ref = current[0]
            let sameAudio = ref.audioFileName == question.audioFileName
            let sameSegment: Bool

            if let rs = ref.startTime, let re = ref.endTime,
               let qs = question.startTime, let qe = question.endTime {
                sameSegment = (rs == qs && re == qe)
            } else if ref.startTime == nil && ref.endTime == nil &&
                        question.startTime == nil && question.endTime == nil {
                sameSegment = sameAudio
            } else {
                sameSegment = false
            }

            if sameAudio && sameSegment {
                current.append(question)
            } else {
                groups.append(current)
                current = [question]
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    /// retry 모드 고려한 실제 그룹 인덱스
    private var currentGroupActualIndex: Int {
        if isRetryMode && !wrongGroupIndices.isEmpty {
            return wrongGroupIndices[currentGroupIndex]
        }
        return currentGroupIndex
    }

    /// 현재 화면에 표시할 질문 배열
    private var currentGroup: [AudioQuestion]? {
        let groups = questionGroups
        let idx = currentGroupActualIndex
        guard idx >= 0, idx < groups.count else { return nil }
        return groups[idx]
    }

    /// 오디오/스크립트 세팅용 대표 질문 (그룹의 첫 번째)
    private var currentQuestion: AudioQuestion? {
        currentGroup?.first
    }

    /// 현재 그룹의 모든 문제가 답변됐는지
    private var allGroupAnswered: Bool {
        guard let group = currentGroup, !group.isEmpty else { return false }
        return group.allSatisfy { groupAnswers[$0.id] != nil }
    }

    private var totalGroupsCount: Int {
        isRetryMode ? wrongGroupIndices.count : questionGroups.count
    }

    /// 결과 화면용 전체 개별 문제 수
    private var totalQuestionsCountForResult: Int {
        if isRetryMode {
            let groups = questionGroups
            return wrongGroupIndices.compactMap { idx -> [AudioQuestion]? in
                guard idx >= 0, idx < groups.count else { return nil }
                return groups[idx]
            }.flatMap { $0 }.count
        }
        return audioQuestions.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    AdaptiveTopBannerView()

                    ZStack {
                        if selectedSet != nil {
                            (colorScheme == .dark ? Color.black : Color.white)
                                .ignoresSafeArea()
                            
                            GeometryReader { contentGeometry in
                                let availableHeight = contentGeometry.size.height
                                
                                ScrollView {
                                    VStack(spacing: 20) {
                                        // 메뉴
                                        HStack {
                                            Menu {
                                                Button(action: { resetToFirstQuestion() }) {
                                                    Label("다시 시작", systemImage: "arrow.counterclockwise")
                                                }
                                                Button(action: {
                                                    stopAudio()
                                                    if let set = selectedSet, !isRetryMode {
                                                        DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: currentGroupIndex)
                                                    }
                                                    selectedSet = nil
                                                    currentGroupIndex = 0
                                                    groupAnswers = [:]
                                                    progress = 0
                                                    wrongGroupIndices = []
                                                    isRetryMode = false
                                                }) {
                                                    Label("세트 선택", systemImage: "list.number")
                                                }
                                                Button(action: { dismiss() }) {
                                                    Label("메인으로 돌아가기", systemImage: "house.fill")
                                                }
                                                Menu("글자 크기") {
                                                    Button(action: { fontScale = 1.0 }) { Text("작게") }
                                                    Button(action: { fontScale = 1.2 }) { Text("보통") }
                                                    Button(action: { fontScale = 1.4 }) { Text("크게") }
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(colorScheme == .dark ? .orange : .blue)
                                            }
                                            Spacer()
                                            
                                            // 진행 표시 (그룹 기준)
                                            Text("\(currentGroupIndex + 1) / \(max(totalGroupsCount, 1))")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal)

                                        Spacer(minLength: 0)

                                        if let group = currentGroup {
                                            // 공통: 재생/재시작 버튼
                                            let playControls = HStack(spacing: 20) {
                                                Button(action: { togglePlayPause() }) {
                                                    HStack {
                                                        Spacer()
                                                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                            .font(.system(size: 30))
                                                            .foregroundColor(.blue)
                                                        Spacer()
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.darkGray, lineWidth: 1)
                                                    )
                                                }
                                                Button(action: { restartCurrentAudio() }) {
                                                    HStack {
                                                        Spacer()
                                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                                            .font(.system(size: 30))
                                                            .foregroundColor(.blue)
                                                        Spacer()
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.darkGray, lineWidth: 1)
                                                    )
                                                }
                                            }
                                            .padding(.horizontal, 20)

                                            if group.count == 1, let question = group.first {
                                                // ✅ 단일 문제 UI/UX 유지 (문제 → 재생/재시작 → 스크립트 → 보기)
                                                let isAnswered = groupAnswers[question.id] != nil

                                                VStack(spacing: 16) {
                                                    VStack(alignment: .center, spacing: 16) {
                                                        Text(question.question)
                                                            .font(.custom("Hiragino Sans", size: 22 * fontScale, relativeTo: .body))
                                                            .multilineTextAlignment(.center)
                                                            .padding(.horizontal, 20)
                                                            .frame(maxWidth: .infinity)
                                                            .fixedSize(horizontal: false, vertical: true)

                                                        if let imageName = question.imageName,
                                                           let image = UIImage(named: imageName) {
                                                            Image(uiImage: image)
                                                                .resizable()
                                                                .scaledToFit()
                                                                .frame(maxWidth: geometry.size.width * 0.8)
                                                                .onTapGesture {
                                                                    fullscreenImageName = imageName
                                                                    showFullscreenImage = true
                                                                }
                                                        }
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 20)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                                    )
                                                    .padding(.horizontal, 20)

                                                    playControls

                                                    // 스크립트는 단일 문제에서도 "해당 문제" 기준으로만 노출
                                                    if isAnswered && hasScript {
                                                        scriptButton.padding(.horizontal, 20)
                                                    }

                                                    VStack(spacing: 16) {
                                                        ForEach(question.options, id: \.self) { option in
                                                            Button(action: { selectAnswer(option, for: question) }) {
                                                                HStack {
                                                                    Spacer()
                                                                    Text(option)
                                                                        .font(.custom("Hiragino Sans", size: 18 * fontScale, relativeTo: .body))
                                                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                                                        .multilineTextAlignment(.center)
                                                                        .padding(.vertical, 12)
                                                                        .fixedSize(horizontal: false, vertical: true)
                                                                    Spacer()
                                                                    if isAnswered {
                                                                        if option == question.answer {
                                                                            Image(systemName: "checkmark.circle.fill")
                                                                                .foregroundColor(.green)
                                                                                .padding(.trailing, 8)
                                                                        } else if option == groupAnswers[question.id] {
                                                                            Image(systemName: "xmark.circle.fill")
                                                                                .foregroundColor(.red)
                                                                                .padding(.trailing, 8)
                                                                        }
                                                                    }
                                                                }
                                                                .frame(maxWidth: .infinity)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 12)
                                                                        .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                                )
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 12)
                                                                        .stroke(Color.darkGray, lineWidth: 1)
                                                                )
                                                            }
                                                            .disabled(isAnswered)
                                                        }
                                                    }
                                                    .padding(.horizontal, 20)
                                                }
                                            } else {
                                                // ✅ 묶음 문제 UI: 상단 재생/재시작 → 스크립트(모든 문항 완료 후) → 각 문항(문제+보기)
                                                playControls

                                                // 모든 문항을 완료하면 재생 버튼 바로 아래에 스크립트 해금
                                                if allGroupAnswered, hasScript {
                                                    scriptButton.padding(.horizontal, 20)
                                                }

                                                VStack(spacing: 20) {
                                                    ForEach(Array(group.enumerated()), id: \.element.id) { idx, question in
                                                        let isAnswered = groupAnswers[question.id] != nil

                                                        VStack(spacing: 16) {
                                                            // 문제 박스
                                                            VStack(alignment: .center, spacing: 16) {
                                                                Text(question.question)
                                                                    .font(.custom("Hiragino Sans", size: 22 * fontScale, relativeTo: .body))
                                                                    .multilineTextAlignment(.center)
                                                                    .padding(.horizontal, 20)
                                                                    .frame(maxWidth: .infinity)
                                                                    .fixedSize(horizontal: false, vertical: true)

                                                                if let imageName = question.imageName,
                                                                   let image = UIImage(named: imageName) {
                                                                    Image(uiImage: image)
                                                                        .resizable()
                                                                        .scaledToFit()
                                                                        .frame(maxWidth: geometry.size.width * 0.8)
                                                                        .onTapGesture {
                                                                            fullscreenImageName = imageName
                                                                            showFullscreenImage = true
                                                                        }
                                                                }
                                                            }
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 20)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 16)
                                                                    .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                                            )

                                                            // 보기(선택지)
                                                            VStack(spacing: 12) {
                                                                ForEach(question.options, id: \.self) { option in
                                                                    Button(action: { selectAnswer(option, for: question) }) {
                                                                        HStack {
                                                                            Spacer()
                                                                            Text(option)
                                                                                .font(.custom("Hiragino Sans", size: 18 * fontScale, relativeTo: .body))
                                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                                                .multilineTextAlignment(.center)
                                                                                .padding(.vertical, 12)
                                                                                .fixedSize(horizontal: false, vertical: true)
                                                                            Spacer()
                                                                            if isAnswered {
                                                                                if option == question.answer {
                                                                                    Image(systemName: "checkmark.circle.fill")
                                                                                        .foregroundColor(.green)
                                                                                        .padding(.trailing, 8)
                                                                                } else if option == groupAnswers[question.id] {
                                                                                    Image(systemName: "xmark.circle.fill")
                                                                                        .foregroundColor(.red)
                                                                                        .padding(.trailing, 8)
                                                                                }
                                                                            }
                                                                        }
                                                                        .frame(maxWidth: .infinity)
                                                                        .background(
                                                                            RoundedRectangle(cornerRadius: 12)
                                                                                .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                                        )
                                                                        .overlay(
                                                                            RoundedRectangle(cornerRadius: 12)
                                                                                .stroke(Color.darkGray, lineWidth: 1)
                                                                        )
                                                                    }
                                                                    .disabled(isAnswered)
                                                                }
                                                            }

                                                        }
                                                        .padding(.horizontal, 20)

                                                        if idx < group.count - 1 {
                                                            Divider()
                                                                .padding(.horizontal, 20)
                                                                .padding(.vertical, 4)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // 다음 버튼 (그룹 내 모두 답변 후)
                                        if allGroupAnswered {
                                            Button(action: { moveToNextGroup() }) {
                                                HStack {
                                                    Spacer()
                                                    Text(currentGroupIndex < totalGroupsCount - 1 ? "다음 문제" : "완료")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        .multilineTextAlignment(.center)
                                                        .padding(.vertical, 12)
                                                    Spacer()
                                                }
                                                .frame(maxWidth: .infinity)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.darkGray, lineWidth: 1)
                                                )
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: availableHeight).padding(.vertical)
                                }
                            }
                        } else {
                            // 세트 선택 화면
                            (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()
                            GeometryReader { geo in
                                VStack(spacing: 0) {
                                    HStack {
                                        Button(action: { dismiss() }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(colorScheme == .dark ? .white : .black).padding()
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            // ── 1회 세트 (5문제 무료) ────────────────────────
                                            VStack(spacing: 0) {
                                                Spacer()
                                                Button(action: {
                                                    selectedSet = 1
                                                    loadQuestionsForSet(1)
                                                }) {
                                                    VStack(spacing: 16) {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill(Color.green.opacity(0.15))
                                                                .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                            VStack(spacing: 4) {
                                                                Image(systemName: "headphones")
                                                                    .font(.system(size: min(geo.size.width * 0.13, 70)))
                                                                    .foregroundColor(.green)
                                                            }
                                                        }
                                                        Text("1회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set1Progress)
                                                                .progressViewStyle(.linear).tint(.green)
                                                                .frame(width: min(geo.size.width * 0.5, 260))
                                                            Text(String(format: "%.0f%%", set1Progress * 100))
                                                                .font(.system(size: 14, weight: .semibold))
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        }
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .frame(height: max(geo.size.height * 0.45, 300))

                                            Divider()
                                                .background(colorScheme == .dark ? Color.gray : Color.gray.opacity(0.3))

                                            // ── 2~3회 세트 (구독 필요) ───────────────────────
                                            ForEach([
                                                (2, set2Progress)
                                            ], id: \.0) { setNumber, setProgress in
                                                let isUnlocked = storeManager.isPremium
                                                VStack(spacing: 0) {
                                                    Spacer()
                                                    Button(action: {
                                                        if isUnlocked {
                                                            selectedSet = setNumber
                                                            loadQuestionsForSet(setNumber)
                                                        } else {
                                                            showPurchaseView = true
                                                        }
                                                    }) {
                                                        VStack(spacing: 16) {
                                                            ZStack {
                                                                RoundedRectangle(cornerRadius: 20)
                                                                    .fill((isUnlocked ? Color.green : Color.orange).opacity(0.15))
                                                                    .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                                if isUnlocked {
                                                                    Image(systemName: "headphones")
                                                                        .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                        .foregroundColor(.green)
                                                                } else {
                                                                    VStack(spacing: 8) {
                                                                        Image(systemName: "crown.fill")
                                                                            .font(.system(size: min(geo.size.width * 0.10, 50)))
                                                                            .foregroundColor(.orange)
                                                                        Text("구독 필요")
                                                                            .font(.system(size: 12, weight: .bold))
                                                                            .foregroundColor(.orange)
                                                                            .padding(.horizontal, 8)
                                                                            .padding(.vertical, 3)
                                                                            .background(Color.orange.opacity(0.15))
                                                                            .cornerRadius(6)
                                                                    }
                                                                }
                                                            }
                                                            Text("\(setNumber)회")
                                                                .font(.system(size: 24, weight: .bold))
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            VStack(spacing: 6) {
                                                                ProgressView(value: setProgress)
                                                                    .progressViewStyle(.linear)
                                                                    .tint(isUnlocked ? .green : .orange)
                                                                    .frame(width: min(geo.size.width * 0.5, 260))
                                                                Text(String(format: "%.0f%%", setProgress * 100))
                                                                    .font(.system(size: 14, weight: .semibold))
                                                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            }
                                                        }
                                                    }
                                                    Spacer()
                                                }
                                                .frame(height: max(geo.size.height * 0.45, 300))

                                                Divider()
                                                    .background(colorScheme == .dark ? Color.gray : Color.gray.opacity(0.3))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    AdaptiveBottomBannerView()
                }
            }
        }
        .ignoresSafeArea(.container, edges: [.leading, .trailing])
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showFullscreenImage) {
            if let imageName = fullscreenImageName,
               let image = UIImage(named: imageName) {
                FullscreenImageView(image: image) { showFullscreenImage = false }
            }
        }
        // 구독 시트
        .fullScreenCover(isPresented: $showPurchaseView){
            PurchaseView()
        }
        .fullScreenCover(isPresented: $showResultSheet)  {
            let totalQ = totalQuestionsCountForResult
            let correctCount = score
            let wrongCount   = totalQ - score
            let accuracy     = totalQ > 0 ? Int(Double(score) / Double(totalQ) * 100) : 0
            VStack(spacing: 24) {
                Text("퀴즈 결과").font(.largeTitle).fontWeight(.bold)
                Text("✔️ 정답수: \(correctCount)").font(.title2).foregroundColor(.green)
                Text("❌ 오답수: \(wrongCount)").font(.title2).foregroundColor(.red)
                Text("📊 정답률: \(accuracy)%").font(.title2).foregroundColor(.blue)
                
                Button(action: {
                    if let set = selectedSet {
                        DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group3_set\(set)")
                        DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: 0)
                        currentGroupIndex = 0
                        groupAnswers = [:]
                        progress = 0; score = 0; audioProgress = 0; isPlaying = false
                        showScript = false; wrongGroupIndices = []; isRetryMode = false
                        selectedSet = nil; audioQuestions = []
                    }
                    stopAudio(); showResultSheet = false; dismiss()
                }) {
                    Text("확인").font(.title3).padding().frame(maxWidth: .infinity)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }
                
                if !isRetryMode && !wrongGroupIndices.isEmpty {
                    Button(action: {
                        stopAudio(); audioPlayer = nil
                        currentGroupIndex = 0
                        groupAnswers = [:]
                        score = 0; audioProgress = 0; isPlaying = false; showScript = false
                        isRetryMode = true; progress = 0
                        showResultSheet = false
                        setupAudio()
                    }) {
                        Text("틀린 문제만 다시 풀기").font(.title3).padding().frame(maxWidth: .infinity)
                            .background(Color.orange).foregroundColor(.white).cornerRadius(10)
                    }
                }
            }
            .padding(32).frame(maxWidth: 400)
        }
        .onAppear {
            isTabBarHidden = true
            configureAudioSession()
            if let set = selectedSet, !isRetryMode {
                let saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group3_set\(set)")
                currentGroupIndex = (saved < questionGroups.count) ? saved : 0
                progress = Double(currentGroupIndex) / Double(max(questionGroups.count, 1))
            } else {
                currentGroupIndex = 0; progress = 0
            }
            refreshSetProgress()
        }
        .onDisappear {
            isTabBarHidden = false
            if let set = selectedSet, !isRetryMode {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: currentGroupIndex)
            }
            stopAudio()
            refreshSetProgress()
        }
        .onChange(of: currentGroupIndex) { _, newValue in
            if let set = selectedSet, !isRetryMode {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: newValue)
            }
            progress = Double(newValue) / Double(max(totalGroupsCount, 1))
            refreshSetProgress()
        }
    }

    // MARK: - 스크립트 버튼 + 패널
    @ViewBuilder
    private var scriptButton: some View {
        VStack(spacing: 0) {
            Button(action: {
                if isScriptEntitled {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showScript.toggle() }
                } else {
                    showPurchaseView = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isScriptEntitled ? "text.bubble.fill" : "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isScriptEntitled ? .green : .orange)
                    Text(LocalizedStringKey("script.button_title"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if isScriptEntitled {
                        Image(systemName: showScript ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                    } else {
                        Text(LocalizedStringKey("explanation.subscribe_hint"))
                            .font(.system(size: 12, weight: .medium)).foregroundColor(.orange)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13).frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: showScript && isScriptEntitled ? 0 : 12, style: .continuous)
                        .fill(colorScheme == .dark
                              ? Color(red: 0.10, green: 0.15, blue: 0.12)
                              : Color(red: 0.93, green: 1.0, blue: 0.95))
                )
                .clipShape(
                    .rect(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: showScript && isScriptEntitled ? 0 : 12,
                        bottomTrailingRadius: showScript && isScriptEntitled ? 0 : 12,
                        topTrailingRadius: 12
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isScriptEntitled ? Color.green.opacity(0.4) : Color.orange.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if showScript && isScriptEntitled {
                VStack(alignment: .leading, spacing: 10) {
                    if !currentScriptText.isEmpty {
                        Text(currentScriptText)
                            .font(.custom("Hiragino Sans", size: 15 * fontScale, relativeTo: .body))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.85))
                            .lineSpacing(5).multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle").foregroundColor(.secondary).font(.system(size: 14))
                            Text(LocalizedStringKey("script.not_available")).font(.system(size: 14)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark
                             ? Color(red: 0.08, green: 0.13, blue: 0.10)
                             : Color(red: 0.94, green: 1.0, blue: 0.96))
                .clipShape(.rect(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.25), lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Private Functions
    private func selectAnswer(_ answer: String, for question: AudioQuestion) {
        guard groupAnswers[question.id] == nil else { return }

        groupAnswers[question.id] = answer

        if answer == question.answer {
            score += 1
        } else if !isRetryMode {
            if !wrongGroupIndices.contains(currentGroupIndex) {
                wrongGroupIndices.append(currentGroupIndex)
            }
        }

        if !isScriptEntitled { showScript = false }
    }
    
    private func moveToNextGroup() {
        if currentGroupIndex < totalGroupsCount - 1 {
            let nextIndex = currentGroupIndex + 1

            // Gating: Non-subscribers can solve only the first few groups in Set 1
            if !storeManager.isPremium {
                let nextGroupActual = isRetryMode ? wrongGroupIndices[nextIndex] : nextIndex
                let isFreeGroup = (selectedSet == 1 && nextGroupActual <= 2)
                if !isFreeGroup {
                    showPurchaseView = true
                    return
                }
            }

            stopAudio()
            audioPlayer = nil

            currentGroupIndex = nextIndex
            groupAnswers = [:]
            audioProgress = 0
            isPlaying = false
            showScript = false

            setupAudio()
            refreshSetProgress()
        } else {
            showResultSheet = true
        }
    }
    
    private func resetToFirstQuestion() {
        stopAudio(); audioPlayer = nil
        currentGroupIndex = 0; progress = 0; score = 0
        groupAnswers = [:]; audioProgress = 0
        isPlaying = false; showScript = false; wrongGroupIndices = []; isRetryMode = false
        setupAudio()
        DatabaseManager.shared.resetProgress(level: level, quizGroup: quizGroup)
        if let set = selectedSet {
            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: 0)
        }
    }
    
    private func resetAndDismiss() {
        if let set = selectedSet {
            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group3_set\(set)")
        }
        currentGroupIndex = 0
        groupAnswers = [:]
        progress = 0; score = 0; audioProgress = 0; isPlaying = false
        showScript = false; selectedSet = nil; audioQuestions = []
        wrongGroupIndices = []; isRetryMode = false; isTabBarHidden = false
        stopAudio(); dismiss()
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch { print("오디오 세션 설정 실패: \(error.localizedDescription)") }
    }
    
    private func restartCurrentAudio() {
        guard let player = audioPlayer, let question = currentQuestion else { return }
        if let start = question.startTime, let end = question.endTime, end > start {
            player.currentTime = start; setupEndTimeTimer()
        } else {
            player.currentTime = 0; endTimeTimer?.invalidate()
        }
        player.play(); isPlaying = true
    }

    private func loadQuestions() {
        audioQuestions = AudioDataLoader.load(set: 1)
        currentGroupIndex = DatabaseManager.shared.loadProgress(level: level, quizGroup: quizGroup)
        if currentGroupIndex >= questionGroups.count { currentGroupIndex = 0 }
        progress = questionGroups.isEmpty ? 0 : Double(currentGroupIndex) / Double(questionGroups.count)
    }

    private func loadQuestionsForSet(_ set: Int) {
        audioQuestions = AudioDataLoader.load(set: set)
        let savedIndex = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group3_set\(set)")
        let groupCount = questionGroups.count
        currentGroupIndex = (savedIndex < groupCount) ? savedIndex : 0
        progress = groupCount == 0 ? 0 : Double(currentGroupIndex) / Double(groupCount)
        groupAnswers = [:]; audioProgress = 0
        isPlaying = false; wrongGroupIndices = []; isRetryMode = false
        stopAudio(); setupAudio()
    }

    private func refreshSetProgress() {
        func prog(set: Int, group: String) -> Double {
            let qs = AudioDataLoader.load(set: set)
            let s  = DatabaseManager.shared.loadProgress(level: level, quizGroup: group)
            // progress should be computed on grouped questions count
            let groupedCount: Int = {
                guard !qs.isEmpty else { return 0 }
                var groups: [[AudioQuestion]] = []
                var current: [AudioQuestion] = []
                for q in qs {
                    if current.isEmpty { current.append(q); continue }
                    let ref = current[0]
                    let sameAudio = ref.audioFileName == q.audioFileName
                    let sameSegment: Bool
                    if let rs = ref.startTime, let re = ref.endTime,
                       let qs = q.startTime, let qe = q.endTime {
                        sameSegment = (rs == qs && re == qe)
                    } else if ref.startTime == nil && ref.endTime == nil &&
                                q.startTime == nil && q.endTime == nil {
                        sameSegment = sameAudio
                    } else {
                        sameSegment = false
                    }
                    if sameAudio && sameSegment { current.append(q) }
                    else { groups.append(current); current = [q] }
                }
                if !current.isEmpty { groups.append(current) }
                return groups.count
            }()
            return groupedCount == 0 ? 0 : Double(min(s, max(groupedCount - 1, 0))) / Double(groupedCount)
        }
        set1Progress = prog(set: 1, group: "Group3_set1")
        set2Progress = prog(set: 2, group: "Group3_set2")
    }

    private func setupAudio() {
        guard let question = currentQuestion else { return }
        let localizedFromCSV = question.localizedScript()
        let script: String?
        if let csvScript = localizedFromCSV, !csvScript.isEmpty { script = csvScript }
        else { script = ScriptData.getScript(for: question.audioFileName) }
        currentScriptText = script ?? ""; hasScript = (script != nil)
        
        guard let url = Bundle.main.url(forResource: question.audioFileName, withExtension: nil) else {
            print("오디오 파일을 찾을 수 없습니다: \(question.audioFileName)"); return
        }
        do {
            configureAudioSession()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            if let start = question.startTime, let end = question.endTime, end > start {
                audioPlayer?.currentTime = start; setupEndTimeTimer()
            } else {
                audioPlayer?.currentTime = 0; endTimeTimer?.invalidate()
            }
            let delegate = AudioPlayerDelegate(isPlaying: $isPlaying)
            _delegate = delegate; audioPlayer?.delegate = delegate
            startProgressUpdateTimer(); setupEndTimeTimer()
        } catch { print("오디오 플레이어 초기화 실패: \(error.localizedDescription)") }
    }
    
    private func setupEndTimeTimer() {
        endTimeTimer?.invalidate(); endTimeTimer = nil
        guard let question = currentQuestion, let player = audioPlayer,
              let startTime = question.startTime, let endTime = question.endTime,
              endTime > startTime else { return }
        if player.currentTime < startTime { player.currentTime = startTime }
        let remainingTime = endTime - player.currentTime
        if remainingTime > 0 {
            endTimeTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { _ in
                self.stopAudioAtEndTime()
            }
        }
    }
    
    private func stopAudioAtEndTime() {
        audioPlayer?.pause(); isPlaying = false
        if let startTime = currentQuestion?.startTime { audioPlayer?.currentTime = startTime }
    }
    
    private func startProgressUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.audioPlayer, let question = self.currentQuestion else { return }
            if let startTime = question.startTime, let endTime = question.endTime, endTime > startTime {
                let duration = endTime - startTime
                let currentOffset = player.currentTime - startTime
                self.audioProgress = duration > 0 ? Float(max(0, min(currentOffset / duration, 1.0))) : 0
                if player.currentTime >= endTime { self.stopAudioAtEndTime() }
            } else {
                self.audioProgress = player.duration > 0 ? Float(player.currentTime / player.duration) : 0
                if !player.isPlaying && player.currentTime >= player.duration {
                    self.isPlaying = false; self.updateTimer?.invalidate()
                }
            }
            self.isPlaying = player.isPlaying
        }
    }

    private func togglePlayPause() {
        guard let player = audioPlayer, let question = currentQuestion else { return }
        if player.isPlaying {
            player.pause(); isPlaying = false; endTimeTimer?.invalidate()
        } else {
            if let startTime = question.startTime, let endTime = question.endTime {
                if player.currentTime < startTime || player.currentTime >= endTime {
                    player.currentTime = startTime
                }
            } else if player.currentTime >= player.duration { player.currentTime = 0 }
            player.play(); isPlaying = true; startProgressUpdateTimer(); setupEndTimeTimer()
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        if let startTime = currentQuestion?.startTime { audioPlayer?.currentTime = startTime }
        else { audioPlayer?.currentTime = 0 }
        updateTimer?.invalidate(); updateTimer = nil
        endTimeTimer?.invalidate(); endTimeTimer = nil
        isPlaying = false
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    @Binding var isPlaying: Bool
    init(isPlaying: Binding<Bool>) { self._isPlaying = isPlaying }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.isPlaying = false }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { self.isPlaying = false }
        print("오디오 디코딩 에러: \(error?.localizedDescription ?? "알 수 없음")")
    }
}
