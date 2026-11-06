import Foundation
import AppKit

public enum Clipboard {
    public static func copy(_ text: String) {
        NSPasteboard.general.setString(text, forType: .string)
    }
}
