import SwiftUI

public enum DS {
    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
    }

    public enum Font {
        public static let title = SwiftUI.Font.title2.weight(.semibold)
        public static let rowTitle = SwiftUI.Font.body
        public static let rowDetail = SwiftUI.Font.callout
    }
}
