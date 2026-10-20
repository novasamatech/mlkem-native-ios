import Foundation

extension Data {
    init(hex: String) {
        let digits = Array(hex.utf8)
        precondition(digits.count.isMultiple(of: 2), "odd hex length")

        self.init(capacity: digits.count / 2)

        for index in stride(from: 0, to: digits.count, by: 2) {
            append(Self.nibble(digits[index]) << 4 | Self.nibble(digits[index + 1]))
        }
    }

    static func random(count: Int) -> Data {
        Data((0 ..< count).map { _ in UInt8.random(in: .min ... .max) })
    }

    private static func nibble(_ digit: UInt8) -> UInt8 {
        switch digit {
        case UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return digit - UInt8(ascii: "0")
        case UInt8(ascii: "a") ... UInt8(ascii: "f"):
            return digit - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A") ... UInt8(ascii: "F"):
            return digit - UInt8(ascii: "A") + 10
        default:
            preconditionFailure("invalid hex digit")
        }
    }
}
