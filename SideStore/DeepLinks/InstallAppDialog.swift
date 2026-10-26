//
//  InstallAppDialog.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

public enum AppImportSourceMode: String, CaseIterable, Identifiable, Sendable {
    case prompt = "prompt"
    case files  = "files"
    case url    = "url"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .prompt:
            return "Prompt User"
        case .files:
            #if !os(tvOS)
            return "Files App"
            #else
            return "Web Upload"
            #endif
        case .url:
            return "URL"
        }
    }
}

@MainActor
public enum InstallAppDialog {
    
    public static func presentSourceSelection(
        from presentingVC: UIViewController,
        barButtonItem: UIBarButtonItem? = nil,
        mode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode,
        onChooseFiles: @escaping () -> Void,
        onConfirm: @escaping (URL) -> Void
    ) {
        switch mode {
        case .prompt:
            #if !os(tvOS)
            let alertController = UIAlertController(
                title: NSLocalizedString("安装应用", comment: ""),
                message: nil,
                preferredStyle: .actionSheet
            )
            if let popover = alertController.popoverPresentationController {
                popover.barButtonItem = barButtonItem
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("从“文件”中选择", comment: ""), style: .default) { _ in
                onChooseFiles()
            })
            #else
            let alertController = UIAlertController(
                title: NSLocalizedString("安装应用", comment: ""),
                message: NSLocalizedString("选择安装方式：", comment: ""),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("通过网页上传", comment: ""), style: .default) { _ in
                onChooseFiles()
            })
            #endif
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("从 URL 安装", comment: ""), style: .default) { _ in
                self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
            
            presentingVC.present(alertController, animated: true)

        case .files:
            onChooseFiles()

        case .url:
            self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
        }
    }
    
    private static func presentURLInputDialog(
        from presentingVC: UIViewController,
        onConfirm: @escaping (URL) -> Void
    ) {
        let alert = UIAlertController(
            title: NSLocalizedString("从 URL 安装", comment: ""),
            message: NSLocalizedString("输入要安装的 .ipa 文件的 URL。", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://example.com/app.ipa"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("继续", comment: ""), style: .default) { _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https") else {
                let errorAlert = UIAlertController(
                    title: NSLocalizedString("无效的 URL", comment: ""),
                    message: NSLocalizedString("请输入有效的 HTTP 或 HTTPS URL。", comment: ""),
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: NSLocalizedString("好", comment: ""), style: .default))
                presentingVC.present(errorAlert, animated: true)
                return
            }
            
            self.present(ipaURL: url, from: presentingVC) {
                onConfirm(url)
            }
        })
        
        presentingVC.present(alert, animated: true)
    }
    
    public static func present(
        ipaURL: URL,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message: String
        if ipaURL.isFileURL {
            let appName = ipaURL.deletingPathExtension().lastPathComponent
            message = String(format: NSLocalizedString("是否继续？这将安装“%@”。", comment: ""), appName)
        } else {
            message = String(format: NSLocalizedString("是否继续？这将从以下位置下载并安装：\\n%@", comment: ""), ipaURL.absoluteString)
        }
        
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    public static func present(
        storeApp: StoreApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message = String(format: NSLocalizedString("是否继续？这将安装“%@”。", comment: ""), storeApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }

    public static func present(
        installedApp: InstalledApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message = String(format: NSLocalizedString("是否继续？这将重新安装“%@”。", comment: ""), installedApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    private static func presentConfirmation(
        message: String,
        from presentingViewController: UIViewController?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard UserDefaults.standard.isInstallConfirmationEnabled else {
            onConfirm()
            return
        }
        
        let rootVC = presentingViewController ?? UIApplication.shared.topViewController()
        guard let presentingVC = rootVC else {
            onCancel()
            return
        }
        
        let alert = UIAlertController(
            title: NSLocalizedString("安装应用", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("安装", comment: ""), style: .default) { _ in
            onConfirm()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel) { _ in
            onCancel()
        })
        
        presentingVC.present(alert, animated: true)
    }
}
