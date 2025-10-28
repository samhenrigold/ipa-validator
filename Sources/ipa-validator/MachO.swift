//
//  MachO.swift
//  ipa-validator
//
//  Created by Sam on 2025-10-27.
//

import Foundation
import MachOKit

struct MachOEncryptionChecker {
    struct SliceStatus {
        let offset: UInt64
        let is64Bit: Bool
        let cryptId: UInt32
        var isEncrypted: Bool { cryptId == 1 }
    }

    struct Result {
        let slices: [SliceStatus]
        var allSlicesEncrypted: Bool { !slices.isEmpty && slices.allSatisfy(\.isEncrypted) }
    }

    private static let encryptionInfoCommandSize = 20

    static func checkEncryption(url: URL) throws -> Result {
        let data = try Data(contentsOf: url)
        let file = try MachOKit.loadFromFile(url: url)

        switch file {
        case .machO(let machOFile):
            return Result(slices: [checkSlice(machOFile, offset: 0, data: data)])

        case .fat(let fatFile):
            let slices = try fatFile.machOFiles().map { machO in
                checkSlice(machO, offset: UInt64(machO.headerStartOffset), data: data)
            }
            return Result(slices: slices)
        }
    }

    private static func checkSlice(_ machO: MachOFile, offset: UInt64, data: Data) -> SliceStatus {
        var cryptId: UInt32 = 0

        for loadCommand in machO.loadCommands
        where
            loadCommand.type == .encryptionInfo || loadCommand.type == .encryptionInfo64
        {

            let commandOffset = Int(machO.headerStartOffset) + machO.headerSize + loadCommand.offset
            guard commandOffset + encryptionInfoCommandSize <= data.count else { break }

            cryptId = data.withUnsafeBytes { ptr in
                let raw = ptr.load(fromByteOffset: commandOffset + 16, as: UInt32.self)
                return machO.isSwapped ? raw.byteSwapped : raw
            }
            break
        }

        return SliceStatus(offset: offset, is64Bit: machO.is64Bit, cryptId: cryptId)
    }
}
