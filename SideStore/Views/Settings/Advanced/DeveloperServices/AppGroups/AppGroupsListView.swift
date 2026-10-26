//
//  AppGroupsListView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppGroupsListView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var newGroupName = ""
    @State private var newGroupIdentifier = "group."

    @State private var groupToEdit: ALTAppGroup? = nil
    @State private var editGroupName = ""
    @State private var showSheetDeleteConfirmation = false

    @State private var groupToDelete: ALTAppGroup? = nil
    @State private var showDeleteConfirmation = false

    private var filteredGroups: [ALTAppGroup] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.appGroups
        }
        return viewModel.appGroups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.groupIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section(header: Text("应用组（\\(viewModel.appGroups.count)）"), footer: Text("应用组支持同一开发者团队内的多个应用和扩展共享数据。点按某个组可编辑其名称或删除它。")) {
                if filteredGroups.isEmpty {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(searchText.isEmpty ? "No App Groups found on Developer Portal." : "No matching App Groups found.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(filteredGroups, id: \.identifier) { group in
                        SwiftUI.Button {
                            editGroupName = group.name
                            groupToEdit = group
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(group.name.isEmpty ? "App Group" : group.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(group.groupIdentifier)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("组编号：\\(group.identifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            SwiftUI.Button(role: .destructive) {
                                groupToDelete = group
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            SwiftUI.Button {
                                editGroupName = group.name
                                groupToEdit = group
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        #endif
                        .contextMenu {
                            SwiftUI.Button {
                                editGroupName = group.name
                                groupToEdit = group
                            } label: {
                                Label("Edit Name", systemImage: "pencil")
                            }
                            #if !os(tvOS)
                            SwiftUI.Button {
                                UIPasteboard.general.string = group.groupIdentifier
                            } label: {
                                Label("Copy Identifier", systemImage: "doc.on.doc")
                            }
                            #endif
                            SwiftUI.Button(role: .destructive) {
                                groupToDelete = group
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search App Groups")
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle("应用组")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    newGroupName = ""
                    newGroupIdentifier = "group."
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.fetchAppGroups(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationView {
                Form {
                    Section(header: Text("应用组详情"), footer: Text("组标识符必须以“group.”前缀开头（例如 group.com.example.shared）。")) {
                        TextField("Name (e.g. Shared Storage)", text: $newGroupName)
                        TextField("Group Identifier", text: $newGroupIdentifier)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .navigationTitle("创建应用组")
                .navigationBarItems(
                    leading: SwiftUI.Button("取消") {
                        showCreateSheet = false
                    },
                    trailing: SwiftUI.Button("创建") {
                        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let groupID = newGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty, !groupID.isEmpty else { return }
                        Task {
                            let success = await viewModel.createAppGroup(name: name, groupIdentifier: groupID, presentingViewController: presentingViewController)
                            if success {
                                showCreateSheet = false
                            }
                        }
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              !newGroupIdentifier.hasPrefix("group.") ||
                              viewModel.isActionLoading)
                )
            }
        }
        .sheet(item: $groupToEdit) { group in
            NavigationView {
                Form {
                    Section(header: Text("说明"), footer: Text("You cannot use special characters such as @, &, *, ', \", -, .")) {
                        TextField("Description", text: $editGroupName)
                    }

                    Section(header: Text("标识符")) {
                        Text(group.groupIdentifier)
                            .foregroundColor(.secondary)
                    }

                    Section {
                        SwiftUI.Button(role: .destructive) {
                            showSheetDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("移除应用组")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("编辑标识符配置")
                .navigationBarItems(
                    leading: SwiftUI.Button("取消") {
                        groupToEdit = nil
                    },
                    trailing: SwiftUI.Button("保存") {
                        let trimmed = editGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            let success = await viewModel.updateAppGroup(group, newName: trimmed, presentingViewController: presentingViewController)
                            if success {
                                groupToEdit = nil
                            }
                        }
                    }
                    .disabled(editGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              editGroupName == group.name ||
                              viewModel.isActionLoading)
                )
                .alert(isPresented: $showSheetDeleteConfirmation) {
                    Alert(
                        title: Text("删除应用组？"),
                        message: Text("确定要从 Apple 开发者门户删除“\\(group.name)”（\\(group.groupIdentifier)）吗？"),
                        primaryButton: .destructive(Text("删除")) {
                            Task {
                                let success = await viewModel.deleteAppGroup(group, presentingViewController: presentingViewController)
                                if success {
                                    groupToEdit = nil
                                }
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("删除应用组？"),
                message: Text("Are you sure you want to delete '\(groupToDelete?.name ?? "this App Group")' (\(groupToDelete?.groupIdentifier ?? "")) from Apple Developer Portal?"),
                primaryButton: .destructive(Text("删除")) {
                    if let target = groupToDelete {
                        Task {
                            _ = await viewModel.deleteAppGroup(target, presentingViewController: presentingViewController)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .developerServicesToast(viewModel: viewModel)
    }
}
