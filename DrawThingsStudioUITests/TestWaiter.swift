import XCTest

extension XCTestCase {
    func waitForUI(seconds: TimeInterval) {
        let expectation = expectation(description: "UI settle wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 1)
    }

    func waitForUI(milliseconds: Int) {
        waitForUI(seconds: TimeInterval(milliseconds) / 1000.0)
    }
}
