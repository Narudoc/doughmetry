import CoreGraphics
import Foundation

/// OCR 텍스트 조각 → 줄 단위 텍스트 재조립 (Vision에 의존하지 않는 순수 로직).
/// 웹은 tesseract.js의 레이아웃 분석을 쓰므로 TS 이식본이 없다.
public enum OCRLayout {
    /// OCR 조각 — box는 Vision 정규화 좌표 (좌하단 원점)
    public typealias Piece = (text: String, box: CGRect)

    /// 관측된 텍스트 조각을 표의 행 단위로 재조립 —
    /// y가 비슷한 조각을 한 줄로 묶고 왼쪽부터 정렬한다 ("재료 | 양" 표 대응).
    /// "재료 | 만드는 법"처럼 단이 나란하면 오른쪽 단은 왼쪽 단 뒤에 따로 이어 붙인다 —
    /// 한 줄로 합치면 재료가 옆 공정 문장과 섞여 서술문으로 걸러진다.
    public static func assembleRows(_ pieces: [Piece]) -> String {
        guard !pieces.isEmpty else { return "" }

        let avgHeight = pieces.map(\.box.height).reduce(0, +) / CGFloat(pieces.count)
        let threshold = max(avgHeight * 0.6, 0.008)

        var rows: [[Piece]] = []
        // Vision 좌표계는 좌하단 원점 — 위에서 아래로 정렬
        for piece in pieces.sorted(by: { $0.box.midY > $1.box.midY }) {
            if var last = rows.last, let refY = last.first?.box.midY,
                abs(refY - piece.box.midY) < threshold
            {
                last.append(piece)
                rows[rows.count - 1] = last
            } else {
                rows.append([piece])
            }
        }
        rows = rows.map { $0.sorted { $0.box.minX < $1.box.minX } }
        func line(_ row: some Sequence<Piece>) -> String {
            row.map(\.text).joined(separator: " ")
        }

        // 오른쪽 단 = 그램 수량까지 나온 뒤 멀리 떨어져 시작하는 공정 문장·수량 있는 재료.
        // 이름 칸에는 수량이 없으므로 "강력분 | 500" 표는, 비고 칸은 짧은 메모라서
        // "르방 | 150 | 뒤흐" 표는 여기서 갈라지지 않는다.
        let minGap = max(0.05, avgHeight * 2)
        let splitXs = rows.compactMap { row -> CGFloat? in
            row.indices.dropFirst().first { i in
                row[i].box.minX - row[i - 1].box.maxX > minGap
                    && !isBareAmount(row[i].text)
                    && startsColumn(row[i].text)
                    && hasGramAmount(line(row[..<i]))
            }
            .map { row[$0].box.minX }
        }
        guard let columnX = splitXs.min() else {
            return rows.map { line($0) }.joined(separator: "\n")
        }

        // 머리글("만드는 법")이나 공정만 있는 행도 그 x 이후면 오른쪽 단 —
        // 오른쪽 단이 머리글부터 시작해야 파서가 그 줄에서 멈춘다
        let cut = columnX - max(0.02, avgHeight)
        // "재료 | 양 | 비고" 표 — 수량 칸 뒤가 짧은 메모("T65"·"Stiff (50%)")인 행이 하나라도 있으면
        // 그 x는 비고 칸이다 ("Keep it cool." 같은 문장 메모 하나로 표 전체를 가르지 않는다)
        // 번호 매긴 공정·공정 머리글이 있는 오른쪽 단은 비고 칸이 아니다 —
        // 줄바꿈된 짧은 이어짐 줄("밀가루를 섞는다")을 비고로 오인해 단 분리를 통째로 포기하지 않게
        let isMethodColumn = rows.joined().contains { p in
            p.box.minX >= cut
                && (p.text.range(of: #"^\s*[0-9]{1,2}[.)]\s"#, options: .regularExpression) != nil
                    || RecipeTextParser.isMethodHeader(p.text))
        }
        let isNotesColumn = !isMethodColumn && rows.contains { row in
            guard let firstRight = row.first(where: { $0.box.minX >= cut }) else { return false }
            return !startsColumn(firstRight.text)
                && row.contains { $0.box.minX < cut && isBareAmount($0.text) && hasGramAmount($0.text) }
        }
        if isNotesColumn {
            return rows.map { line($0) }.joined(separator: "\n")
        }

        var left: [String] = []
        var right: [String] = []
        for row in rows {
            let l = row.filter { $0.box.minX < cut }
            let r = row.filter { $0.box.minX >= cut }
            if !l.isEmpty { left.append(line(l)) }
            if !r.isEmpty { right.append(line(r)) }
        }
        return (left + right).joined(separator: "\n")
    }

    /// 괄호 밖에 그램 수량이 있는지 — RecipeTextParser와 같이 "T65"처럼 영문자에 붙은 숫자,
    /// %·온도, 줄머리 번호("1. ")는 수량으로 보지 않는다
    static func hasGramAmount(_ text: String) -> Bool {
        let s = text
            .replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*[0-9]{1,2}[.)]\s"#, with: "", options: .regularExpression)
        return s.range(
            of: #"(?<![A-Za-z0-9.,])[0-9]+(?:[.,][0-9]+)?(?![0-9.,]*[ \t]*(?:%|°|℃|도))"#,
            options: .regularExpression) != nil
    }

    /// 수량만 있는 칸("500", "350 g", "(100%)") — 표의 수량·% 열이지 별도 단이 아니다
    static func isBareAmount(_ text: String) -> Bool {
        text.replacingOccurrences(
            of: #"[0-9][0-9.,]*[ \t]*(?:kg|g|㎏|그램|키로|킬로|ml|개|%)?"#, with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        .trimmingCharacters(in: CharacterSet(charactersIn: " \t()[]~-–—/|:.,"))
        .isEmpty
    }

    /// 옆 단의 첫 조각 — 공정 문장(줄머리 번호·서술 어미·긴 문장)이나 수량 있는 재료.
    /// "Stiff (50%)"·"인스턴트"·"T65" 같은 표의 비고 칸은 그 행에 남겨야 르방 수분율·이스트 종류를 읽는다
    static func startsColumn(_ text: String) -> Bool {
        hasGramAmount(text)
            || text.range(of: #"^\s*[0-9]{1,2}[.)]\s|(세요|니다|[.!])\s*$"#, options: .regularExpression) != nil
            || text.split(whereSeparator: \.isWhitespace).count >= 4
    }
}
