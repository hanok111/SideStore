//
//  ProfilePortalDetailView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct ProfilePortalDetailView: View {
    let profile: ALTListedProvisioningProfile
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?
    @Environment(\.presentationMode) var presentationMode

    @State private var editedName: String = ""
    @State private var selectedAppIDId: String = ""
    @State private var selectedCertificateIDs: Set<String> = []
    @State private var selectedDeviceIDs: Set<String> = []

    @State private var customCertInput: String = ""
    @State private var customDeviceInput: String = ""

    @State private var showDeleteAlert = false
    @State private var exportProfileURL: URL? = nil

    private var isExpired: Bool {
        profile.dateExpire < Date()
    }

    private var hasChanges: Bool {
        let nameChanged = !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && editedName != profile.name
        let originalAppID = profile.appId?.appIdId ?? profile.appId?.identifier ?? ""
        let appIDChanged = !selectedAppIDId.isEmpty && selectedAppIDId != originalAppID
        let originalDevices = Set(profile.deviceIds ?? [])
        let devicesChanged = selectedDeviceIDs != originalDevices
        return nameChanged || appIDChanged || devicesChanged
    }

    private var canSave: Bool {
        !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedAppIDId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedCertificateIDs.isEmpty &&
        !selectedDeviceIDs.isEmpty &&
        !viewModel.isActionLoading
    }

    var body: some View {
        List {
            Section(header: Text("描述文件信息"), footer: Text("你可以编辑描述文件名称，并用更新的证书或设备关联重新生成描述文件。")) {
                HStack {
                    Text("名称")
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    TextField("Profile Name", text: $editedName)
                }

                InfoRow(label: "UUID", value: profile.uuid.uuidString)
                if let identifier = profile.identifier {
                    InfoRow(label: "Identifier", value: identifier)
                }
                if let profType = profile.profileType {
                    InfoRow(label: "Type", value: profType.displayName)
                } else if let rawType = profile.type {
                    InfoRow(label: "Type", value: rawType)
                }
                if let isTeam = profile.isTeamProfile {
                    InfoRow(label: "Managed By", value: isTeam ? "Xcode (Team Profile)" : "Manual (Portal)")
                }
                InfoRow(label: "Status", value: isExpired ? "Expired" : (profile.status ?? "Active"), valueColor: isExpired ? .red : .primary)
                InfoRow(label: "Expiration Date", value: formatDate(profile.dateExpire), valueColor: isExpired ? .red : .primary)
            }

            Section(header: Text("App ID 关联"), footer: Text("从团队已注册的 App ID 中选择，或指定自定义 App ID / 标识符。")) {
                if !viewModel.appIDs.isEmpty {
                    Picker("Team App ID", selection: $selectedAppIDId) {
                        Text("选择 App ID").tag("")
                        ForEach(viewModel.appIDs, id: \.identifier) { appID in
                            Text("\\(appID.name)（\\(appID.bundleIdentifier)）").tag(appID.identifier)
                        }
                    }
                }

                HStack {
                    Text("App ID 编号")
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    TextField("App ID Identifier (e.g. R7V954WR9W)", text: $selectedAppIDId)
                        .font(.system(.subheadline, design: .monospaced))
                }
            }

            Section(header: Text("关联证书（\\(selectedCertificateIDs.count)）"), footer: Text("选择获准使用此描述文件签名的证书，或添加自定义证书编号。")) {
                if viewModel.certificates.isEmpty {
                    Text("此团队下没有证书。")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.certificates, id: \.serialNumber) { cert in
                        let certID = cert.identifier ?? cert.serialNumber
                        SwiftUI.Button {
                            if selectedCertificateIDs.contains(certID) {
                                selectedCertificateIDs.remove(certID)
                            } else {
                                selectedCertificateIDs.insert(certID)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.commonName ?? cert.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text("序列号：\\(cert.serialNumber)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    let hasKey = ProfileManager.shared.hasPrivateKey(for: cert)
                                    HStack(spacing: 4) {
                                        Text("Type: \(hasKey ? "public + private" : "public only")")
                                            .font(.caption2)
                                            .foregroundColor(hasKey ? .green : .secondary)
                                        if hasKey {
                                            Image(systemName: "key.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                Spacer()
                                if selectedCertificateIDs.contains(certID) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Add Custom Certificate ID", text: $customCertInput)
                        .font(.system(.subheadline, design: .monospaced))
                    SwiftUI.Button("添加") {
                        let trimmed = customCertInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            selectedCertificateIDs.insert(trimmed)
                            customCertInput = ""
                        }
                    }
                    .disabled(customCertInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(header: HStack {
                Text("关联设备（\\(selectedDeviceIDs.count)）")
                Spacer()
                if !viewModel.devices.isEmpty {
                    SwiftUI.Button(selectedDeviceIDs.count >= viewModel.devices.count ? "Deselect All" : "Select All") {
                        if selectedDeviceIDs.count >= viewModel.devices.count {
                            selectedDeviceIDs.removeAll()
                        } else {
                            selectedDeviceIDs = Set(viewModel.devices.compactMap { $0.deviceID ?? $0.identifier })
                        }
                    }
                    .font(.caption)
                }
            }, footer: Text("选择允许运行使用此描述文件签名的应用的设备，或输入自定义设备编号 / UDID。")) {
                if viewModel.devices.isEmpty {
                    Text("此团队下未找到已注册设备。")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.devices, id: \.identifier) { device in
                        let devID = device.deviceID ?? device.identifier
                        let isSelected = selectedDeviceIDs.contains(devID) || selectedDeviceIDs.contains(device.identifier)
                        SwiftUI.Button {
                            if isSelected {
                                selectedDeviceIDs.remove(devID)
                                selectedDeviceIDs.remove(device.identifier)
                            } else {
                                selectedDeviceIDs.insert(devID)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(device.identifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Add Custom Device ID / UDID", text: $customDeviceInput)
                        .font(.system(.subheadline, design: .monospaced))
                    SwiftUI.Button("添加") {
                        let trimmed = customDeviceInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            selectedDeviceIDs.insert(trimmed)
                            customDeviceInput = ""
                        }
                    }
                    .disabled(customDeviceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if hasChanges {
                Section {
                    SwiftUI.Button {
                        Task {
                            let success = await viewModel.updateProfile(
                                profile,
                                name: editedName.trimmingCharacters(in: .whitespacesAndNewlines),
                                appIDId: selectedAppIDId.trimmingCharacters(in: .whitespacesAndNewlines),
                                certificateIDs: Array(selectedCertificateIDs),
                                deviceIDs: Array(selectedDeviceIDs),
                                type: profile.profileType,
                                presentingViewController: presentingViewController
                            )
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isActionLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("保存更改（重新生成描述文件）")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }

            Section {
                SwiftUI.Button {
                    Task {
                        guard let downloaded = await viewModel.downloadProfile(profile: profile) else { return }
                        let safeName = profile.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).mobileprovision")
                        do {
                            try downloaded.data.write(to: tempURL)
                            exportProfileURL = tempURL
                        } catch {
                            debugLog("[ProfilePortalDetailView] Failed to write profile to temp: \(error)")
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isActionLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.down.doc")
                            Text("下载描述文件（.mobileprovision）")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isActionLoading)
            }

            Section {
                SwiftUI.Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("从门户删除描述文件")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(profile.name)
        .refreshable {
            await viewModel.fetchProfiles(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .onAppear {
            if editedName.isEmpty {
                editedName = profile.name
            }
            if selectedAppIDId.isEmpty {
                selectedAppIDId = profile.appId?.appIdId ?? profile.appId?.identifier ?? ""
            }
            if selectedDeviceIDs.isEmpty, let devIDs = profile.deviceIds {
                selectedDeviceIDs = Set(devIDs)
            }
            if selectedCertificateIDs.isEmpty {
                selectedCertificateIDs = Set(viewModel.certificates.compactMap { $0.identifier ?? $0.serialNumber })
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("删除描述文件？"),
                message: Text("确定要从 Apple 开发者门户删除“\\(profile.name)”吗？"),
                primaryButton: .destructive(Text("删除")) {
                    Task {
                        let success = await viewModel.deleteProfile(profile, presentingViewController: presentingViewController)
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .developerServicesToast(viewModel: viewModel)
        .sheet(isPresented: Binding<Bool>(
            get: { exportProfileURL != nil },
            set: { if !$0 { exportProfileURL = nil } }
        )) {
            if let url = exportProfileURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
