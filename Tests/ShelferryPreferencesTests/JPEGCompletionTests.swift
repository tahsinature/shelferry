import Foundation
import Testing
@testable import ShelferryApp

struct JPEGCompletionTests {
    @Test func ignoresEmbeddedThumbnailAndRequiresOuterEndMarker() {
        // APP1 contains a complete miniature JPEG; the main scan is still arriving.
        let header: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE1, 0, 6, 0xFF, 0xD8, 0xFF, 0xD9]
        let scan: [UInt8] = [0xFF, 0xDA, 0, 2, 42, 0xFF, 0, 17, 0xFF, 0xD0, 23]
        #expect(!JPEGCompletion.hasEndMarker(Data(header + scan)))
        #expect(JPEGCompletion.hasEndMarker(Data(header + scan + [0xFF, 0xD9])))
        #expect(JPEGCompletion.hasEndMarker(Data(header + scan + [0xFF, 0xD9, 0, 0])))
    }

    @Test func handlesMultipleScansAndTruncatedSegments() {
        let progressive: [UInt8] = [0xFF, 0xD8, 0xFF, 0xDA, 0, 2, 42,
                                    0xFF, 0xC4, 0, 3, 7, 0xFF, 0xDA, 0, 2, 23, 0xFF, 0xD9]
        #expect(JPEGCompletion.hasEndMarker(Data(progressive)))
        for count in 0..<progressive.count {
            #expect(!JPEGCompletion.hasEndMarker(Data(progressive.prefix(count))))
        }
    }
}
