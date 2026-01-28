import SwiftUI

struct FullscreenScriptView: View {
    let script: String
    let highlightedRange: NSRange
    let dismissAction: () -> Void
    let fontScale: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // 배경색 설정
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 상단 닫기 버튼
                HStack {
                    Spacer()
                    Button(action: dismissAction) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    .padding()
                }
                .background(colorScheme == .dark ? Color.black : Color.white)
                
                // 스크립트 내용
                GeometryReader { geometry in
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack {
                                Spacer()
                                
                                Text(script)
                                    .font(.system(size: 24 * fontScale))
                                    .lineSpacing(12 * fontScale)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .onChange(of: highlightedRange) { _, newRange in
                                        if newRange.length > 0 {
                                            let startIndex = script.index(script.startIndex, offsetBy: newRange.location)
                                            let endIndex = script.index(startIndex, offsetBy: newRange.length)
                                            let highlightedText = String(script[startIndex..<endIndex])
                                            
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                proxy.scrollTo(highlightedText, anchor: .center)
                                            }
                                        }
                                    }
                                
                                Spacer()
                            }
                            .frame(minHeight: geometry.size.height)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
