import SwiftUI
import WebKit

// KanjiVG stroke paths are bundled in Resources/StrokeOrder/strokes.json.
// Data: © KanjiVG contributors, CC BY-SA 3.0 (see Resources/StrokeOrder/COPYING).
private struct StrokeGlyph: Decodable {
    let paths: [String]
    let numbers: [[Double]]
}

private enum StrokeOrderData {
    static let glyphs: [String: StrokeGlyph] = {
        let url = Bundle.main.url(forResource: "strokes", withExtension: "json", subdirectory: "StrokeOrder")
            ?? Bundle.main.url(forResource: "strokes", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              let glyphs = try? JSONDecoder().decode([String: StrokeGlyph].self, from: data) else {
            return [:]
        }
        return glyphs
    }()
}

struct StrokeOrderGuideView: UIViewRepresentable {
    let word: String
    let columns: Int

    final class Coordinator {
        var displayedKey = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.scrollView.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let key = "\(word)|\(columns)"
        guard context.coordinator.displayedKey != key else { return }
        context.coordinator.displayedKey = key
        view.loadHTMLString(Self.html(word: word, columns: columns), baseURL: nil)
    }

    private static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func html(word: String, columns: Int) -> String {
        let cards = Array(word).enumerated().map { index, character -> String in
            let letter = String(character)
            guard let glyph = StrokeOrderData.glyphs[letter] else {
                return "<div class='card missing'><div class='order'>\(index + 1)</div><div class='fallback'>\(escaped(letter))</div><div class='letter'>\(escaped(letter))</div></div>"
            }
            let paths = glyph.paths.enumerated().map { strokeIndex, path in
                let number = strokeIndex + 1
                let marker: String
                if strokeIndex < glyph.numbers.count, glyph.numbers[strokeIndex].count == 2 {
                    let point = glyph.numbers[strokeIndex]
                    marker = "<text class='number' x='\(point[0])' y='\(point[1])'>\(number)</text>"
                } else {
                    marker = ""
                }
                return "<path class='ghost' d='\(escaped(path))'/><path class='stroke' d='\(escaped(path))'/>\(marker)"
            }.joined()
            return "<div class='card'><div class='order'>\(index + 1)</div><svg viewBox='0 0 109 109' aria-label='\(escaped(letter)) 획순'>\(paths)</svg><div class='letter'>\(escaped(letter))</div></div>"
        }.joined()

        return """
        <!doctype html><html lang="ja"><head><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"><style>
        *{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;background:#000;color:#fff;font-family:-apple-system,sans-serif}
        body{display:flex;align-items:center;justify-content:center;overflow:hidden}
        #word{display:grid;grid-template-columns:repeat(\(columns),minmax(0,1fr));gap:10px;width:100%;height:100%;align-content:center;justify-content:center}
        .card{position:relative;min-width:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
        svg{width:100%;max-width:220px;max-height:calc(100% - 28px);aspect-ratio:1;overflow:visible}
        path{fill:none;stroke-width:4;stroke-linecap:round;stroke-linejoin:round}
        .ghost{stroke:#777;opacity:.6}.stroke{stroke:#fff;opacity:0}
        .number{fill:#bbb;font-size:9px;font-weight:700;paint-order:stroke;stroke:#000;stroke-width:2.5px}
        .number.active{fill:#62b7ff}.order{position:absolute;top:2px;left:4px;font-size:16px;color:#62b7ff;font-weight:800}
        .letter{font-size:18px;font-weight:600;color:#ddd;text-align:center;line-height:24px}
        .fallback{display:flex;align-items:center;justify-content:center;min-height:70px;font-size:64px;font-weight:600;color:#fff}
        </style></head><body><div id="word">\(cards)</div><script>
        async function play(){
          const strokes=[...document.querySelectorAll('.stroke')];
          for(const path of strokes){const length=path.getTotalLength();path.style.strokeDasharray=length;path.style.strokeDashoffset=length;}
          for(const path of strokes){
            const number=path.nextElementSibling;
            path.style.opacity='1';path.style.stroke='#62b7ff';
            if(number&&number.classList.contains('number'))number.classList.add('active');
            const length=path.getTotalLength();
            const animation=path.animate([{strokeDashoffset:length},{strokeDashoffset:0}],{duration:Math.max(350,Math.min(850,length*8)),easing:'ease-in-out',fill:'forwards'});
            await animation.finished;
            path.style.strokeDashoffset='0';path.style.stroke='#fff';
            if(number&&number.classList.contains('number'))number.classList.remove('active');
            await new Promise(resolve=>setTimeout(resolve,120));
          }
        }
        play();
        </script></body></html>
        """
    }
}
