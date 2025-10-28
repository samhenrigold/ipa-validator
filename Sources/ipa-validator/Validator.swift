//
//  Validator.swift
//  ipa-validator
//
//  Created by Sam on 2025-10-27.
//

import ArgumentParser
import Foundation
import ZIPFoundation

// ANSI color codes for terminal output
private let red = "\u{001B}[31m"
private let green = "\u{001B}[32m"
private let yellow = "\u{001B}[33m"
private let reset = "\u{001B}[0m"
private let bold = "\u{001B}[1m"

// Shell convention: exit code for signal termination = 128 + signal number
extension Int32 {
    fileprivate var asSignalExitCode: Int32 { 128 + self }
}

struct ValidationResult {
    let path: String
    let filename: String
    let encrypted: Bool?
    let slices: [MachOEncryptionChecker.SliceStatus]
    let error: String?
}

@main
struct IPAValidator: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ipa-validator",
        abstract: "Check if IPA executables are encrypted.",
        discussion: """
            Inspects Mach-O LC_ENCRYPTION_INFO load commands to determine encryption status.

            Exit codes:
              0 - All files are encrypted
              1 - One or more files are NOT encrypted
              2 - Error(s) occurred

            Examples:
              ipa-validator MyApp.ipa
              ipa-validator *.ipa
              ipa-validator --quiet *.ipa | grep 'not-encrypted'
            """,
        version: "0.1.0"
    )

    @Argument(help: "IPA file(s) to validate.")
    var ipaPaths: [String] = []

    @Flag(name: .shortAndLong, help: "Show verbose output.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Machine-readable output.")
    var quiet: Bool = false

    mutating func run() async throws {
        guard !ipaPaths.isEmpty else {
            throw ValidationError("No IPA files specified.")
        }

        setupSignalHandlers()

        let sharedTempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipa-validator-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedTempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sharedTempDir) }

        let results = try await processIPAs(tempDir: sharedTempDir)

        let hadErrors = !results.allSatisfy { $0.error == nil }
        let anyNotEncrypted = results.contains { $0.encrypted == false }

        if hadErrors { throw ExitCode(2) }
        if anyNotEncrypted { throw ExitCode(1) }
    }

    private func setupSignalHandlers() {
        signal(SIGINT) { _ in
            // Backspace to erase the ^C that appears in terminal
            let bsp = String(UnicodeScalar(8))
            fputs("\(bsp)\(bsp)\rInterrupted\n", stderr)
            Darwin.exit(SIGINT.asSignalExitCode)
        }

        signal(SIGTERM) { _ in
            fputs("\nTerminated\n", stderr)
            Darwin.exit(SIGTERM.asSignalExitCode)
        }
    }

    private func processIPAs(tempDir: URL) async throws -> [ValidationResult] {
        try await withThrowingTaskGroup(of: ValidationResult.self) { group in
            for path in ipaPaths {
                group.addTask { try processIPA(path, tempDir: tempDir) }
            }

            var results: [ValidationResult] = []
            for try await result in group {
                printResult(result)
                results.append(result)
            }
            return results
        }
    }

    private func processIPA(_ path: String, tempDir: URL) throws -> ValidationResult {
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent

        guard FileManager.default.fileExists(atPath: url.path) else {
            return ValidationResult(path: path, filename: filename, encrypted: nil, slices: [], error: "File not found")
        }

        do {
            let archive = try Archive(url: url, accessMode: .read)

            guard let infoPlistEntry = IPAExtractor.findInfoPlist(in: archive) else {
                return ValidationResult(
                    path: path,
                    filename: filename,
                    encrypted: nil,
                    slices: [],
                    error: "Info.plist not found"
                )
            }

            let appBundleRoot = infoPlistEntry.path.replacingOccurrences(of: "/Info.plist", with: "")
            if verbose { fputs("[\(filename)] Bundle: \(appBundleRoot)/\n", stderr) }

            let infoPlistData = try IPAExtractor.data(from: infoPlistEntry, in: archive)
            let bundleExecutable = try IPAExtractor.bundleExecutable(from: infoPlistData)
            if verbose { fputs("[\(filename)] Executable: \(bundleExecutable)\n", stderr) }

            let execPath = "\(appBundleRoot)/\(bundleExecutable)"
            guard let execEntry = archive[execPath] else {
                return ValidationResult(
                    path: path,
                    filename: filename,
                    encrypted: nil,
                    slices: [],
                    error: "Executable not found: \(bundleExecutable)"
                )
            }

            let uniqueTempDir = tempDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: uniqueTempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: uniqueTempDir) }

            let tempExecURL = try IPAExtractor.temporaryFile(for: execEntry, in: archive, tempDir: uniqueTempDir)
            let result = try MachOEncryptionChecker.checkEncryption(url: tempExecURL)

            return ValidationResult(
                path: path,
                filename: filename,
                encrypted: result.allSlicesEncrypted,
                slices: result.slices,
                error: nil
            )
        } catch {
            return ValidationResult(
                path: path,
                filename: filename,
                encrypted: nil,
                slices: [],
                error: error.localizedDescription
            )
        }
    }

    private func printResult(_ result: ValidationResult) {
        let isTTY = isatty(STDOUT_FILENO) != 0

        if quiet {
            if result.error != nil {
                print("\(result.path)\terror")
            } else if let encrypted = result.encrypted {
                print("\(result.path)\t\(encrypted ? "encrypted" : "not-encrypted")")
            }
            return
        }

        if let error = result.error {
            let icon = isTTY ? "\(red)\(bold)✗\(reset)" : "✗"
            fputs("\(icon) \(result.filename)\n  Error: \(error)\n", stderr)
        } else if let encrypted = result.encrypted {
            let icon: String
            let status: String

            if isTTY {
                if encrypted {
                    icon = "\(green)\(bold)✓\(reset)"
                    status = "\(green)encrypted\(reset)"
                } else {
                    icon = "\(red)\(bold)✗\(reset)"
                    status = "\(red)not encrypted\(reset)"
                }
            } else {
                icon = encrypted ? "✓" : "✗"
                status = encrypted ? "encrypted" : "not encrypted"
            }

            print("\(icon) \(result.filename) (\(status))")

            if verbose && !result.slices.isEmpty {
                for (idx, slice) in result.slices.enumerated() {
                    let arch = slice.is64Bit ? "arm64" : "armv7"
                    print("  Slice \(idx): \(arch) cryptid=\(slice.cryptId)")
                }
            }
        }
    }
}
