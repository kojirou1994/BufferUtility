import Foundation
#if os(Linux)
import SystemPackage
#else
import System
#endif

public typealias BufferHandler<Buffer> = (_ buffer: Buffer, _ fileOffset: Int, _ stop: inout Bool) throws -> Void

public func enumerateBuffer(file: URL, bufferSizeLimit: Int, handler: BufferHandler<UnsafeRawBufferPointer>) throws {
  try enumerateBuffer(files: CollectionOfOne(file), allowMultipleFilesInOneBuffer: false, bufferSizeLimit: bufferSizeLimit, handler: handler)
}

public func enumerateBuffer(file: String, bufferSizeLimit: Int, handler: BufferHandler<UnsafeRawBufferPointer>) throws {
  try enumerateBuffer(files: CollectionOfOne(file), allowMultipleFilesInOneBuffer: false, bufferSizeLimit: bufferSizeLimit, handler: handler)
}

public func enumerateBuffer<C: Collection>(files: C, allowMultipleFilesInOneBuffer: Bool, bufferSizeLimit: Int, handler: BufferHandler<UnsafeRawBufferPointer>) throws where C.Element == URL {
  if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
    try systemEnumerateBuffer(files: files.lazy.map { FilePath($0.path) }, allowMultipleFilesInOneBuffer: allowMultipleFilesInOneBuffer, bufferSizeLimit: bufferSizeLimit, handler: handler)
  } else {
    try foundationEnumerateBuffer(files: files, allowMultipleFilesInOneBuffer: allowMultipleFilesInOneBuffer, bufferSizeLimit: bufferSizeLimit) { data, fileIndex, stop in
      try data.withUnsafeBytes { buffer in
        try handler(buffer, fileIndex, &stop)
      }
    }
  }
}

public func enumerateBuffer<C: Collection>(files: C, allowMultipleFilesInOneBuffer: Bool, bufferSizeLimit: Int, handler: BufferHandler<UnsafeRawBufferPointer>) throws where C.Element == String {
  if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
    try systemEnumerateBuffer(files: files.lazy.map { FilePath($0) }, allowMultipleFilesInOneBuffer: allowMultipleFilesInOneBuffer, bufferSizeLimit: bufferSizeLimit, handler: handler)
  } else {
    try foundationEnumerateBuffer(files: files.lazy.map { URL(fileURLWithPath: $0) }, allowMultipleFilesInOneBuffer: allowMultipleFilesInOneBuffer, bufferSizeLimit: bufferSizeLimit) { data, fileIndex, stop in
      try data.withUnsafeBytes { buffer in
        try handler(buffer, fileIndex, &stop)
      }
    }
  }
}

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
public func systemEnumerateBuffer(file: FilePath, bufferSizeLimit: Int, handler: BufferHandler<UnsafeRawBufferPointer>) throws {
  try systemEnumerateBuffer(files: CollectionOfOne(file), allowMultipleFilesInOneBuffer: true, bufferSizeLimit: bufferSizeLimit, handler: handler)
}

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
public func systemEnumerateBuffer<C: Collection>(files: C, allowMultipleFilesInOneBuffer: Bool, bufferSizeLimit: Int, handler: BufferHandler<UnsafeRawBufferPointer>) throws
where C.Element == FilePath {

  precondition(bufferSizeLimit > 0)

  let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSizeLimit, alignment: MemoryLayout<UInt8>.alignment)
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

    readloop: while true {
      let newLoadedBufferSize = try currentFileDescriptor.read(into: UnsafeMutableRawBufferPointer(rebasing: buffer.dropFirst(loadedBufferSize)))

      if newLoadedBufferSize == 0 {
        // no more data, stop the loop
        break readloop
      }

      loadedBufferSize += newLoadedBufferSize

      if loadedBufferSize == bufferSizeLimit {
        try handleLoadedBuffer(fileIndex: fileIndex)
        if stop {
          break readloop
        }
      }

    } // readloop end

    try currentFileDescriptor.close()

    if !allowMultipleFilesInOneBuffer, loadedBufferSize > 0 {
      try handleLoadedBuffer(fileIndex: fileIndex)
    }

  }

  // if has unhandled buffer
  if loadedBufferSize > 0 {
    try handleLoadedBuffer(fileIndex: files.count-1)
  }
}

public func foundationEnumerateBuffer(file: URL, bufferSizeLimit: Int, handler: BufferHandler<Data>) throws {
  try foundationEnumerateBuffer(files: CollectionOfOne(file), allowMultipleFilesInOneBuffer: true, bufferSizeLimit: bufferSizeLimit, handler: handler)
}

public func foundationEnumerateBuffer<C: Collection>(files: C, allowMultipleFilesInOneBuffer: Bool, bufferSizeLimit: Int, handler: BufferHandler<Data>) throws where C.Element == URL {

  precondition(bufferSizeLimit > 0)

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

      readloop: while true {
        let needBufferSize = bufferSizeLimit - buffer.count
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

        if buffer.count == bufferSizeLimit {
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

      if !allowMultipleFilesInOneBuffer, buffer.isEmpty {
        try handleLoadedBuffer(fileIndex: fileIndex)
      }

    } // end of autoreleasepool

  } // end of files loop

  // if has unhandled buffer
  if !buffer.isEmpty {
    try handleLoadedBuffer(fileIndex: files.count-1)
  }
}
