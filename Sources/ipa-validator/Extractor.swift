//
//  Extractor.swift
//  ipa-validator
//
//  Created by Sam on 2025-10-27.
//

import ArgumentParser
import Foundation
import ZIPFoundation

struct IPAExtractor {
    static func findInfoPlist(in archive: Archive) -> Entry? {
        archive.first { entry in
            guard entry.type == .file else { return false }
            let components = entry.path.split(separator: "/", omittingEmptySubsequences: true).filter { $0 != "." }
            guard let payloadIdx = components.firstIndex(of: "Payload") else { return false }
            return payloadIdx + 3 == components.count
                && components[payloadIdx + 1].hasSuffix(".app")
                && components[payloadIdx + 2] == "Info.plist"
        }
    }

    static func data(from entry: Entry, in archive: Archive) throws -> Data {
        var data = Data()
        data.reserveCapacity(Int(entry.uncompressedSize))
        _ = try archive.extract(entry, consumer: { data.append($0) })
        guard !data.isEmpty else {
            throw ValidationError("Entry is empty: \(entry.path)")
        }
        return data
    }

    static func temporaryFile(for entry: Entry, in archive: Archive, tempDir: URL) throws -> URL {
        let fileName = String(entry.path.split(separator: "/").last ?? "executable")
        let outURL = tempDir.appendingPathComponent(fileName)
        _ = try archive.extract(entry, to: outURL)
        return outURL
    }

    static func bundleExecutable(from data: Data) throws -> String {
        guard
            let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any],
            let exec = dict["CFBundleExecutable"] as? String, !exec.isEmpty
        else {
            throw ValidationError("CFBundleExecutable not found in Info.plist")
        }
        return exec
    }
}
