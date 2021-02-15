import XCTest
import BufferUtility

final class BufferUtilityTests: XCTestCase {
  func testAsyncBuffer() throws {
    var number = 0
    let numberLimit = 100
    var numbers = [Int]()
    asyncCachedEnumerate { () -> Int? in
      number += 1
      return number == numberLimit ? nil : number
    } output: { (output) in
      Thread.sleep(forTimeInterval: 0.1)
      numbers.append(output)
    }
    XCTAssertTrue(numbers.elementsEqual(1..<numberLimit))
    print("EXIT")
  }
}
