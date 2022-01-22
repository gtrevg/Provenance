//
//  CoreOptions+Serialization.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public extension CoreOptional { // where Self:PVEmulatorCore {
    static func valueForOption<T>(_: T.Type, _ option: String, andMD5 md5: String? = nil) -> T? {
        let className = NSStringFromClass(Self.self)
        let key = "\(className).\(option)"
        let md5Key: String = [className, md5, option].compactMap{$0}.joined(separator: ".")

        DLOG("Looking for either key's `\(key)` or \(md5Key) with type \(T.self)")

        let savedOption = UserDefaults.standard.object(forKey: md5Key) ??  UserDefaults.standard.object(forKey: key)
        DLOG("savedOption found?: \(String(describing: savedOption)) isIt type: \(T.self), \(savedOption as? T)")

        if let savedOption = savedOption as? T {
            DLOG("Read key `\(md5Key)` option: \(savedOption)")
            return savedOption
        } else {
            DLOG("need to find options for key `\(option)`")
            let currentOptions: [CoreOption] = options
            guard let foundOption = findOption(forKey: option, options: currentOptions) else {
                ELOG("No option for key: `\(option)`")
                return nil
            }
            DLOG("Found option `\(foundOption)`")
            return foundOption.defaultValue as? T
            //return UserDefaults.standard.object(forKey: "\(className).\(foundOption)") as? T
        }
    }

    static func setValue(_ value: Encodable?, forOption option: CoreOption, andMD5 md5: String? = nil) {
        let className = NSStringFromClass(Self.self)
        let key = option.key
        let classedKey: String = [className, md5, key].compactMap{$0}.joined(separator: ".")
 
        // TODO: Make sure the value matches the option type
        DLOG("Options: Setting key: \(classedKey) to value: \(value ?? "nil")")
        UserDefaults.standard.set(value, forKey: classedKey)
        UserDefaults.standard.synchronize()
    }

    static func valueForOption(_ option: CoreOption) -> CoreOptionValue {
        switch option {
        case .bool:
            let value = valueForOption(Bool.self, option.key) ?? false
            return .bool(value)
        case .string:
            if let value = valueForOption(String.self, option.key) {
                return .string(value)
            } else {
                return .notFound
            }
        case .range:
            if let value = valueForOption(Int.self, option.key) {
                return .int(value)
            } else {
                return .notFound
            }
        case .rangef:
            if let value = valueForOption(Float.self, option.key) {
                return .float(value)
            } else {
                return .notFound
            }
        case .multi:
            if let value = valueForOption(Int.self, option.key) {
                return .int(value)
            } else if let value = valueForOption(String.self, option.key) {
                return .string(value)
            } else {
                return .notFound
            }
        case .enumeration:
            if let value = valueForOption(Int.self, option.key) {
                return .int(value)
            } else if let value = valueForOption(String.self, option.key) {
                return .string(value)
            } else {
                return .notFound
            }
        case .group:
            assertionFailure("Feature unfinished")
            return .notFound
        }
    }

    static func findOption(forKey key: String, options: [CoreOption]) -> CoreOption? {
        var foundOption: CoreOption?
        for option in options {
            let subOption = option.subOptionForKey(key)
            if subOption != nil {
                foundOption = subOption
            }
        }
        return foundOption
    }
}
