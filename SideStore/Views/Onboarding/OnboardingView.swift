//
//  OnboardingView.swift
//  SideStore
//
//  Created by SternXD on 9/13/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Minimuxer
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    var onFinish: (() -> Void)? = nil
    @State private var currentStep = 0
    private let totalSteps = 5

    var body: some View {
        ZStack {
            #if !os(tvOS)
                Color(.systemBackground).ignoresSafeArea()
            #else
                Color.black.ignoresSafeArea()
            #endif

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                TabView(selection: $currentStep) {
                    WelcomeStep(onNext: { currentStep += 1 })
                        .tag(0)

                    PairingFileStep(onNext: { currentStep += 1 })
                        .tag(1)

                    LocalDevVPNStep(onNext: { currentStep += 1 })
                        .tag(2)

                    AppleIDStep(onNext: { currentStep += 1 })
                        .tag(3)

                    CompleteStep(onFinish: complete)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentStep)
                #if !os(tvOS)
                    .highPriorityGesture(
                        DragGesture().onEnded { value in
                            if value.translation.width > 50, currentStep > 0, currentStep < totalSteps - 1 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentStep -= 1
                                }
                            }
                        }
                    )
                #endif
            }
        }
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(0 ..< totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.accentColor : Color.primary.opacity(0.18))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            if currentStep > 0 && currentStep < totalSteps - 1 {
                HStack {
                    SwiftUI.Button(action: { currentStep -= 1 }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 44)
    }

    private func complete() {
        UserDefaults.standard.hasCompletedOnboarding = true
        UserDefaults.standard.synchronize()
        onFinish?()
    }
}

private struct WelcomeStep: View {
    let onNext: () -> Void
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") ?? UIImage(systemName: "app.fill")!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .scaleEffect(isBreathing ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isBreathing)
                .onAppear { isBreathing = true }

            VStack(spacing: 8) {
                Text(NSLocalizedString("欢迎使用 SideStore", comment: ""))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("直接在设备上侧载和刷新应用，无需连接电脑。", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 18) {
                featureRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue,
                    title: NSLocalizedString("设备端侧载", comment: ""),
                    description: NSLocalizedString("使用设备端本地回环 VPN 隧道安装和刷新应用。", comment: "")
                )

                featureRow(
                    icon: "doc.badge.gearshape",
                    color: .orange,
                    title: NSLocalizedString("设备配对", comment: ""),
                    description: String(
                        format: NSLocalizedString("一次性配对文件可将 SideStore 连接到 %@ 的设备服务。", comment: ""),
                        ProcessInfo.processInfo.platformName
                    )
                )

                featureRow(
                    icon: "person.crop.circle.badge.checkmark",
                    color: .green,
                    title: NSLocalizedString("个人签名", comment: ""),
                    description: NSLocalizedString("使用你自己的 Apple ID，以标准开发证书签名应用。", comment: "")
                )
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer()

            SwiftUI.Button(action: onNext) {
                Text(NSLocalizedString("开始使用", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(14)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct PairingFileStep: View {
    let onNext: () -> Void
    @State private var hasPairingFile = PairingFileManager.shared.hasPairingFile()
    @State private var isShowingFilePicker = false
    @State private var errorMessage: String? = nil

    private let contentTypes: [UTType] = PairingFileManager.supportedContentTypes

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: hasPairingFile ? "checkmark.seal.fill" : "doc.badge.gearshape.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(hasPairingFile ? .green : .accentColor)
                .animation(.easeInOut, value: hasPairingFile)

            VStack(spacing: 8) {
                Text(NSLocalizedString("配对文件", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(String(
                    format: NSLocalizedString("SideStore 使用由你的电脑生成的配对文件（.mobiledevicepairing 或 .plist）与 %@ 的设备服务通信。", comment: ""),
                    ProcessInfo.processInfo.platformName
                ))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            if hasPairingFile {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("已检测并加载配对文件。", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            VStack(spacing: 12) {
                #if !os(tvOS)
                    SwiftUI.Button(action: { isShowingFilePicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                            Text(hasPairingFile
                                ? NSLocalizedString("选择其他文件", comment: "")
                                : NSLocalizedString("选择配对文件", comment: ""))
                        }
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    SwiftUI.Button(action: {
                        UIApplication.shared.open(AppConstants.URLs.pairingDocumentation)
                    }) {
                        Text(NSLocalizedString("如何获取配对文件？", comment: ""))
                            .font(.footnote)
                            .foregroundColor(.accentColor)
                    }
                #endif

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("继续", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(hasPairingFile ? Color.accentColor : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                }
                .disabled(!hasPairingFile)

                if !hasPairingFile {
                    SwiftUI.Button(action: onNext) {
                        Text(NSLocalizedString("稍后设置", comment: ""))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                do {
                    try PairingFileManager.shared.importPairingFile(from: url)
                    hasPairingFile = true
                    errorMessage = nil
                    onNext()
                } catch {
                    errorMessage = error.localizedDescription
                }
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        #endif
    }
}

private struct LocalDevVPNStep: View {
    let onNext: () -> Void
    @State private var isConnected = false
    @State private var errorMessage: String? = nil

    private let vpnSchemeURL = URL(string: "localdevvpn://")!
    private let vpnConnectURL = URL(string: "localdevvpn://enable?scheme=sidestore")!
    private let appStoreURL = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!

    private var isInstalled: Bool {
        UIApplication.shared.canOpenURL(vpnSchemeURL)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                if let uiImage = UIImage(named: "LocalDevVPN") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    Image(systemName: "network")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.accentColor)
                }

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    #if !os(tvOS)
                        .background(Circle().fill(Color(.systemBackground)))
                    #else
                        .background(Circle().fill(Color.black))
                    #endif
                        .offset(x: 4, y: 4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: isConnected)

            VStack(spacing: 8) {
                Text(NSLocalizedString("LocalDevVPN", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(NSLocalizedString("SideStore 通过本地回环 VPN 与设备端服务通信。验证前请启用 LocalDevVPN。", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("LocalDevVPN 已连接。", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            VStack(spacing: 12) {
                if !isConnected {
                    SwiftUI.Button(action: verifyVPN) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.horizontal.fill")
                            Text(NSLocalizedString("验证 VPN", comment: ""))
                        }
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }

                if let errorMessage {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)

                        if !isInstalled {
                            SwiftUI.Button(action: {
                                UIApplication.shared.open(appStoreURL)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.app")
                                    Text(NSLocalizedString("在 App Store 获取 LocalDevVPN", comment: ""))
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("继续", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isConnected ? Color.accentColor : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                }
                .disabled(!isConnected)

                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("稍后设置", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear {
            checkStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkStatus()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkStatus()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                checkStatus()
            }
        }
    }

    private func checkStatus() {
        let interfaces = Minimuxer.shared.network.activeInterfaces
        let hasVpnTunnel = interfaces.contains { info in
            info.name.lowercased().hasPrefix("utun") && info.ip.hasPrefix("10.7.")
        }

        if hasVpnTunnel {
            isConnected = true
            errorMessage = nil
            return
        }

        let targetIp = ConnectionConfig.shared.tunnelPeerIp ?? "10.7.0.1"
        if !targetIp.isEmpty, Minimuxer.shared.core.testDeviceConnection(ifaddr: targetIp, timeout: 200) {
            isConnected = true
            errorMessage = nil
        } else {
            isConnected = false
            if isInstalled, errorMessage == NSLocalizedString("此设备未安装 LocalDevVPN。", comment: "") {
                errorMessage = nil
            }
        }
    }

    private func verifyVPN() {
        checkStatus()
        if isConnected {
            errorMessage = nil
            return
        }

        if isInstalled {
            errorMessage = nil
            UIApplication.shared.open(vpnConnectURL, options: [:]) { success in
                if !success {
                    errorMessage = NSLocalizedString("此设备未安装 LocalDevVPN。", comment: "")
                }
            }
        } else {
            UIApplication.shared.open(vpnConnectURL, options: [:]) { success in
                if !success {
                    errorMessage = NSLocalizedString("此设备未安装 LocalDevVPN。", comment: "")
                }
            }
        }
    }
}

private struct AppleIDStep: View {
    let onNext: () -> Void
    @State private var isAuthenticated = AuthManager.shared.isAuthenticated
    @State private var isSigningIn = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(isAuthenticated ? .green : .accentColor)
                .animation(.easeInOut, value: isAuthenticated)

            VStack(spacing: 8) {
                Text(NSLocalizedString("Apple ID", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(NSLocalizedString("SideStore 需要一个 Apple ID 来创建用于签名应用的开发证书和描述文件。", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if isAuthenticated {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(AuthManager.shared.currentAppleID ?? NSLocalizedString("已登录", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                SwiftUI.Button(action: {
                    Task {
                        isSigningIn = true
                        errorMessage = nil
                        defer { isSigningIn = false }

                        do {
                            _ = try await AuthManager.shared.signIn(
                                presentingViewController: UIApplication.shared.topViewController(),
                                skipResign: true,
                                skipHowTos: true
                            )
                            isAuthenticated = true
                            onNext()
                        } catch {
                            if !(error is CancellationError) {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "key.fill")
                        }
                        Text(NSLocalizedString("使用 Apple ID 登录", comment: ""))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .disabled(isSigningIn)
                .frame(maxWidth: 420)
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("继续", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isAuthenticated ? Color.accentColor : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                }
                .disabled(!isAuthenticated && !isSigningIn)

                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("稍后设置", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .disabled(isSigningIn)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct CompleteStep: View {
    let onFinish: () -> Void

    private var hasPairingFile: Bool {
        PairingFileManager.shared.hasPairingFile()
    }

    private var isAuthenticated: Bool {
        AuthManager.shared.isAuthenticated
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: hasPairingFile ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(hasPairingFile ? .green : .orange)

            VStack(spacing: 8) {
                Text(hasPairingFile
                    ? NSLocalizedString("全部就绪！", comment: "")
                    : NSLocalizedString("设置未完成", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(hasPairingFile
                    ? NSLocalizedString("SideStore 设置已完成，现在可以安装和刷新应用了。", comment: "")
                    : NSLocalizedString("你可以进入 SideStore，但在安装或刷新应用之前需要配对文件。", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                summaryRow(
                    title: NSLocalizedString("配对文件", comment: ""),
                    isConfigured: hasPairingFile,
                    warning: NSLocalizedString("安装或刷新应用前必需", comment: "")
                )

                Divider()

                summaryRow(
                    title: NSLocalizedString("Apple ID", comment: ""),
                    isConfigured: isAuthenticated,
                    warning: NSLocalizedString("随时可在设置中添加", comment: "")
                )
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)

            Spacer()

            SwiftUI.Button(action: onFinish) {
                Text(NSLocalizedString("打开 SideStore", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(14)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func summaryRow(title: String, isConfigured: Bool, warning: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isConfigured ? .green : .orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if isConfigured {
                    Text(NSLocalizedString("已配置", comment: ""))
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text(NSLocalizedString("未配置", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    Text(warning)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
