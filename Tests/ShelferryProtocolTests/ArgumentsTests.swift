import Testing
import Foundation
@testable import ShelferryProtocol

struct ArgumentsTests {
    @Test func testPathsAfterSeparatorAreLiteral() throws {
        let args = try Arguments(["add", "--copy", "--shelf", "work", "--", "-report.pdf", "a\nb.txt"])
        #expect(args.request.copy)
        #expect(args.request.shelf == "work")
        #expect(args.request.paths.count == 2)
        #expect(args.request.paths[0].hasSuffix("/-report.pdf"))
        #expect(args.request.paths[1].hasSuffix("/a\nb.txt"))
    }
    @Test func testDestructiveCommandsRequireExplicitShelfAndConfirmation() throws {
        #expect(throws: ServiceError.self) { try Arguments(["delete", "--yes"]) }
        #expect(throws: ServiceError.self) { try Arguments(["clear", "--shelf", "work"]) }
        _ = try Arguments(["delete", "--shelf", "work", "--yes"])
    }
    @Test func testInvalidInput() {
        for args in [["unknown"], ["add"], ["new", "--name"], ["rename", "--shelf", "a"], ["list", "unexpected"], ["list", "--null"], ["items", "a", "--null", "--json"]] {
            #expect(throws: ServiceError.self) { try Arguments(args) }
        }
    }
    @Test func testJSONPreservesUnusualFilenames() throws {
        let request = Request(command: "add", paths: ["/tmp/a\nb\t\".txt", "/tmp/日本語.txt"])
        let decoded = try JSONDecoder().decode(Request.self, from: JSONEncoder().encode(request))
        #expect(decoded.paths == request.paths)
    }
}
