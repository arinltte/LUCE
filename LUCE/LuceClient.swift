//
//  LuceClient.swift
//  LUCE
//
//  Created on 22/05/2026.
//

import SwiftUI
import Combine
import IOKit
import IOKit.graphics
import CoreGraphics
import ApplicationServices
import Darwin

// MARK: - Global State for Crash-Safe Cleanup

private weak var _globalLuceClient: LuceClient?

private func luceAtexitCleanup() {
    _globalLuceClient?.emergencyUnlock()
}

// MARK: - Global CGEvent Tap Callback

func luceEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let client = Unmanaged<LuceClient>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = client.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passRetained(event)
    }

    // Returning nil drops the event (blocks the keypress)
    return nil
}

// MARK: - Client

class LuceClient: ObservableObject {

    // MARK: Published State

    @Published var isKeyboardLocked: Bool = false {
        didSet {
            NotificationCenter.default.post(
                name: .keyboardLockChanged, object: nil,
                userInfo: ["isLocked": isKeyboardLocked]
            )
        }
    }

    @Published var brightnessLevel: Float? = nil
    @Published var brightnessWarning: String? = nil
    @Published var hasAccessibilityPermission: Bool = false
    @Published var lockError: String? = nil

    @Published var menuBarIcon: String =
        UserDefaults.standard.string(forKey: "menuBarIcon") ?? "keyboard" {
        didSet {
            UserDefaults.standard.set(menuBarIcon, forKey: "menuBarIcon")
            NotificationCenter.default.post(
                name: .menuBarIconChanged, object: nil,
                userInfo: ["icon": menuBarIcon]
            )
        }
    }

    @Published var appTheme: AppTheme =
        AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "Rare Jade") ?? .rareJade {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme")
        }
    }

    // MARK: Internal (accessed by global callback & atexit)

    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private static var atexitRegistered: Bool = false

    // MARK: Init

    init() {
        checkAccessibilityPermission()

        _globalLuceClient = self

        if !LuceClient.atexitRegistered {
            LuceClient.atexitRegistered = true
            atexit(luceAtexitCleanup)
        }
    }

    deinit {
        forceRemoveTap()
    }

    // MARK: - Brightness

    func refreshBrightness() {
        if let level = Self.getCurrentBrightness() {
            brightnessLevel = level
        } else {
            brightnessLevel = nil
        }
    }

    /// Reads the built-in display brightness dynamically supporting both Apple Silicon and Intel.
    static func getCurrentBrightness() -> Float? {
        // Method 1: DisplayServices API (Works on Apple Silicon and modern macOS)
        // Uses DisplayServicesGetBrightness which accurately reflects the macOS UI slider percentage
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        if let sym = dlsym(RTLD_DEFAULT, "DisplayServicesGetBrightness") {
            typealias DSGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
            let getBrightness = unsafeBitCast(sym, to: DSGetBrightnessFunc.self)
            
            var brightness: Float = 0.0
            if getBrightness(CGMainDisplayID(), &brightness) == 0 {
                return max(0, min(1, brightness))
            }
        }
        
        // Method 2: Fallback to IOKit IODisplayConnect (Legacy Intel displays)
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )

        guard result == kIOReturnSuccess else { return nil }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var brightness: Float = -1
            if IODisplayGetFloatParameter(service, 0,
                                          "brightness" as CFString,
                                          &brightness) == kIOReturnSuccess {
                IOObjectRelease(service)
                IOObjectRelease(iterator)
                return max(0, min(1, brightness))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return nil
    }

    // MARK: - Accessibility Permission

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Keyboard Lock

    func lockKeyboard() {
        // Reset warnings prior to check
        lockError = nil
        brightnessWarning = nil

        // 1. Check Accessibility first
        checkAccessibilityPermission()
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            lockError = "Accessibility permission is required."
            return
        }

        // 2. Check Brightness strictly ON-DEMAND when user attempts to lock
        refreshBrightness()
        if let level = brightnessLevel, level < 0.20 {
            let percent = Int(round(level * 100))
            brightnessWarning = "Screen brightness is at \(percent)%. Increase to at least 20% before locking so you can see the Unlock button."
            return
        }

        // 3. Apply the Lock
        // 14 is the raw value for NSSystemDefined.
        // This explicitly blocks the Media keys (Brightness, Volume, Play/Pause).
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
          | (1 << CGEventType.keyUp.rawValue)
          | (1 << CGEventType.flagsChanged.rawValue)
          | (1 << 14)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: luceEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lockError = "Failed to create keyboard lock. Check Privacy & Security settings."
            requestAccessibilityPermission()
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isKeyboardLocked = true
    }

    func unlockKeyboard() {
        forceRemoveTap()
        isKeyboardLocked = false
        brightnessWarning = nil
    }

    func emergencyUnlock() {
        forceRemoveTap()
    }

    private func forceRemoveTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
