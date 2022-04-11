import Foundation
import SystemPackage

public struct BufferEnumerator {
  public init(options: Options) {
    self.options = options
  }

  public struct Options {
    public init(bufferSizeLimit: Int, allowMultipleFilesInOneBuffer: Bool = true, disableCache: Bool = true) {
      self.bufferSizeLimit = bufferSizeLimit
      self.allowMultipleFilesInOneBuffer = allowMultipleFilesInOneBuffer
      self.disableCache = disableCache
    }

    public let bufferSizeLimit: Int
    public let allowMultipleFilesInOneBuffer: Bool
    public let disableCache: Bool
  }

  public typealias BufferHandler<Buffer> = (_ buffer: Buffer, _ fileOffset: Int, _ stop: inout Bool) throws -> Void

  public var options: Options
}

public extension BufferEnumerator {

  private func setup(fd: CInt) throws {
    if options.disableCache {
      #if canImport(Darwin)
      precondition(fcntl(fd, F_NOCACHE, 1) == 0)
      #endif
    }
  }

  // MARK: System Framework
  func systemEnumerateBuffer<C: Collection>(files: C, handler: BufferHandler<UnsafeRawBufferPointer>) throws where C.Element == FilePath {

    precondition(options.bufferSizeLimit > 0)

    let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: options.bufferSizeLimit, alignment: MemoryLayout<UInt8>.alignment)
    defer {
      buffer.deallocate()
    }

    var stop = false
    var loadedBufferSize = 0

    func handleLoadedBuffer(fileIndex: Int) throws {
      try handler(.init(rebasing: buffer.prefix(loadedBufferSize)), fileIndex, &stop)
      loadedBufferSize = 0
    }

    for (fileIndex, readingFilePath) in files.enumerated() {
      if stop {
        return
      }

      let currentFileDescriptor = try FileDescriptor.open(readingFilePath, .readOnly)
      try setup(fd: currentFileDescriptor.rawValue)

      readloop: while true {
        let newLoadedBufferSize = try currentFileDescriptor.read(into: UnsafeMutableRawBufferPointer(rebasing: buffer.dropFirst(loadedBufferSize)))

        if newLoadedBufferSize == 0 {
          // no more data, stop the loop
          break readloop
        }

        loadedBufferSize += newLoadedBufferSize

        if loadedBufferSize == options.bufferSizeLimit {
          try handleLoadedBuffer(fileIndex: fileIndex)
          if stop {
            break readloop
          }
        }

      } // readloop end

      try currentFileDescriptor.close()

      if !options.allowMultipleFilesInOneBuffer, loadedBufferSize > 0 {
        try handleLoadedBuffer(fileIndex: fileIndex)
      }

    }

    // if has unhandled buffer
    if loadedBufferSize > 0 {
      try handleLoadedBuffer(fileIndex: files.count-1)
    }
  }

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
        try setup(fd: currentFileHandle.fileDescriptor)

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

// MARK: Collection wrappers
public extension BufferEnumerator {
  // MARK: URL inputs
  @inlinable
  func enumerateBuffer<C: Collection>(files: C, handler: BufferHandler<UnsafeRawBufferPointer>) throws where C.Element == URL {
    try systemEnumerateBuffer(files: files.lazy.map { FilePath($0.path) }, handler: handler)
  }

  // MARK: String inputs
  @inlinable
  func enumerateBuffer<C: Collection>(files: C, handler: BufferHandler<UnsafeRawBufferPointer>) throws where C.Element == String {
    try systemEnumerateBuffer(files: files.lazy.map { FilePath($0) }, handler: handler)
  }
}

// MARK: Single file wrapper
public extension BufferEnumerator {
  @inlinable
  func enumerateBuffer(file: URL, handler: BufferHandler<UnsafeRawBufferPointer>) throws {
    try enumerateBuffer(files: CollectionOfOne(file), handler: handler)
  }

  @inlinable
  func enumerateBuffer(file: String, handler: BufferHandler<UnsafeRawBufferPointer>) throws {
    try enumerateBuffer(files: CollectionOfOne(file), handler: handler)
  }

  @inlinable
  func systemEnumerateBuffer(file: FilePath, handler: BufferHandler<UnsafeRawBufferPointer>) throws {
    try systemEnumerateBuffer(files: CollectionOfOne(file), handler: handler)
  }

  @inlinable
  func foundationEnumerateBuffer(file: URL, bufferSizeLimit: Int, handler: BufferHandler<Data>) throws {
    try foundationEnumerateBuffer(files: CollectionOfOne(file), handler: handler)
  }
}
