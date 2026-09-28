//
//  Snapshot.swift
//  HebcalWatchCoreTests
//
//  Golden-file ("snapshot") assertions. The expected output is a text file
//  checked in under Snapshots/, so a change in behavior shows up as a
//  readable diff in code review.
//
//  - First run (no golden file yet): the file is written and the test fails
//    once, asking you to review and commit it.
//  - On a mismatch the actual output is written next to the golden file as
//    `<name>.actual.<ext>` (git-ignored); compare the two with any diff tool.
//    If the new output is right, accept it by re-running with
//    SNAPSHOT_RECORD=1 (e.g. `SNAPSHOT_RECORD=1 swift test`), or just
//    move the .actual file over the golden one.
//

import Foundation
import Testing

func assertSnapshot(_ actual: String, named name: String,
                    filePath: String = #filePath, sourceLocation: SourceLocation = #_sourceLocation) {
    let dir = URL(filePath: filePath).deletingLastPathComponent().appending(path: "Snapshots")
    let golden = dir.appending(path: name)
    let actualFile = dir.appending(path: golden.deletingPathExtension().lastPathComponent
                                   + ".actual." + golden.pathExtension)
    let record = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"

    guard !record, let expected = try? String(contentsOf: golden, encoding: .utf8) else {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? actual.write(to: golden, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: actualFile)
        Issue.record("Recorded snapshot \(golden.path). Review it, commit it, and re-run.",
                     sourceLocation: sourceLocation)
        return
    }
    if expected == actual {
        try? FileManager.default.removeItem(at: actualFile)
        return
    }
    try? actual.write(to: actualFile, atomically: true, encoding: .utf8)
    let expectedLines = expected.components(separatedBy: "\n")
    let actualLines = actual.components(separatedBy: "\n")
    var report = [String]()
    for i in 0..<max(expectedLines.count, actualLines.count) where report.count < 20 {
        let e = i < expectedLines.count ? expectedLines[i] : "<missing>"
        let a = i < actualLines.count ? actualLines[i] : "<missing>"
        if e != a {
            report.append("line \(i + 1):\n  - \(e)\n  + \(a)")
        }
    }
    Issue.record("""
        Snapshot \(name) changed. Actual output written to \(actualFile.path)
        Compare: diff "\(golden.path)" "\(actualFile.path)"
        \(report.joined(separator: "\n"))
        """, sourceLocation: sourceLocation)
}
