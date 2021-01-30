import Foundation
import BufferUtility

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])

let outputURL = outputDir.appendingPathComponent(input.lastPathComponent)

precondition(!FileManager.default.fileExists(atPath: outputURL.path), "Output existed!")

precondition(FileManager.default.createFile(atPath: outputURL.path, contents: nil), "Cannot create dst file!")

let inputFileHandle = try FileHandle(forReadingFrom: input)
let outputFileHandle = try FileHandle(forWritingTo: outputURL)
let bufferSize = 4 * 1024 * 1024

try asyncCachedEnumerate(input: { () -> Data? in
  autoreleasepool {
    if #available(macOS 10.15.4, *) {
      return try! inputFileHandle.read(upToCount: bufferSize)
    } else {
      let d = inputFileHandle.readData(ofLength: bufferSize)
      return d.isEmpty ? nil : d
    }
  }
}, output: { data in
  if #available(macOS 10.15.4, *) {
    try outputFileHandle.write(contentsOf: data)
  } else {
    outputFileHandle.write(data)
  }
})
