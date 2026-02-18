//
//  SettingsStore.swift
//  DrawThingsStudio
//
//  Thin abstraction over non-sensitive settings persistence.
//

import Foundation

protocol SettingsStore {
    func string(forKey defaultName: String) -> String?
    func integer(forKey defaultName: String) -> Int
    func bool(forKey defaultName: String) -> Bool
    func double(forKey defaultName: String) -> Double
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

struct UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey defaultName: String) -> String? {
        defaults.string(forKey: defaultName)
    }

    func integer(forKey defaultName: String) -> Int {
        defaults.integer(forKey: defaultName)
    }

    func bool(forKey defaultName: String) -> Bool {
        defaults.bool(forKey: defaultName)
    }

    func double(forKey defaultName: String) -> Double {
        defaults.double(forKey: defaultName)
    }

    func object(forKey defaultName: String) -> Any? {
        defaults.object(forKey: defaultName)
    }

    func set(_ value: Any?, forKey defaultName: String) {
        defaults.set(value, forKey: defaultName)
    }

    func removeObject(forKey defaultName: String) {
        defaults.removeObject(forKey: defaultName)
    }
}
