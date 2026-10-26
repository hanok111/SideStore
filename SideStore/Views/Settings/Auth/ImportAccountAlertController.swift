//
//  ImportAccountAlertController.swift
//  SideStore
//
//  Created by Magesh K on 8/10/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import Foundation

class ImportAccountAlertViewController: UIViewController {
    let passwordTextField = PaddedSecureTextField()

    override func viewDidLoad() {
        super.viewDidLoad()

        passwordTextField.isSecureTextEntry = true
        passwordTextField.placeholder = NSLocalizedString("文件密码", comment: "")
        passwordTextField.borderStyle = .none
        #if !os(tvOS)
        passwordTextField.backgroundColor = .tertiarySystemFill
        #else
        passwordTextField.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        #endif
        passwordTextField.layer.cornerRadius = 14
        passwordTextField.layer.masksToBounds = true
        passwordTextField.font = .systemFont(ofSize: 16)
        passwordTextField.autocapitalizationType = .none
        passwordTextField.autocorrectionType = .no

        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(passwordTextField)

        NSLayoutConstraint.activate([
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            passwordTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            passwordTextField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            passwordTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            passwordTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    override var preferredContentSize: CGSize {
        get {
            return CGSize(width: 270, height: 60)
        }
        set {
            super.preferredContentSize = newValue
        }
    }
}

class ImportAccountAlertController: UIAlertController {
    
    static func make(
        data: Data,
        checksum: String,
        presentingViewController: UIViewController
    ) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("导入账号", comment: ""),
            message: NSLocalizedString("找到一个账号配置文件，请输入密码以导入。", comment: ""),
            preferredStyle: .alert
        )
        let alertVC = ImportAccountAlertViewController()
        alert.setValue(alertVC, forKey: "contentViewController")
        
        let importAction = UIAlertAction(title: NSLocalizedString("导入", comment: ""), style: .default) { [weak presentingViewController, weak alertVC] _ in
            guard let presentingVC = presentingViewController,
                  let password = alertVC?.passwordTextField.text,
                  !password.isEmpty else { return }
            Task { @MainActor in
                do {
                    let account = try await ImportExport.importAccount(data, filePassword: password)
                    UserDefaults.standard.acctFileChecksum = checksum
                    let toastView = ToastView(
                        text: NSLocalizedString("Successfully imported '\(account.email)'!", comment: ""),
                        detailText: "SideStore should be fully operational!"
                    )
                    toastView.show(in: presentingVC)
                } catch {
                    debugLog("[ImportAccountAlertController] Failed to import account configuration: \(error)")
                    let toastView = ToastView(
                        text: NSLocalizedString("导入账号配置失败！", comment: ""),
                        detailText: error.localizedDescription
                    )
                    toastView.show(in: presentingVC)
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel)
        alert.addAction(importAction)
        alert.addAction(cancelAction)
        
        return alert
    }
}
