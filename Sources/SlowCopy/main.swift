import Foundation
import BufferUtility

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])

let outputURL = outputDir.appendingPathComponent(input.lastPathComponent)

precondition(!FileManager.default.fileExists(atPath: outputURL.path), "Output existed!")

precondition(FileManager.default.createFile(atPath: outputURL.path, contents: nil), "Cannot create dst file!")

let outputFileHandle = try FileHandle.init(forWritingTo: outputURL)

try enumerateBuffer(file: input, bufferSizeLimit: 4 * 1024) { (buffer, _, _) in
  if #available(macOS 10.15.4, *) {
    try outputFileHandle.write(contentsOf: buffer)
  } else {
    outputFileHandle.write(Data(bytesNoCopy: .init(mutating: buffer.baseAddress!), count: buffer.count, deallocator: .none))
  }
}
