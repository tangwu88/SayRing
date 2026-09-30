#!/usr/bin/env swift
// Backward-compatible macOS entrypoint. The Java exporter keeps PNG output
// deterministic across macOS, Windows and CI while preserving --check.
import Foundation

let root = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["java", "scripts/GenerateLauncherIcons.java"]
  + Array(CommandLine.arguments.dropFirst())
process.currentDirectoryURL = root
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
