import Testing
import Foundation

struct CueTests {
    @Test func example() async throws {
        #expect(true)
    }
    
    @Test func testSimpleAddition() async throws {
        let result = 2 + 2
        #expect(result == 4, "Basic addition should work")
    }
    
    @Test func testStringOperations() async throws {
        let testString = "Hello"
        #expect(testString.count == 5, "String length should be correct")
        #expect(testString.uppercased() == "HELLO", "Uppercased string should match")
    }
    
    @Test func testAsyncOperation() async throws {
        let startTime = Date()
        try await Task.sleep(for: .milliseconds(100))
        let endTime = Date()
        
        #expect(endTime.timeIntervalSince(startTime) >= 0.1, 
               "Async sleep should take at least 100ms")
    }
}
