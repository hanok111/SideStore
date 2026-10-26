//
//  CertificateDetailView.swift
//  SideStore
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct DeveloperPortalMetadata {
    var identifier: String?
    var machineName: String?
    var machineIdentifier: String?
    var requesterEmail: String?
    var requesterFirstName: String?
    var requesterLastName: String?
    var displayName: String?
    var certificateType: String? = nil
    var certificateTypeName: String? = nil
    var certificateTypeId: String? = nil
    var platform: String? = nil
    var platformName: String? = nil
    var isManaged: Bool? = nil
    var status: String? = nil
    var ownerName: String? = nil
    var ownerId: String? = nil
    var autoRotationEnabled: Bool? = nil
    var requestedDate: String? = nil
    var serialNumDecimal: String? = nil
}

struct CertificateDetailView: View {
    let certificate: ALTX509Certificate
    let portalMetadata: DeveloperPortalMetadata?
    @ObservedObject var viewModel: CertificatesViewModel
    
    private var signableCert: ALTCertificate? {
        viewModel.getSignableCertificate(for: certificate.serialNumber)
    }
    
    init(certificate: ALTX509Certificate, portalMetadata: DeveloperPortalMetadata? = nil, viewModel: CertificatesViewModel) {
        self.certificate = certificate
        self.portalMetadata = portalMetadata
        self.viewModel = viewModel
    }
    
    @State private var isRedacted = true
    
    @State private var showPrivateKey = false
    @State private var copiedPrivateKey = false
    @State private var copiedPEM = false
    @State private var copiedSerialNumber = false
    @State private var copiedIdentifier = false
    @State private var copiedFingerprintSHA1 = false
    @State private var copiedFingerprintSHA256 = false
    
    var body: some View {
        Form {
            Section {
                Section {
                    if let identifier = portalMetadata?.identifier ?? certificate.identifier {
                        detailRowWithCopy(title: "证书编号", value: identifier, isCopied: $copiedIdentifier)
                    }
                    if let certType = portalMetadata?.certificateType ?? certificate.certificateType {
                        detailRow(title: "证书类型", value: certType)
                    }
                    if let typeName = portalMetadata?.certificateTypeName ?? certificate.certificateTypeName {
                        detailRow(title: "类型名称", value: typeName)
                    }
                    if let managed = portalMetadata?.isManaged ?? certificate.isManaged {
                        detailRow(title: "托管", value: managed ? "Yes (Xcode Cloud)" : "No")
                    }
                    if let status = portalMetadata?.status ?? certificate.status {
                        detailRow(title: "状态", value: status)
                    }
                    if let platform = portalMetadata?.platform ?? certificate.platform {
                        detailRow(title: "平台", value: platform)
                    }
                    if let platformName = portalMetadata?.platformName ?? certificate.platformName {
                        detailRow(title: "平台名称", value: platformName)
                    }
                    if let machineID = portalMetadata?.machineIdentifier ?? certificate.machineIdentifier {
                        detailRow(title: "机器 ID", value: machineID)
                    }
                    if let createdBy = portalMetadata?.requesterFirstName ?? certificate.requesterFirstName {
                        detailRow(title: "创建者", value: redactableValue(createdBy))
                    }
                    if let email = portalMetadata?.requesterEmail ?? certificate.requesterEmail {
                        detailRow(title: "请求者邮箱", value: redactableValue(email))
                    }
                    if let ownerName = portalMetadata?.ownerName ?? certificate.ownerName {
                        detailRow(title: "所有者姓名", value: redactableValue(ownerName))
                    }
                    if let ownerId = portalMetadata?.ownerId ?? certificate.ownerId {
                        detailRow(title: "所有者编号", value: redactableValue(ownerId))
                    }
                    if let autoRotation = portalMetadata?.autoRotationEnabled ?? certificate.autoRotationEnabled {
                        detailRow(title: "自动轮换", value: autoRotation ? "Enabled" : "Disabled")
                    }
                } header: {
                    Text("开发者门户信息")
                }
            }
            
            if let certData = certificate.data {
                let details = parseCertificate(derData: certData)
                Section {
                    detailRow(title: "版本", value: details.version)
                    detailRow(title: "主题", value: redactableValue(details.subject))
                    detailRow(title: "签发者", value: details.issuer)
                    detailRow(title: "序列号（十六进制）", value: details.serialHex)
                    detailRow(title: "序列号（十进制）", value: details.serialDec)
                } header: {
                    Text("X.509 字段")
                }
                
                if let from = details.validFrom, let until = details.validUntil {
                    let stats = computeValidityStats(from: from, until: until)
                    Section {
                        detailRow(title: "有效期自", value: formatDate(from))
                        detailRow(title: "有效期至", value: formatDate(until))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("有效期进度")
                                Spacer()
                                Text(String(format: "%.0f%%", stats.progress * 100))
                                    .foregroundColor(.secondary)
                            }
                            ProgressView(value: stats.progress)
                                .tint(.accentColor)
                        }
                        
                        detailRow(title: "有效天数", value: "Total: \(stats.totalDays), Elapsed: \(stats.elapsedDays), Remaining: \(stats.remainingDays)")
                    } header: {
                        Text("有效期")
                    }
                }
                
                Section {
                    detailRow(title: "公钥", value: details.publicKeyType)
                    detailRow(title: "签名算法", value: details.signatureAlgorithm)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("SHA-1 指纹")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            
                            #if !os(tvOS)
                            SwiftUI.Button {
                                UIPasteboard.general.string = details.fingerprintSHA1
                                copiedFingerprintSHA1 = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedFingerprintSHA1 = false
                                }
                            } label: {
                                Image(systemName: copiedFingerprintSHA1 ? "checkmark" : "doc.on.doc")
                                    .font(.footnote)
                                    .foregroundColor(copiedFingerprintSHA1 ? .green : .accentColor)
                            }
                            .buttonStyle(.plain)
                            #endif
                        }
                        Text(details.fingerprintSHA1)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            #if !os(tvOS)
                            .textSelection(.enabled)
                            #endif
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("SHA-256 指纹")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            
                            #if !os(tvOS)
                            SwiftUI.Button {
                                UIPasteboard.general.string = details.fingerprintSHA256
                                copiedFingerprintSHA256 = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedFingerprintSHA256 = false
                                }
                            } label: {
                                Image(systemName: copiedFingerprintSHA256 ? "checkmark" : "doc.on.doc")
                                    .font(.footnote)
                                    .foregroundColor(copiedFingerprintSHA256 ? .green : .accentColor)
                            }
                            .buttonStyle(.plain)
                            #endif
                        }
                        Text(details.fingerprintSHA256)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            #if !os(tvOS)
                            .textSelection(.enabled)
                            #endif
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("签名与公钥详情")
                }
            }
            
            Section {
                detailRow(title: "有私钥", value: signableCert != nil ? "Yes" : "No")
                
                if let privateKey = signableCert?.privateKey {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("私钥数据")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            
                            SwiftUI.Button {
                                showPrivateKey.toggle()
                            } label: {
                                Image(systemName: showPrivateKey ? "eye.slash" : "eye")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            
                            #if !os(tvOS)
                            SwiftUI.Button {
                                UIPasteboard.general.string = privateKey.base64EncodedString()
                                copiedPrivateKey = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedPrivateKey = false
                                }
                            } label: {
                                Image(systemName: copiedPrivateKey ? "checkmark" : "doc.on.doc")
                                    .foregroundColor(copiedPrivateKey ? .green : .accentColor)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 12)
                            #endif
                        }
                        
                        if showPrivateKey {
                            Text(privateKey.base64EncodedString())
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                #if !os(tvOS)
                                .textSelection(.enabled)
                                #endif
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                        } else {
                            Text("••••••••••••••••••••••••••••")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if let certData = certificate.data {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("证书 PEM 数据")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            
                            #if !os(tvOS)
                            SwiftUI.Button {
                                let pem = String(data: certData, encoding: .utf8) ?? certData.base64EncodedString()
                                UIPasteboard.general.string = pem
                                copiedPEM = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedPEM = false
                                }
                            } label: {
                                Image(systemName: copiedPEM ? "checkmark" : "doc.on.doc")
                                    .foregroundColor(copiedPEM ? .green : .accentColor)
                            }
                            .buttonStyle(.plain)
                            #endif
                        }
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(String(data: certData, encoding: .utf8) ?? certData.base64EncodedString())
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                #if !os(tvOS)
                                .textSelection(.enabled)
                                #endif
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("加密密钥")
            }
        }
        .navigationTitle("证书详情")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    isRedacted.toggle()
                } label: {
                    Image(systemName: isRedacted ? "eye.slash" : "eye")
                }
            }
        }
    }
    
    private func redactableValue(_ value: String, sensitive: Bool = true) -> String {
        if sensitive && isRedacted {
            return "••••••••"
        }
        return value
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                #if !os(tvOS)
                .textSelection(.enabled)
                #endif
        }
    }
    
    private func detailRowWithCopy(title: String, value: String, isCopied: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                #if !os(tvOS)
                .textSelection(.enabled)
                #endif
            
            #if !os(tvOS)
            if value != "N/A" && !value.isEmpty && value != "••••••••" {
                SwiftUI.Button {
                    UIPasteboard.general.string = value
                    isCopied.wrappedValue = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied.wrappedValue = false
                    }
                } label: {
                    Image(systemName: isCopied.wrappedValue ? "checkmark" : "doc.on.doc")
                        .font(.footnote)
                        .foregroundColor(isCopied.wrappedValue ? .green : .accentColor)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            #endif
        }
    }
}
