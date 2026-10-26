//
//  ProfileManagementView.swift
//  SideStore
//
//  Created by Magesh K on 14/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign
import UniformTypeIdentifiers

struct PendingProfileImport: Identifiable {
    let id = UUID()
    let profile: ALTProvisioningProfile
    let analysis: ProfileManager.CertificateAnalysisResult
}

struct ProfileManagementView: View {
    weak var presentingViewController: UIViewController?

    @StateObject private var viewModel = ProfileManagementViewModel()
    @StateObject private var certificatesViewModel = CertificatesViewModel()
    @StateObject private var devServicesViewModel = DeveloperServicesViewModel()

    @State private var searchText = ""
    @State private var showFileImporter = false
    @State private var profileToDelete: ALTProvisioningProfile? = nil
    @State private var showDeleteConfirmation = false
    @State private var showPortalDeleteConfirmation = false
    @State private var profileToShareURL: URL? = nil
    @State private var pendingImport: PendingProfileImport? = nil
    @State private var profileToEditOnPortal: ALTListedProvisioningProfile? = nil
    @State private var showAddOptions = false
    @State private var navigateToPortalProfiles = false

    private var allowedImportTypes: [UTType] {
        [UTType(filenameExtension: "mobileprovision")].compactMap { $0 }
    }

    private var filteredProfiles: [ALTProvisioningProfile] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.profiles
        }
        return viewModel.profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.teamName.localizedCaseInsensitiveContains(searchText) ||
            $0.uuid.uuidString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            List {
                Section(header: Text("概览")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("总计")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\\(viewModel.profiles.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("就绪")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\\(viewModel.readyCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("门户")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\\(viewModel.portalCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("缺少证书")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\\(viewModel.profiles.count - viewModel.readyCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(viewModel.profiles.count - viewModel.readyCount > 0 ? .orange : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(
                    header: Text("描述文件（\\(filteredProfiles.count)）"),
                    footer: Text("描述文件决定权限、设备许可和过期日期。描述文件会与你的开发者账号自动同步。")
                ) {
                    if filteredProfiles.isEmpty {
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            Text(searchText.isEmpty ? "No provisioning profiles installed. Tap '+' to import or pull to refresh." : "No matching provisioning profiles found.")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    } else {
                        ForEach(filteredProfiles, id: \.uuid) { profile in
                            NavigationLink(destination: ProvisioningProfileDetailView(profile: profile, profileURL: ProfileManager.shared.profileURL(for: profile.uuid), certificatesViewModel: certificatesViewModel)) {
                                ProfileManagementRowView(profile: profile, isRemote: viewModel.isRemoteProfile(profile), formatDate: formatDate)
                            }
                            #if !os(tvOS)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                SwiftUI.Button(role: .destructive) {
                                    promptDelete(profile)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                if viewModel.canEditProfileOnPortal(profile) {
                                    SwiftUI.Button {
                                        if let listed = viewModel.listedProfile(for: profile.uuid) {
                                            profileToEditOnPortal = listed
                                        }
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.purple)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                SwiftUI.Button {
                                    shareProfile(profile)
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                            #endif
                            .contextMenu {
                                if viewModel.canEditProfileOnPortal(profile) {
                                    SwiftUI.Button {
                                        if let listed = viewModel.listedProfile(for: profile.uuid) {
                                            profileToEditOnPortal = listed
                                        }
                                    } label: {
                                        Label("Edit on Developer Portal", systemImage: "pencil")
                                    }
                                }
                                SwiftUI.Button {
                                    shareProfile(profile)
                                } label: {
                                    Label("Share Profile", systemImage: "square.and.arrow.up")
                                }
                                SwiftUI.Button(role: .destructive) {
                                    promptDelete(profile)
                                } label: {
                                    Label("Delete Profile", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            #if !os(tvOS)
            .listStyle(InsetGroupedListStyle())
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Profiles")
            #else
            .listStyle(GroupedListStyle())
            #endif

            if let message = viewModel.toastMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(20)
                        .shadow(radius: 6)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: viewModel.toastMessage)
            }
        }
        .navigationTitle("Profile Management")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    showAddOptions = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Provisioning Profile")
            }
        }
        .onAppear {
            viewModel.loadProfiles(isPullToRefresh: false)
        }
        .refreshable {
            viewModel.loadProfiles(isPullToRefresh: true)
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                handleFileSelected(at: url)
            case .failure(let error):
                viewModel.showToast("Import canceled: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { profileToShareURL != nil },
            set: { if !$0 { profileToShareURL = nil } }
        )) {
            if let url = profileToShareURL {
                ActivityViewController(activityItems: [url])
            }
        }
        #endif
        .sheet(item: $profileToEditOnPortal) { listed in
            NavigationView {
                ProfilePortalDetailView(profile: listed, viewModel: devServicesViewModel, presentingViewController: presentingViewController)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            SwiftUI.Button("完成") {
                                profileToEditOnPortal = nil
                                viewModel.loadProfiles(isPullToRefresh: true)
                            }
                        }
                    }
            }
        }
        .alert(item: $pendingImport) { pending in
            switch pending.analysis {
            case .signable(let certName, _):
                return Alert(
                    title: Text("关联签名证书？"),
                    message: Text("在 SideStore 中找到与私钥匹配的签名证书“\\(certName)”。\\n\\n是否关联并保存此描述文件？"),
                    primaryButton: .default(Text("关联并保存")) {
                        commitImport(pending.profile)
                    },
                    secondaryButton: .cancel()
                )
            case .publicOnly(let certName, _):
                return Alert(
                    title: Text("缺少私钥"),
                    message: Text("在此描述文件中找到证书“\\(certName)”，但 SideStore 中未找到匹配的私钥（.p12）。\\n\\n继续意味着在导入带私钥的匹配签名证书之前，此描述文件将无法用于签名应用。"),
                    primaryButton: .destructive(Text("仍要导入")) {
                        commitImport(pending.profile)
                    },
                    secondaryButton: .cancel()
                )
            case .noMatch(let count):
                return Alert(
                    title: Text("没有匹配的签名证书"),
                    message: Text("此描述文件包含 \\(count) 个开发者证书，但没有一个与 SideStore 中的签名证书匹配。\\n\\n继续意味着在导入带私钥的匹配签名证书之前，此描述文件将无法用于签名应用。"),
                    primaryButton: .destructive(Text("仍要导入")) {
                        commitImport(pending.profile)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("删除本地描述文件？"),
                message: Text("Are you sure you want to delete '\(profileToDelete?.name ?? "this profile")' from local storage? Any apps assigned to this profile will revert to default."),
                primaryButton: .destructive(Text("删除")) {
                    if let target = profileToDelete {
                        Task {
                            await viewModel.deleteProfile(target, alsoDeleteFromPortal: false)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Delete Portal Profile?", isPresented: $showPortalDeleteConfirmation) {
            SwiftUI.Button("Delete from Portal & Locally", role: .destructive) {
                if let target = profileToDelete {
                    Task {
                        await viewModel.deleteProfile(target, alsoDeleteFromPortal: true)
                    }
                }
            }
            SwiftUI.Button("Delete Locally Only") {
                if let target = profileToDelete {
                    Task {
                        await viewModel.deleteProfile(target, alsoDeleteFromPortal: false)
                    }
                }
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("'\((profileToDelete?.name ?? "This profile"))' exists on the Apple Developer Portal. Do you want to delete it from Apple's servers as well, or only delete the local cache?")
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            SwiftUI.Button("好", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .confirmationDialog("Add Provisioning Profile", isPresented: $showAddOptions, titleVisibility: .visible) {
            SwiftUI.Button("Import from Files") {
                importProfileAction()
            }
            SwiftUI.Button("Create on Developer Portal") {
                Task {
                    await devServicesViewModel.loadAll(presentingViewController: presentingViewController)
                }
                navigateToPortalProfiles = true
            }
            SwiftUI.Button("取消", role: .cancel) {}
        }
        .onChange(of: navigateToPortalProfiles) { isActive in
            if !isActive {
                viewModel.loadProfiles(isPullToRefresh: true)
            }
        }
        .background(
            NavigationLink(
                destination: ProfilesListView(viewModel: devServicesViewModel, presentingViewController: presentingViewController),
                isActive: $navigateToPortalProfiles
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    private func handleFileSelected(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let profile = try ALTProvisioningProfile(data: data)
            let analysis = ProfileManager.shared.analyzeCertificates(for: profile)
            self.pendingImport = PendingProfileImport(profile: profile, analysis: analysis)
        } catch {
            viewModel.showToast("Invalid provisioning profile: \(error.localizedDescription)")
        }
    }

    private func commitImport(_ profile: ALTProvisioningProfile) {
        do {
            _ = try ProfileManager.shared.importProfile(data: profile.data)
            viewModel.loadProfiles(isPullToRefresh: false)
            viewModel.showToast("Imported '\(profile.name)' successfully")
        } catch {
            viewModel.showToast("Failed to import profile: \(error.localizedDescription)")
        }
    }

    private func promptDelete(_ profile: ALTProvisioningProfile) {
        profileToDelete = profile
        if viewModel.isRemoteProfile(profile) {
            showPortalDeleteConfirmation = true
        } else {
            showDeleteConfirmation = true
        }
    }

    private func importProfileAction() {
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["mobileprovision"],
            title: "Import Provisioning Profile",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            handleFileSelected(at: fileURL)
        }
        #endif
    }

    private func shareProfile(_ profile: ALTProvisioningProfile) {
        let fileURL = ProfileManager.shared.profileURL(for: profile.uuid)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        #if !os(tvOS)
        profileToShareURL = fileURL
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startExport(
            fileURL: fileURL,
            title: "Export Provisioning Profile",
            presentingVC: topVC,
            completion: nil
        )
        #endif
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct ProfileManagementRowView: View {
    let profile: ALTProvisioningProfile
    let isRemote: Bool
    let formatDate: (Date) -> String

    private var isExpired: Bool {
        profile.expirationDate < Date()
    }

    private var matchingCert: ALTCertificate? {
        ProfileManager.shared.getMatchingCertificate(for: profile)
    }

    private var assignedApps: [String] {
        ProfileManager.shared.getAppsUsingProfile(uuid: profile.uuid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                Spacer()
                if isRemote {
                    HStack(spacing: 3) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 8))
                        Text("门户")
                            .fontWeight(.medium)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 8))
                        Text("本地")
                            .fontWeight(.medium)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.secondary)
                    .cornerRadius(6)
                }

                if isExpired {
                    Text("已过期")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                } else if matchingCert != nil {
                    Text("就绪")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                } else {
                    Text("无密钥")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }
                Text("过期时间：\\(formatDate(profile.expirationDate))")
                    .font(.caption)
                    .foregroundColor(isExpired ? .red : .secondary)
            }

            HStack {
                Text(profile.bundleIdentifier)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(profile.teamName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let cert = matchingCert {
                HStack(spacing: 4) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("Signer: \(cert.name)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if !assignedApps.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text("Assigned: \(assignedApps.joined(separator: ", "))")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
