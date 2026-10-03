import CoreGraphics
import Foundation

public struct TextPiece: Equatable {
    public let text: String
    public let box: CGRect

    public init(text: String, box: CGRect) {
        self.text = text
        self.box = box
    }
}

public enum TextAssembly {
    /// Reads Vision boxes (origin at the bottom-left, y upward) from top to bottom.
    /// Words that overlap vertically stay on one line, left to right.
    public static func assemble(_ pieces: [TextPiece], keepLineBreaks: Bool) -> String {
        let cleaned = pieces.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !cleaned.isEmpty else { return "" }

        let sorted = cleaned.sorted { lhs, rhs in
            if abs(lhs.box.midY - rhs.box.midY) > 0.000_1 {
                return lhs.box.midY > rhs.box.midY
            }
            return lhs.box.minX < rhs.box.minX
        }

        var lines: [[TextPiece]] = []
        for piece in sorted {
            if let index = lines.firstIndex(where: { line in
                line.contains { verticallyOverlaps($0.box, piece.box) }
            }) {
                lines[index].append(piece)
            } else {
                lines.append([piece])
            }
        }

        let rendered = lines.map { line -> String in
            line.sorted { $0.box.minX < $1.box.minX }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: " ")
        }.filter { !$0.isEmpty }

        if keepLineBreaks {
            return rendered.joined(separator: "\n")
        }
        return rendered.joined(separator: " ")
    }

    private static func verticallyOverlaps(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let overlap = min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY)
        let basis = min(lhs.height, rhs.height)
        if basis <= 0.000_1 {
            return abs(lhs.midY - rhs.midY) < 0.01
        }
        return overlap > basis * 0.35
    }
}
