//
//  FAT.swift
//  SwiftMachO
//
//  Created by Linus Henze on 2020-04-15.
//  Copyright © 2020/2021 Pinauten GmbH. All rights reserved.
//

import Foundation

public let CPU_TYPE_ANY: UInt32 = UInt32.max
public let CPU_ARCH_ABI64: UInt32 = 0x1000000
public let CPU_TYPE_X86: UInt32 = 7
public let CPU_TYPE_I386: UInt32 = CPU_TYPE_X86   // For compatibility
public let CPU_TYPE_X86_64: UInt32 = CPU_TYPE_X86 | CPU_ARCH_ABI64
public let CPU_TYPE_ARM: UInt32 = 12
public let CPU_TYPE_ARM64: UInt32 = CPU_TYPE_ARM | CPU_ARCH_ABI64
public let CPU_TYPE_POWERPC: UInt32 = 18
public let CPU_TYPE_POWERPC64: UInt32 = CPU_TYPE_POWERPC | CPU_ARCH_ABI64

public enum FATError: Error {
    case notFAT
    case noBestArchFound
}

open class FAT {
    public var slices: [FATSlice] = []
    
    public init(fromData data: Data) throws {
        guard let magic = data.tryGetGeneric(type: UInt32.self) else {
            throw MachOError.ReadError
        }
        
        guard magic.bigEndian == 0xCAFEBABE else {
            throw FATError.notFAT
        }
        
        guard let nArchs = data.tryGetGeneric(type: UInt32.self, offset: 4)?.bigEndian else {
            throw MachOError.ReadError
        }
        
        for i in 0..<UInt(nArchs) {
            guard let cpuType = data.tryGetGeneric(type: UInt32.self, offset: 8 + (i * 20))?.bigEndian else {
                throw MachOError.ReadError
            }
            
            guard let cpuSubType = data.tryGetGeneric(type: UInt32.self, offset: 12 + (i * 20))?.bigEndian else {
                throw MachOError.ReadError
            }
            
            guard let offset = data.tryGetGeneric(type: UInt32.self, offset: 16 + (i * 20))?.bigEndian else {
                throw MachOError.ReadError
            }
            
            guard let size = data.tryGetGeneric(type: UInt32.self, offset: 20 + (i * 20))?.bigEndian else {
                throw MachOError.ReadError
            }
            
            guard offset + size <= data.count else {
                throw MachOError.BadFormat
            }
            
            slices.append(.init(cpuType: cpuType, cpuSubType: cpuSubType, data: data.subdata(in: Int(offset)..<Int(offset + size)), offset: offset))
        }
    }
    
    public func bestArch() throws -> FATSlice {
#if arch(arm64) || arch(arm)
        let targetCpuType = CPU_TYPE_ARM64
#elseif arch(x86_64)
        let targetCpuType = CPU_TYPE_X86_64
#else
        #error("Unknown architecture!")
#endif
        
        for slice in slices {
            if slice.cpuType == targetCpuType {
                return slice
            }
        }
        
        throw FATError.noBestArchFound
    }
    
    public struct FATSlice {
        public var cpuType: UInt32
        public var cpuSubType: UInt32
        public var data: Data
        public var offset: UInt32
        
        public init(cpuType: UInt32, cpuSubType: UInt32, data: Data, offset: UInt32) {
            self.cpuType = cpuType
            self.cpuSubType = cpuSubType
            self.data = data
            self.offset = offset
        }
    }
}
