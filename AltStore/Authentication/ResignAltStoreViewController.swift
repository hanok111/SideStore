//
//  ResignAltStoreViewController.swift
//  AltStore
//
//  Created by Riley Testut on 10/26/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SideSign

final class ResignAltStoreViewController: UIViewController
{
    var context: StandaloneOperationContext!
    var mismatchReason: CodeSignValidationReason?
    var isFreeTeam: Bool = false
    
    var completionHandler: ((Result<Void, Error>) -> Void)?
    
    @IBOutlet private var placeholderView: PlaceholderView!
    @IBOutlet private var reinstallButton: PillButton!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.placeholderView.textLabel.isHidden = true
        
        self.placeholderView.detailTextLabel.textAlignment = .left
        self.placeholderView.detailTextLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        
        let isFreeTeam = self.isFreeTeam
        let reason = self.mismatchReason ?? (isFreeTeam ? .freeAccountLimitRevoked : .revoked)
        debugLog("[ResignAltStoreViewController] Displaying Resign SideStore Now screen (mismatchReason: \(reason)).")
        let reasonText: String
        
        switch reason {
            case .expired:
                reasonText = NSLocalizedString("用于安装 SideStore 的签名证书已过期。", comment: "")
            case .revoked:
                reasonText = NSLocalizedString("用于安装 SideStore 的签名证书已在 Apple 开发者门户被吊销。", comment: "")
            case .freeAccountLimitRevoked:
                reasonText = NSLocalizedString("免费开发者账号只能有 1 张有效的签名证书。由于在本设备上未找到该证书的私钥，SideStore 将创建一张新证书。这会自动吊销现有证书，可能会导致其他设备或 Xcode 安装的应用无法使用。", comment: "")
            case .differentAccount:
                reasonText = NSLocalizedString("登录的 Apple ID 账号已变更。", comment: "")
            case .differentTeam:
                reasonText = NSLocalizedString("当前开发者团队已变更。", comment: "")
            case .privateKeyLost:
                reasonText = NSLocalizedString("当前签名证书的私钥在本设备的钥匙串中缺失。", comment: "")
            case .externalSigner:
                reasonText = NSLocalizedString("SideStore 是由其他签名工具（如 Xcode 或 AltStore）安装的。", comment: "")
            case .missingProfile:
                reasonText = NSLocalizedString("SideStore 的描述文件缺失或无效。", comment: "")
            case .missingCertificate:
                reasonText = NSLocalizedString("无法从 SideStore 的二进制文件中提取签名证书。", comment: "")
        }
        
        let isRevocationExpected = (reason == .privateKeyLost || reason == .freeAccountLimitRevoked)
        let buttonTitle = isRevocationExpected ?
            NSLocalizedString("立即吊销并重新签名", comment: "") :
            NSLocalizedString("立即重新签名", comment: "")
        self.reinstallButton.setTitle(buttonTitle, for: .normal)
        self.reinstallButton.fontSize = 15
        
        let header = NSLocalizedString("检测到签名证书不匹配。", comment: "")
        let paragraph1 = NSLocalizedString("为确保你能继续使用 SideStore，必须立即使用新证书重装应用。否则旧证书过期后，你将无法刷新或打开 SideStore。", comment: "")
        let paragraph2 = NSLocalizedString("这次重装会向系统注册新签名，并会退出 SideStore。重装完成后可以立即重新打开 SideStore。", comment: "")
        
        let fullText = "\(header)\n\n\(paragraph1)\n\n\(paragraph2)"
        let attributedString = NSMutableAttributedString(string: fullText)
        
        if let headerRange = fullText.range(of: header) {
            let nsRange = NSRange(headerRange, in: fullText)
            attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: nsRange)
        }
        
        self.placeholderView.detailTextLabel.attributedText = attributedString
        
        // Separator Line
        let separator = UIView()
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        // Reason Bold Prefix
        let reasonLabel = UILabel()
        reasonLabel.text = NSLocalizedString("原因：", comment: "")
        reasonLabel.textColor = .white
        reasonLabel.font = UIFont.boldSystemFont(ofSize: 14)
        reasonLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        // Reason Description
        let reasonTextLabel = UILabel()
        reasonTextLabel.text = reasonText
        reasonTextLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        reasonTextLabel.font = UIFont.systemFont(ofSize: 14)
        reasonTextLabel.numberOfLines = 0
        
        // Horizontal Container for key-value layout
        let reasonContainer = UIStackView(arrangedSubviews: [reasonLabel, reasonTextLabel])
        reasonContainer.axis = .horizontal
        reasonContainer.alignment = .top
        reasonContainer.spacing = 8
        
        // Add to standard Stack View hierarchy
        self.placeholderView.stackView.addArrangedSubview(separator)
        self.placeholderView.stackView.addArrangedSubview(reasonContainer)
        
        // Pin edges to match the width of the stack view
        separator.leadingAnchor.constraint(equalTo: self.placeholderView.stackView.leadingAnchor).isActive = true
        separator.trailingAnchor.constraint(equalTo: self.placeholderView.stackView.trailingAnchor).isActive = true
        
        reasonContainer.leadingAnchor.constraint(equalTo: self.placeholderView.stackView.leadingAnchor).isActive = true
        reasonContainer.trailingAnchor.constraint(equalTo: self.placeholderView.stackView.trailingAnchor).isActive = true
        
        self.placeholderView.stackView.setCustomSpacing(20, after: self.placeholderView.detailTextLabel)
        self.placeholderView.stackView.setCustomSpacing(15, after: separator)
    }
}

private extension ResignAltStoreViewController
{
    @IBAction func resignAltStore(_ sender: PillButton)
    {
        guard let altStore = InstalledApp.fetchAltStore(in: DatabaseManager.shared.viewContext) else { return }
                
        func refresh()
        {
            sender.isIndicatingActivity = true
            
            if let progress = AppManager.shared.installationProgress(for: altStore)
            {
                // Cancel pending AltStore installation so we can start a new one.
                progress.cancel()
            }
                        
            // Install, _not_ refresh, to ensure we are installing with a non-revoked certificate.
            let group = AppManager.shared.install(.app(altStore), presentingViewController: self, context: self.context) { (result) in
                switch result
                {
                case .success: self.completionHandler?(.success(()))
                case .failure(let error as NSError):
                    DispatchQueue.main.async {
                        sender.progress = nil
                        sender.isIndicatingActivity = false
                        
                        if error is CancellationError || (error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError) {
                            debugLog("[ResignAltStoreViewController] Operation cancelled. Auto-dismissing Resign SideStore Now screen.")
                            self.context?.error = OperationError.cancelled
                            self.completionHandler?(.failure(OperationError.cancelled))
                            self.dismiss(animated: true, completion: nil)
                            return
                        }
                        
                        let alertController = UIAlertController(title: NSLocalizedString("重新签名 SideStore 失败", comment: ""), message: error.localizedFailureReason ?? error.localizedDescription, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("再试一次", comment: ""), style: .default, handler: { (action) in
                            refresh()
                        }))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("稍后重新签名", comment: ""), style: .cancel, handler: { (action) in
                            self.completionHandler?(.failure(error))
                        }))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
            
            sender.progress = group.progress
        }
        
        refresh()
    }
    
    @IBAction func cancel(_ sender: UIButton)
    {
        self.completionHandler?(.failure(OperationError.cancelled))
    }
}
