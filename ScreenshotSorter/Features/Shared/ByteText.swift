import Foundation

enum ByteText {
    /// "0 MB" instead of the system's "Zero kB"; otherwise the standard file-size format.
    static func short(_ bytes: Int) -> String {
        bytes == 0 ? "0 MB" : Int64(bytes).formatted(.byteCount(style: .file))
    }
}
