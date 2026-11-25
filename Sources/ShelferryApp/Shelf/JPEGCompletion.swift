import Foundation

/// Finds the outer JPEG's end marker, ignoring markers inside metadata thumbnails.
enum JPEGCompletion {
    static func hasEndMarker(_ data: Data) -> Bool {
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { return false }
            var offset = 2
            var inScan = false
            var sawScan = false

            while offset < bytes.count {
                if inScan {
                    while offset < bytes.count, bytes[offset] != 0xFF { offset += 1 }
                }
                guard offset < bytes.count, bytes[offset] == 0xFF else { return false }
                while offset < bytes.count, bytes[offset] == 0xFF { offset += 1 }
                guard offset < bytes.count else { return false }
                let marker = bytes[offset]
                offset += 1

                // Escaped FF bytes and restart markers belong to compressed scan data.
                if inScan, marker == 0x00 || (0xD0...0xD7).contains(marker) { continue }
                if marker == 0xD9 { return sawScan }
                if marker == 0x01 { continue } // Standalone TEM marker.
                guard marker != 0x00, marker != 0xD8, offset + 2 <= bytes.count else { return false }

                // Every other marker has a length that includes the two length bytes.
                let length = Int(bytes[offset]) * 256 + Int(bytes[offset + 1])
                guard length >= 2, length <= bytes.count - offset else { return false }
                offset += length
                inScan = marker == 0xDA
                if inScan { sawScan = true }
            }
            return false
        }
    }
}
