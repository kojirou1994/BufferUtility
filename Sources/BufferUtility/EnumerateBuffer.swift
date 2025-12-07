import SystemUp
import CStringInterop

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

  package func setup(fd: FileDescriptor) throws {
    if options.disableCache {
      #if canImport(Darwin)
      let v = try FileControl.control(fd, command: .noCache, value: 1)
      precondition(v == 0)
      #endif
    }
  }

  // MARK: System Framework
  func systemEnumerateBuffer(files: some Collection<some CStringConvertible>, handler: BufferHandler<UnsafeRawBufferPointer>) throws {

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

      let currentFileDescriptor = try SystemCall.open(readingFilePath, .readOnly)
      try setup(fd: currentFileDescriptor)

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

}

// MARK: Single file wrapper
public extension BufferEnumerator {

  @inlinable
  func systemEnumerateBuffer(file: some CStringConvertible, handler: BufferHandler<UnsafeRawBufferPointer>) throws {
    try systemEnumerateBuffer(files: CollectionOfOne(file), handler: handler)
  }
}
