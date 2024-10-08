import Foundation
import DequeModule
//protocol AsyncBufferItem: AnyObject {
//  associatedtype Buffer
//
//  init(buffer: Buffer)
//
//  func overwrite(buffer: Buffer)
//}

final class AsyncCachedBuffer<T>: Sendable {
  let condition: NSCondition  = .init()
  nonisolated(unsafe)
  private var finished: Bool = false
  nonisolated(unsafe)
  private var buffers: Deque<T>

  private let maximumBufferCount = 10

  init(maximumBufferCount: Int = 10) {
    buffers = .init()
    buffers.reserveCapacity(maximumBufferCount)
  }

  func add(buffer: T) {
    condition.lock()
    defer {
      debug("Leave \(#function)")
      condition.unlock()
    }
    debug("Add \(buffer)")
    while buffers.count == maximumBufferCount {
      condition.wait()
    }
    buffers.append(buffer)
    debug("Signal \(#function)")
    condition.signal()
  }

  var nextBuffer: T? {
    condition.lock()
    defer {
      debug("Leave \(#function)")
      condition.unlock()
    }
    while buffers.isEmpty {
      if finished {
        return nil
      } else {
        // not finished yet
        condition.wait()//until: Date(timeIntervalSinceNow: 0.1))
      }
    }
    defer {
      debug("Signal \(#function)")
      condition.signal()
    }
    return buffers.removeFirst()
  }

  func finish() {
    condition.lock()
    assert(!finished, "Shoud be called only one time.")
    finished = true
    condition.unlock()
  }
}

public func asyncCachedEnumerate<T>(input: @escaping @Sendable () -> T?, output: (T) throws -> Void) rethrows {
  let queue = AsyncCachedBuffer<T>()
  Thread {
    while let nextInput = input() {
      queue.add(buffer: nextInput)
    }
    queue.finish()
  }.start()
  while let buffer = queue.nextBuffer {
    debug("Use output: \(buffer)")
    try output(buffer)
  }
}
