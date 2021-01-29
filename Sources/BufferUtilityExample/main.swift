import Foundation
import BufferUtility
import CryptoKit
import System

let input = CommandLine.arguments[1]

if #available(macOS 11.0, *) {
  var sha256 = SHA256()
  try enumerateBuffer(file: input, bufferSizeLimit: 1024*1024) { (buffer, _, _) in
    sha256.update(bufferPointer: buffer)
  }
  print(Array(sha256.finalize()))
} else {
  fatalError()
}

