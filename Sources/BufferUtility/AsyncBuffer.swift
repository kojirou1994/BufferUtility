import Foundation

//protocol AsyncBufferItem: AnyObject {
//  associatedtype Buffer
//
//  init(buffer: Buffer)
//
//  func overwrite(buffer: Buffer)
//}

class AsyncCachedBuffer<T> {
  let condition: NSCondition  = .init()
  private var finished: Bool = false

  private var buffers: ContiguousArray<T>

  private let maximumBufferCount = 10

  init(maximumBufferCount: Int = 10) {
    buffers = .init()
    buffers.reserveCapacity(maximumBufferCount)
  }

  func add(buffer: T) {
    condition.lock()
    defer {
      condition.unlock()
    }
    debug("Add \(buffer)")
    while buffers.count == maximumBufferCount {
      condition.wait()
    }
    buffers.append(buffer)
    condition.signal()
  }

  var nextBuffer: T? {
    condition.lock()
    defer {
      condition.unlock()
    }
    while buffers.isEmpty {
      if finished {
        return nil
      } else {
        // not finished yet
        condition.wait()
      }
    }
    defer {
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

public func asyncCachedEnumerate<T>(input: @escaping () -> T?, output: (T) throws -> Void) rethrows {
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
