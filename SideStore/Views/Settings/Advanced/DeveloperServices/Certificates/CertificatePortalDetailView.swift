//
//  CertificatePortalDetailView.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct CertificatePortalDetailView: View {
    let certificate: ALTX509Certificate
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?
    @Environment(\.presentationMode) var presentationMode

    @State private var showRevokeAlert = false

    private var isExpired: Bool {
        certificate.expiryDate < Date()
    }

    var body: some View {
        List {
            Section(header: Text("证书详情")) {
                InfoRow(label: "Name", value: certificate.name)
                InfoRow(label: "Serial Number", value: certificate.serialNumber)
                if let identifier = certificate.identifier {
                    InfoRow(label: "Certificate ID", value: identifier)
                }
                if let certType = certificate.certificateType {
                    InfoRow(label: "Certificate Type", value: certType)
                }
                if let typeName = certificate.certificateTypeName {
                    InfoRow(label: "Type Name", value: typeName)
                }
                if let managed = certificate.isManaged {
                    InfoRow(label: "Managed", value: managed ? "Yes (Xcode Cloud)" : "No")
                }
                if let platform = certificate.platform {
                    InfoRow(label: "Platform", value: platform)
                }
                if let machineName = certificate.machineName {
                    InfoRow(label: "Machine Name", value: machineName)
                }
                if let machineIdentifier = certificate.machineIdentifier {
                    InfoRow(label: "Machine Identifier", value: machineIdentifier)
                }
                if let createdBy = certificate.requesterFirstName {
                    InfoRow(label: "Created By", value: createdBy)
                }
                if let email = certificate.requesterEmail {
                    InfoRow(label: "Requester Email", value: email)
                }
                if let teamName = viewModel.team?.name {
                    InfoRow(label: "Team Name", value: teamName)
                }
                if let teamID = viewModel.team?.identifier {
                    InfoRow(label: "Team Identifier", value: teamID)
                }
                InfoRow(label: "Created Date", value: formatDate(certificate.creationDate))
                InfoRow(label: "Expiration Date", value: formatDate(certificate.expiryDate), valueColor: isExpired ? .red : .primary)
                InfoRow(label: "Status", value: isExpired ? "Expired" : "Active", valueColor: isExpired ? .red : .green)
            }

            Section(footer: Text("吊销证书将永久使其在 Apple 服务器上失效。仅与此证书关联的描述文件可能需要重新生成。")) {
                SwiftUI.Button(role: .destructive) {
                    showRevokeAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("在门户上吊销证书")
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
        .navigationTitle(certificate.name)
        .refreshable {
            await viewModel.fetchCertificates(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .alert(isPresented: $showRevokeAlert) {
            Alert(
                title: Text("吊销证书？"),
                message: Text("确定要在 Apple 开发者门户上吊销“\\(certificate.name)”吗？此操作无法撤销。"),
                primaryButton: .destructive(Text("吊销")) {
                    Task {
                        let success = await viewModel.revokeCertificate(certificate, presentingViewController: presentingViewController)
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
