import Foundation

func debug(_ item: Any) {
  #if DEBUG
  print(item)
  #endif
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
