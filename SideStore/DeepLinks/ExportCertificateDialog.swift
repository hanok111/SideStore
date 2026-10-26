//
//  ExportCertificateDialog.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

@MainActor
public enum ExportCertificateDialog {
    
    public static func present(callbackTemplate: String, presentingViewController: UIViewController? = nil) {
        let rootVC = presentingViewController ?? UIApplication.shared.topViewController()
        guard let presentingVC = rootVC else { return }
        
        let alert = UIAlertController(
            title: NSLocalizedString("导出证书", comment: ""),
            message: NSLocalizedString("要将你的证书导出到外部应用吗？该应用将能够使用你的证书签名应用。", comment: ""),
            preferredStyle: .alert
        )
        
        let exportAction = UIAlertAction(title: NSLocalizedString("导出", comment: ""), style: .default) { _ in
            guard callbackTemplate.contains("$(BASE64_CERT)") else {
                let toast = ToastView(text: NSLocalizedString("未找到 $(BASE64_CERT) 占位符", comment: ""), detailText: nil)
                toast.show(in: presentingVC)
                return
            }
            
            guard let encodedCert = CertificateManager.shared.activeSigningCertificateBase64Encoded,
                  let password = CertificateManager.shared.activeCertificate?.password else {
                let toast = ToastView(text: NSLocalizedString("找不到证书或密码", comment: ""), detailText: nil)
                toast.show(in: presentingVC)
                return
            }
            
            var urlStr = callbackTemplate.replacingOccurrences(of: "$(BASE64_CERT)", with: encodedCert, options: .literal, range: nil)
            urlStr = urlStr.replacingOccurrences(of: "$(PASSWORD)", with: password, options: .literal, range: nil)
            
            guard let callbackURL = URL(string: urlStr) else {
                let toast = ToastView(text: NSLocalizedString("初始化回调 URL 失败！", comment: ""), detailText: nil)
                toast.show(in: presentingVC)
                return
            }
            
            debugLog("[ExportCertificateDialog] Opening certificate callback URL: \(callbackURL.absoluteString)")
            UIApplication.shared.open(callbackURL)
        }
        
        alert.addAction(exportAction)
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        
        presentingVC.present(alert, animated: true)
    }
}
