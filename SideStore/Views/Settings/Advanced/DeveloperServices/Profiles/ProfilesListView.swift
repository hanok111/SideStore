//
//  ProfilesListView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct ProfilesListView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var searchText = ""
    @State private var showCreateProfileSheet = false

    @State private var profileToDelete: ALTListedProvisioningProfile? = nil
    @State private var showDeleteConfirmation = false
    @State private var showPurgeAllConfirmation = false

    private var filteredProfiles: [ALTListedProvisioningProfile] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.profiles
        }
        return viewModel.profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) == true) ||
            $0.uuid.uuidString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section(header: Text("描述文件（\\(viewModel.profiles.count)）"), footer: Text("删除开发者门户上的描述文件后，Apple 可签发带有更新证书和未标记 UUID 的新描述文件。")) {
                if filteredProfiles.isEmpty {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(searchText.isEmpty ? "No Provisioning Profiles found on Developer Portal." : "No matching Provisioning Profiles found.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(filteredProfiles, id: \.uuid) { profile in
                        NavigationLink(destination: ProfilePortalDetailView(profile: profile, viewModel: viewModel, presentingViewController: presentingViewController)) {
                            ProfileRow(profile: profile, formatDate: formatDate)
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            SwiftUI.Button(role: .destructive) {
                                profileToDelete = profile
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        #endif
                        .contextMenu {
                            SwiftUI.Button(role: .destructive) {
                                profileToDelete = profile
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !viewModel.profiles.isEmpty {
                Section {
                    SwiftUI.Button(role: .destructive) {
                        showPurgeAllConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("删除门户上的全部描述文件")
                                .fontWeight(.semibold)
                            Spacer()
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
        .navigationTitle("描述文件")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    showCreateProfileSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.fetchProfiles(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .sheet(isPresented: $showCreateProfileSheet) {
            CreateManualProfileView(viewModel: viewModel, presentingViewController: presentingViewController)
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("删除描述文件？"),
                message: Text("Are you sure you want to delete '\(profileToDelete?.name ?? "this profile")' from the Apple Developer Portal?"),
                primaryButton: .destructive(Text("删除")) {
                    if let target = profileToDelete {
                        Task {
                            _ = await viewModel.deleteProfile(target, presentingViewController: presentingViewController)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Purge All Profiles?", isPresented: $showPurgeAllConfirmation) {
            SwiftUI.Button("全部删除（\\(viewModel.profiles.count)）", role: .destructive) {
                Task {
                    _ = await viewModel.deleteAllProfiles(presentingViewController: presentingViewController)
                }
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(viewModel.profiles.count) provisioning profile(s) for team '\(viewModel.team?.name ?? "")' on Apple's developer portal. SideStore will automatically generate fresh profiles on next app install or refresh.")
        }
        .developerServicesToast(viewModel: viewModel)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct ProfileRow: View {
    let profile: ALTListedProvisioningProfile
    let formatDate: (Date) -> String

    private var isExpired: Bool {
        profile.dateExpire < Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                Spacer()
                if isExpired {
                    Text("已过期")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                }
                Text("过期时间：\\(formatDate(profile.dateExpire))")
                    .font(.caption)
                    .foregroundColor(isExpired ? .red : .secondary)
            }

            HStack {
                if let bundleID = profile.bundleIdentifier {
                    Text(bundleID)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let type = profile.profileType {
                    Text(type.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                }
                if let isTeam = profile.isTeamProfile {
                    Text(isTeam ? "Xcode Managed" : "Manual")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isTeam ? Color.blue.opacity(0.12) : Color.purple.opacity(0.12))
                        .foregroundColor(isTeam ? .blue : .purple)
                        .cornerRadius(6)
                }
            }

            Text(profile.uuid.uuidString)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.vertical, 2)
    }
}
