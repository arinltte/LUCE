//
//  LuceView.swift
//  LUCE
//
//  Created on 22/05/2026.
//

import SwiftUI

struct LuceView: View {
    @ObservedObject var client: LuceClient
    var onClose: () -> Void

    @State private var showAbout: Bool   = false
    @State private var isPulsing: Bool   = false

    @State private var updateStatus: String = "Check for Updates"
    @State private var updateURL: String?   = nil

    private let baseWindowWidth: CGFloat = 320

    // MARK: - Dynamic Height

    private var dynamicWindowHeight: CGFloat {
        if client.isKeyboardLocked { return 250 }
        if showAbout { return 350 }

        // Base height accounts for:
        // Header + Instructional Text + Lock Button + Bottom Bar + Padding/Spacing
        var h: CGFloat = 180
        
        // Add height dynamically as multi-line banners appear
        if client.brightnessWarning != nil { h += 65 }
        if !client.hasAccessibilityPermission { h += 65 }
        if client.lockError != nil { h += 40 }
        
        return h
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if client.isKeyboardLocked {
                lockedContent
            } else if showAbout {
                aboutContent
            } else {
                mainContent
            }

            // Pushes the footer exactly to the bottom bounds
            Spacer(minLength: 0)

            if !client.isKeyboardLocked {
                Divider().opacity(0.5)
                bottomBar
            }
        }
        .frame(width: baseWindowWidth, height: dynamicWindowHeight)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dynamicWindowHeight)
        .animation(.easeInOut(duration: 0.2), value: showAbout)
        .animation(.easeInOut(duration: 0.25), value: client.isKeyboardLocked)
        .tint(client.appTheme.accentColor)
        .background(
            ZStack {
                AmbientThemeBackground(theme: client.appTheme)
                if client.isKeyboardLocked {
                    Rectangle().fill(Color.red.opacity(0.07))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(client.isKeyboardLocked ? Color.red.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            client.checkAccessibilityPermission()
        }
    }

    // ================================================================
    // MARK: - Main Content
    // ================================================================

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("LUCE")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { withAnimation { showAbout = true } }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Brightness warning
            if let bw = client.brightnessWarning {
                warningBanner(
                    icon: "sun.min",
                    color: .orange,
                    message: bw
                )
            }

            // Accessibility permission warning
            if !client.hasAccessibilityPermission {
                warningBanner(
                    icon: "lock.shield",
                    color: .orange,
                    message: "Accessibility permission required. Grant it in System Settings → Privacy & Security → Accessibility."
                )
            }

            // Lock error
            if let error = client.lockError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .padding(.top, 1) // Optical alignment
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Grouping the descriptive text tightly with the action button
            VStack(alignment: .leading, spacing: 10) {
                Text("Lock your keyboard to clean it safely without triggering unintended key presses.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: { client.lockKeyboard() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
                        Text("Lock Keyboard")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(client.appTheme.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    // ================================================================
    // MARK: - Locked Content
    // ================================================================

    private var lockedContent: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            // Pulsing lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 42))
                .foregroundColor(.red.opacity(isPulsing ? 0.45 : 1.0))
                .animation(
                    .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: isPulsing
                )

            Text("Keyboard Locked")
                .font(.system(size: 16, weight: .bold))

            Text("Use mouse or trackpad to click Unlock.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            // Unlock button
            Button(action: { client.unlockKeyboard() }) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 15))
                    Text("Unlock")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .onAppear { isPulsing = true }
        .onDisappear { isPulsing = false }
    }

    // ================================================================
    // MARK: - About Content
    // ================================================================

    private var aboutContent: some View {
        VStack(spacing: 10) {
            Text("About")
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 3) {
                if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .cornerRadius(12)
                }
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "LUCE")
                    .font(.system(size: 13, weight: .bold))
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Check for Updates
            Button(action: checkForUpdates) {
                Text(updateStatus)
                    .font(.system(size: 11))
                    .foregroundColor(updateURL != nil ? .white : nil)
                    .padding(.horizontal, updateURL != nil ? 8 : 0)
                    .padding(.vertical, updateURL != nil ? 3 : 0)
                    .background(updateURL != nil ? client.appTheme.accentColor : Color.clear)
                    .cornerRadius(4)
            }
            .controlSize(.small)
            .disabled(updateStatus == "Checking…" || updateStatus == "Up to Date")

            Divider().opacity(0.5)

            HStack {
                Text("Menu Bar Icon")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $client.menuBarIcon) {
                    Text("⌨️ Keyboard").tag("keyboard")
                    Text("🔒 Lock").tag("lock.fill")
                    Text("🛡️ Shield").tag("lock.shield")
                    Text("🧹 Broom").tag("broom")
                    Text("✨ Sparkles").tag("sparkles")
                    Text("💧 Drop").tag("drop.fill")
                    Text("🔌 Plug").tag("powerplug")
                    Text("⚡ Bolt").tag("bolt.fill")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            HStack {
                Text("Theme")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $client.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text("2026 Developed by [arinltte](https://github.com/arinltte)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .tint(client.appTheme.accentColor)
                Text("cjshen00@gmail.com")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(14)
    }

    // MARK: - Update Check

    private func checkForUpdates() {
        if let url = updateURL {
            NSWorkspace.shared.open(URL(string: url)!)
            return
        }
        updateStatus = "Checking…"
        Task {
            do {
                let reqURL = URL(string: "https://github.com/arinltte/luce/releases/latest")!
                var request = URLRequest(url: reqURL)
                request.httpMethod = "HEAD"
                let (_, response) = try await URLSession.shared.data(for: request)
                let tag = (response.url?.lastPathComponent ?? "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "v"))

                let current = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0"
                let isNewer = tag.compare(current, options: .numeric) == .orderedDescending

                if !tag.isEmpty && isNewer {
                    updateStatus = "New Version (v\(tag))"
                    updateURL = "https://github.com/arinltte/luce/releases/latest"
                } else {
                    updateStatus = "Up to Date"
                }
            } catch {
                updateStatus = "Check for Updates"
            }
        }
    }

    // ================================================================
    // MARK: - Bottom Bar
    // ================================================================

    private var bottomBar: some View {
        HStack {
            if showAbout {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { showAbout = false }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            if !showAbout {
                Button("Exit") { NSApplication.shared.terminate(nil) }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        // Hard-locked height so the footer never expands vertically
        .frame(height: 28)
    }

    // ================================================================
    // MARK: - Reusable Components
    // ================================================================

    private func warningBanner(icon: String, color: Color, message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .padding(.top, 1) // Optical alignment with text
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(color)
                .lineLimit(nil) // Allows the text to expand instead of clipping
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(color.opacity(0.08))
        .cornerRadius(6)
    }
}
