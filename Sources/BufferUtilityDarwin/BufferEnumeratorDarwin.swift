import BufferUtility
import Foundation

public extension BufferEnumerator {

  func foundationEnumerateBuffer<C: Collection>(files: C, handler: BufferHandler<Data>) throws where C.Element == URL {

    precondition(options.bufferSizeLimit > 0)

    var stop = false
    var buffer = Data()

    func handleLoadedBuffer(fileIndex: Int) throws {
      try handler(buffer, fileIndex, &stop)
      buffer.removeAll(keepingCapacity: true)
    }

    for (fileIndex, readingFileURL) in files.enumerated() {

      if stop {
        return
      }

      try withAutoReleasePool {
        let currentFileHandle = try FileHandle(forReadingFrom: readingFileURL)
        try setup(fd: .init(rawValue: currentFileHandle.fileDescriptor))

        readloop: while true {
          let needBufferSize = options.bufferSizeLimit - buffer.count
          if #available(macOS 10.15.4, *) {
            if let newBuffer = try withAutoReleasePool({ try currentFileHandle.read(upToCount: needBufferSize) }) {
              // has new buffer
              buffer.append(newBuffer)
            } else {
              // no more data
              break readloop
            }
          } else {
            let newBuffer = withAutoReleasePool { currentFileHandle.readData(ofLength: needBufferSize) }
            if newBuffer.isEmpty {
              // no more data
              break readloop
            } else {
              buffer.append(newBuffer)
            }
          }

          if buffer.count == options.bufferSizeLimit {
            try handleLoadedBuffer(fileIndex: fileIndex)
            if stop {
              break readloop
            }
          }

        } // readloop end


        if #available(macOS 10.15.4, *) {
          try currentFileHandle.close()
        } else {
          currentFileHandle.closeFile()
        }

        if !options.allowMultipleFilesInOneBuffer, buffer.isEmpty {
          try handleLoadedBuffer(fileIndex: fileIndex)
        }

      } // end of autoreleasepool

    } // end of files loop

    // if has unhandled buffer
    if !buffer.isEmpty {
      try handleLoadedBuffer(fileIndex: files.count-1)
    }
  }
}

@_transparent
func withAutoReleasePool<T>(_ execute: () throws -> T) rethrows -> T {
  #if canImport(Darwin)
  return try autoreleasepool {
    try execute()
  }
  #else
  return try execute()
  #endif
}

