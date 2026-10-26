//
//  SignInFlowHandler.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit
import SideSign

class SignInFlowHandler: AnyObject, SignInHandler, AnisetteServerHandler {
    
    private weak var presentingViewController: UIViewController?
    private weak var presentedAuthVC: AuthenticationViewController?
    
    private var credentialsContinuation: CheckedContinuation<(String, String), Error>?
    private var activeAuthCompletionHandler: ((Result<(ALTAccount, ALTAppleAPISession), Error>) -> Void)?
    var showsDoItLater: Bool = false
    
    private lazy var navigationController: UINavigationController = {
        let storyboard = UIStoryboard(name: "Authentication", bundle: nil)
        let navigationController = storyboard.instantiateViewController(withIdentifier: "navigationController") as! UINavigationController
        navigationController.isModalInPresentation = true
        return navigationController
    }()
    
    init(presentingViewController: UIViewController?) {
        self.presentingViewController = presentingViewController
    }

    private var isPresenterAvailable: Bool {
        return self.presentingViewController != nil || self.navigationController.presentingViewController != nil
    }

    private var activePresenter: UIViewController? {
        if self.navigationController.presentingViewController != nil {
            return self.navigationController
        }
        return self.presentingViewController?.presentedViewController ?? self.presentingViewController
    }
    
    @MainActor
    func credentials() async throws -> (String, String) {
        guard let presentingViewController = self.presentingViewController else {
            throw OperationError.invalidParameters("SignInFlowHandler: Cannot prompt for credentials because presentingViewController is nil")
        }
        
        if let _ = self.presentedAuthVC {
            return try await withCheckedThrowingContinuation { continuation in
                self.credentialsContinuation = continuation
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.credentialsContinuation = continuation
            
            let storyboard = UIStoryboard(name: "Authentication", bundle: nil)
            let authVC = storyboard.instantiateViewController(withIdentifier: "authenticationViewController") as! AuthenticationViewController
            self.presentedAuthVC = authVC
            
            authVC.authenticationHandler = { [weak self] (appleID, password, completionHandler) in
                guard let self = self else { return }
                self.activeAuthCompletionHandler = completionHandler
                if let credsContinuation = self.credentialsContinuation {
                    self.credentialsContinuation = nil
                    credsContinuation.resume(returning: (appleID, password))
                }
            }
            
            authVC.completionHandler = { [weak self] (result) in
                guard let self = self else { return }
                if result == nil {
                    // Cancelled
                    if let credsContinuation = self.credentialsContinuation {
                        self.credentialsContinuation = nil
                        credsContinuation.resume(throwing: OperationError.cancelled)
                    }
                    self.presentedAuthVC = nil
                    
                    if self.navigationController.presentingViewController != nil {
                        self.navigationController.dismiss(animated: true)
                    }
                } else {
                    // Success (dismissed)
                    self.presentedAuthVC = nil
                }
            }
            
            self.navigationController.view.tintColor = .altInvertedPrimary
            self.navigationController.setViewControllers([authVC], animated: false)
            presentingViewController.present(self.navigationController, animated: true)
        }
    }
    
    @MainActor
    func handleSignInResult(_ result: Result<(ALTAccount, ALTAppleAPISession), Error>) async {
        if let completionHandler = self.activeAuthCompletionHandler {
            self.activeAuthCompletionHandler = nil
            switch result {
            case .success((let account, let session)):
                completionHandler(.success((account, session)))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    @MainActor
    func verificationCode(for request: TwoFactorRequest) async throws -> TwoFactorResponse {
        guard self.isPresenterAvailable else {
            throw OperationError.invalidParameters("SignInFlowHandler: Cannot prompt for 2FA verification code because presenting view controller is unavailable")
        }

        let errorMessage: String? = request.error

        if let errorMessage, !errorMessage.isEmpty {
            let shouldRetry = try await showErrorRetryAlert(message: errorMessage)
            guard shouldRetry else {
                return .cancel
            }
        }

        switch request {
        case .selectDeliveryMethod(let preferredMode, let phoneNumbers):
            return try await withCheckedThrowingContinuation { continuation in
                self.showDeliveryMethodDialog(
                    preferredMode: preferredMode,
                    phoneNumbers: phoneNumbers,
                    activeID: phoneNumbers.first?.id ?? "",
                    continuation: continuation
                )
            }

        case .trustedDevice:
            return try await promptCodeEntry(
                title: NSLocalizedString("请输入发送到你 Apple 设备的 6 位验证码。", comment: ""),
                phoneNumbers: [],
                activePhoneID: "",
                currentDeliveryMode: nil,
                isTrustedDevice: true
            )

        case .sms(let phoneNumbers, let activeID, _):
            let activePhone = phoneNumbers.first(where: { $0.id == activeID })
            let title: String
            if let activePhone, !activePhone.number.isEmpty {
                title = String(format: NSLocalizedString("请输入通过短信发送到 %@ 的 6 位验证码。", comment: ""), activePhone.number)
            } else {
                title = NSLocalizedString("请输入通过短信发送到你手机的 6 位验证码。", comment: "")
            }
            return try await promptCodeEntry(
                title: title,
                phoneNumbers: phoneNumbers,
                activePhoneID: activeID,
                currentDeliveryMode: .sms,
                isTrustedDevice: false
            )

        case .voice(let phoneNumbers, let activeID, _):
            let activePhone = phoneNumbers.first(where: { $0.id == activeID })
            let title: String
            if let activePhone, !activePhone.number.isEmpty {
                title = String(format: NSLocalizedString("请输入通过电话呼叫发送到 %@ 的 6 位验证码。", comment: ""), activePhone.number)
            } else {
                title = NSLocalizedString("请输入通过电话呼叫发送的 6 位验证码。", comment: "")
            }
            return try await promptCodeEntry(
                title: title,
                phoneNumbers: phoneNumbers,
                activePhoneID: activeID,
                currentDeliveryMode: .voice,
                isTrustedDevice: false
            )
        }
    }

    @MainActor
    private func showErrorRetryAlert(message: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            let alert = UIAlertController(
                title: NSLocalizedString("验证失败", comment: ""),
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("重试", comment: ""), style: .default) { _ in
                continuation.resume(returning: true)
            })

            alert.addAction(UIAlertAction(title: systemLocalizedString("Cancel"), style: .cancel) { _ in
                continuation.resume(returning: false)
            })

            self.present(alert)
        }
    }

    @MainActor
    func accountRepair(url: URL, message: String) async -> AccountRepairDecision {
        guard self.isPresenterAvailable else {
            return .cancel
        }

        return await withCheckedContinuation { continuation in
            let appleAccountURL = AppConstants.URLs.appleAccount
            let baseMessage = message.isEmpty ? AppConstants.defaultAccountRepairMessage : message
            let displayMessage = """
                \(baseMessage)

                \(NSLocalizedString("警告：反复跳过而不完成必需验证或条款，久而久之可能导致你的账号被 Apple 限制。", comment: ""))
                """

            let alert = UIAlertController(
                title: NSLocalizedString("需要修复账号", comment: ""),
                message: displayMessage,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: NSLocalizedString("打开开发者账号", comment: ""), style: .default) { [weak self] _ in
                self?.activePresenter?.openWebURL(url)
                continuation.resume(returning: .cancel)
            })

            alert.addAction(UIAlertAction(title: NSLocalizedString("打开 Apple 账号", comment: ""), style: .default) { [weak self] _ in
                self?.activePresenter?.openWebURL(appleAccountURL)
                continuation.resume(returning: .cancel)
            })

            alert.addAction(UIAlertAction(title: NSLocalizedString("跳过并继续", comment: ""), style: .default) { _ in
                continuation.resume(returning: .proceed)
            })

            alert.addAction(UIAlertAction(title: systemLocalizedString("Cancel"), style: .cancel) { _ in
                continuation.resume(returning: .cancel)
            })

            self.present(alert)
        }
    }

    @MainActor
    private func promptCodeEntry(title: String,
                                 phoneNumbers: [TrustedPhoneNumber],
                                 activePhoneID: String,
                                 currentDeliveryMode: TwoFactorDeliveryMode?,
                                 isTrustedDevice: Bool) async throws -> TwoFactorResponse
    {
        return try await withCheckedThrowingContinuation { continuation in
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            var observer: NSObjectProtocol?
            alertController.addTextField { (textField) in
                textField.autocorrectionType = .no
                textField.autocapitalizationType = .none
                textField.keyboardType = .numberPad
                
                observer = NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: textField, queue: .main) { (notification) in
                    guard let textField = notification.object as? UITextField else { return }
                    alertController.actions.first?.isEnabled = (textField.text ?? "").count == 6
                }
            }
            
            let submitAction = UIAlertAction(title: NSLocalizedString("继续", comment: ""), style: .default) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                let textField = alertController.textFields?.first
                let code = textField?.text ?? ""
                continuation.resume(returning: .verificationCode(code))
            }
            submitAction.isEnabled = false
            alertController.addAction(submitAction)

            if isTrustedDevice {
                let otherMethodsAction = UIAlertAction(title: NSLocalizedString("其他选项…", comment: ""), style: .default) { [weak self] _ in
                    if let observer = observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    guard let self = self else {
                        continuation.resume(returning: .cancel)
                        return
                    }
                    self.showDeliveryMethodDialog(preferredMode: .sms, phoneNumbers: phoneNumbers, activeID: activePhoneID, continuation: continuation)
                }
                alertController.addAction(otherMethodsAction)
            } else if let mode = currentDeliveryMode {
                let resendTitle = (mode == .sms)
                    ? NSLocalizedString("重发短信", comment: "")
                    : NSLocalizedString("再次呼叫", comment: "")
                let resendAction = UIAlertAction(title: resendTitle, style: .default) { _ in
                    if let observer = observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    if case .voice = mode {
                        return continuation.resume(returning: .requestVoice(phoneID: activePhoneID))
                    }
                    if case .sms = mode {
                        return continuation.resume(returning: .requestSMS(phoneID: activePhoneID))
                    }
                }
                alertController.addAction(resendAction)

                let otherMethodsAction = UIAlertAction(title: NSLocalizedString("其他选项…", comment: ""), style: .default) { [weak self] _ in
                    if let observer = observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    guard let self = self else {
                        continuation.resume(returning: .cancel)
                        return
                    }
                    self.showDeliveryMethodDialog(preferredMode: .trustedDevice, phoneNumbers: phoneNumbers, activeID: activePhoneID, continuation: continuation)
                }
                alertController.addAction(otherMethodsAction)

                if phoneNumbers.count > 1 {
                    let changeNumberAction = UIAlertAction(title: NSLocalizedString("选择其他号码", comment: ""), style: .default) { [weak self] _ in
                        if let observer = observer {
                            NotificationCenter.default.removeObserver(observer)
                        }
                        guard let self = self else {
                            continuation.resume(returning: .cancel)
                            return
                        }
                        self.showPhoneNumberSelectionDialog(phoneNumbers: phoneNumbers, activeID: activePhoneID, mode: mode, continuation: continuation)
                    }
                    alertController.addAction(changeNumberAction)
                }
            }
            
            alertController.addAction(UIAlertAction(title: systemLocalizedString("Cancel"), style: .cancel) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: .cancel)
            })
            
            self.present(alertController)
        }
    }

    @MainActor
    private func showDeliveryMethodDialog(preferredMode: TwoFactorDeliveryMode,
                                          phoneNumbers: [TrustedPhoneNumber],
                                          activeID: String,
                                          continuation: CheckedContinuation<TwoFactorResponse, Error>)
    {
        let alert = UIAlertController(
            title: NSLocalizedString("验证方式", comment: ""),
            message: NSLocalizedString("你希望如何接收验证码？", comment: ""),
            preferredStyle: .alert
        )

        let isAppleDefault = (preferredMode == .trustedDevice)
        let trustedDeviceTitle = isAppleDefault
            ? NSLocalizedString("苹果设备（推荐）", comment: "")
            : NSLocalizedString("苹果设备", comment: "")
        let trustedDeviceAction = UIAlertAction(title: trustedDeviceTitle, style: .default) { _ in
            continuation.resume(returning: .requestTrustedDevice)
        }
        alert.addAction(trustedDeviceAction)

        let isSMSDefault = (preferredMode == .sms)
        let smsTitle = isSMSDefault
            ? NSLocalizedString("短信（推荐）", comment: "")
            : NSLocalizedString("短信", comment: "")
        let smsAction = UIAlertAction(title: smsTitle, style: .default) { [weak self] _ in
            guard let self = self else {
                continuation.resume(returning: .cancel)
                return
            }
            if phoneNumbers.count > 1 {
                self.showPhoneNumberSelectionDialog(phoneNumbers: phoneNumbers, activeID: activeID, mode: .sms, continuation: continuation)
            } else {
                let targetID = phoneNumbers.first?.id ?? activeID
                continuation.resume(returning: .requestSMS(phoneID: targetID))
            }
        }
        alert.addAction(smsAction)

        let isVoiceDefault = (preferredMode == .voice)
        let voiceTitle = isVoiceDefault
            ? NSLocalizedString("电话呼叫（推荐）", comment: "")
            : NSLocalizedString("电话呼叫", comment: "")
        let voiceAction = UIAlertAction(title: voiceTitle, style: .default) { [weak self] _ in
            guard let self = self else {
                continuation.resume(returning: .cancel)
                return
            }
            if phoneNumbers.count > 1 {
                self.showPhoneNumberSelectionDialog(phoneNumbers: phoneNumbers, activeID: activeID, mode: .voice, continuation: continuation)
            } else {
                let targetID = phoneNumbers.first?.id ?? activeID
                continuation.resume(returning: .requestVoice(phoneID: targetID))
            }
        }
        alert.addAction(voiceAction)

        alert.addAction(UIAlertAction(title: systemLocalizedString("Cancel"), style: .cancel) { _ in
            continuation.resume(returning: .cancel)
        })

        switch preferredMode {
        case .trustedDevice:
            alert.preferredAction = trustedDeviceAction
        case .sms:
            alert.preferredAction = smsAction
        case .voice:
            alert.preferredAction = voiceAction
        }

        self.present(alert)
    }

    @MainActor
    private func showPhoneNumberSelectionDialog(phoneNumbers: [TrustedPhoneNumber],
                                                 activeID: String,
                                                 mode: TwoFactorDeliveryMode,
                                                 continuation: CheckedContinuation<TwoFactorResponse, Error>)
    {
        let alert = UIAlertController(
            title: NSLocalizedString("选择电话号码", comment: ""),
            message: NSLocalizedString("选择一个用于接收验证码的电话号码：", comment: ""),
            preferredStyle: .alert
        )

        for phone in phoneNumbers {
            let isCurrent = (phone.id == activeID)
            let buttonTitle = isCurrent ? "\(phone.number) (Current)" : phone.number
            let action = UIAlertAction(title: buttonTitle, style: .default) { _ in
                if case .voice = mode {
                    return continuation.resume(returning: .requestVoice(phoneID: phone.id))
                }
                if case .sms = mode {
                    return continuation.resume(returning: .requestSMS(phoneID: phone.id))
                }
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: systemLocalizedString("Cancel"), style: .cancel) { _ in
            continuation.resume(returning: .cancel)
        })

        self.present(alert)
    }
    
    @MainActor
    func resolveRevocation(certificates: [ALTX509Certificate], teamType: ALTTeamType) async throws -> RevokeDecision {
        guard self.isPresenterAvailable else {
            throw OperationError.invalidParameters("SignInFlowHandler: Cannot resolve certificate revocation because presenting view controller is unavailable")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let alertController = UIAlertController(
                title: NSLocalizedString("吊销证书", comment: ""),
                message: NSLocalizedString("选择要吊销的 iOS 开发证书：", comment: ""),
                preferredStyle: .alert
            )
            
            let revokeVC = RevokeCertificatesAlertViewController(certificates: certificates, teamType: teamType)
            alertController.setValue(revokeVC, forKey: "contentViewController")
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel) { _ in
                if teamType == .free {
                    let warningAlert = UIAlertController(
                        title: NSLocalizedString("警告", comment: ""),
                        message: NSLocalizedString("SideStore 在没有私钥的情况下无法管理现有证书。除非 SideStore 明确重签并续期，否则用现有证书签名的应用将很快过期。", comment: ""),
                        preferredStyle: .alert
                    )
                    warningAlert.addAction(UIAlertAction(title: NSLocalizedString("好", comment: ""), style: .default) { _ in
                        warningAlert.dismiss(animated: true) {
                            continuation.resume(returning: .keepExisting)
                        }
                    })
                    self.present(warningAlert)
                } else {
                    continuation.resume(returning: .keepExisting)
                }
            }
            
            let isPaid = (teamType != .free && teamType != .unknown)
            let initialCount = revokeVC.getSelectedCertificates().count
            let initialTitle: String
            if isPaid {
                initialTitle = (initialCount == 0) ? "Continue Without Revoking" : "Revoke Selected (\(initialCount))"
            } else {
                initialTitle = "Revoke"
            }
            let actionStyle: UIAlertAction.Style = (isPaid && initialCount == 0) ? .default : .destructive
            let revokeAction = UIAlertAction(title: initialTitle, style: actionStyle) { _ in
                alertController.dismiss(animated: true) {
                    let selected = revokeVC.getSelectedCertificates()
                    continuation.resume(returning: .revokeSelected(selected))
                }
            }
            
            if isPaid {
                revokeAction.isEnabled = true
                revokeVC.onSelectionChanged = { selected in
                    if selected.isEmpty {
                        revokeAction.setValue(NSLocalizedString("不吊销并继续", comment: ""), forKey: "title")
                        revokeAction.setValue(nil, forKey: "titleTextColor")
                    } else {
                        revokeAction.setValue("Revoke Selected (\(selected.count))", forKey: "title")
                        revokeAction.setValue(UIColor.systemRed, forKey: "titleTextColor")
                    }
                }
            }
            
            alertController.addAction(cancelAction)
            alertController.addAction(revokeAction)
            
            self.present(alertController)
        }
    }
    
    @MainActor
    func resolveTeam(_ teams: [ALTTeam]) async throws -> ALTTeam {
        guard self.isPresenterAvailable else {
            throw OperationError.invalidParameters("SignInFlowHandler: Cannot resolve team selection because presenting view controller is unavailable")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let storyboard = UIStoryboard(name: "Authentication", bundle: nil)
            let selectTeamViewController = storyboard.instantiateViewController(withIdentifier: "selectTeamViewController") as! SelectTeamViewController
            selectTeamViewController.teams = teams
            selectTeamViewController.completionHandler = { result in
                continuation.resume(with: result)
            }
            self.present(selectTeamViewController)
        }
    }
    
    @MainActor
    func resolvePostAuth() async {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            let storyboard = UIStoryboard(name: "Authentication", bundle: nil)
            let instructionsViewController = storyboard.instantiateViewController(withIdentifier: "instructionsViewController") as! InstructionsViewController
            instructionsViewController.showsBottomButton = true
            instructionsViewController.completionHandler = {
                guard !hasResumed else {
                    debugLog("[SignInFlowHandler] resolvePostAuth completionHandler invoked more than once. Ignoring.")
                    return
                }
                hasResumed = true
                continuation.resume(returning: ())
            }
            self.present(instructionsViewController)
        }
    }
    
    @MainActor
    func resolveDeviceRegistrationErrors(_ error: Error) async -> ProvisioningErrorDecision {
        let title: String
        if error is OperationError {
            title = NSLocalizedString("设备注册错误", comment: "")
        } else {
            title = NSLocalizedString("开发者门户错误", comment: "")
        }

        return await withCheckedContinuation { continuation in
            let alertController = UIAlertController(
                title: title,
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            
            if self.showsDoItLater {
                let retryAction = UIAlertAction(title: NSLocalizedString("重试", comment: ""), style: .default) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .retry)
                    }
                }
                let laterAction = UIAlertAction(title: NSLocalizedString("稍后再说", comment: ""), style: .cancel) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .cancel)
                    }
                }
                alertController.addAction(retryAction)
                alertController.addAction(laterAction)
            } else {
                let cancelAction = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .cancel)
                    }
                }
                
                let skipAction = UIAlertAction(title: NSLocalizedString("跳过", comment: ""), style: .default) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .skip)
                    }
                }
                
                let retryAction = UIAlertAction(title: NSLocalizedString("重试", comment: ""), style: .default) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .retry)
                    }
                }
                
                alertController.addAction(retryAction)
                alertController.addAction(skipAction)
                alertController.addAction(cancelAction)
            }
            
            self.present(alertController)
        }
    }
    
    @MainActor
    func resolveProvisioningError(_ error: Error) async -> ProvisioningErrorDecision {
        return await withCheckedContinuation { continuation in
            let alertController = UIAlertController(
                title: NSLocalizedString("开发者门户错误", comment: ""),
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            
            if self.showsDoItLater {
                let retryAction = UIAlertAction(title: NSLocalizedString("重试", comment: ""), style: .default) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .retry)
                    }
                }
                let laterAction = UIAlertAction(title: NSLocalizedString("稍后再说", comment: ""), style: .cancel) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .cancel)
                    }
                }
                alertController.addAction(retryAction)
                alertController.addAction(laterAction)
            } else {
                let cancelAction = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .cancel)
                    }
                }
                
                let skipAction = UIAlertAction(title: NSLocalizedString("跳过", comment: ""), style: .default) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .skip)
                    }
                }
                
                let retryAction = UIAlertAction(title: NSLocalizedString("重试", comment: ""), style: .default) { _ in
                    alertController.dismiss(animated: true) {
                        continuation.resume(returning: .retry)
                    }
                }
                
                alertController.addAction(cancelAction)
                alertController.addAction(skipAction)
                alertController.addAction(retryAction)
            }
            
            self.present(alertController)
        }
    }
    
    @MainActor
    func showCertificateSkipAcknowledgment() async {
        await withCheckedContinuation { continuation in
            let alertController = UIAlertController(
                title: NSLocalizedString("已跳过证书设置", comment: ""),
                message: NSLocalizedString("当前签名证书不存在且未正确获取/设置。你可以稍后完成待处理操作，或前往“设置 -> 证书管理”手动设置证书。", comment: ""),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("好", comment: ""), style: .default) { _ in
                alertController.dismiss(animated: true) {
                    continuation.resume()
                }
            })
            self.present(alertController)
        }
    }

    @MainActor
    func showDeviceRegistrationSkipAcknowledgment() async {
        await withCheckedContinuation { continuation in
            let alertController = UIAlertController(
                title: NSLocalizedString("已跳过设备注册", comment: ""),
                message: NSLocalizedString("你的设备尚未在此开发者团队下注册。完成注册之前无法安装或刷新应用，稍后可在设置中完成。", comment: ""),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("好", comment: ""), style: .default) { _ in
                alertController.dismiss(animated: true) {
                    continuation.resume()
                }
            })
            self.present(alertController)
        }
    }
    
    @MainActor
    func resolveResign(mismatchReason: CodeSignValidationReason, context: StandaloneOperationContext) async throws -> Bool {
        guard self.isPresenterAvailable else {
            throw OperationError.invalidParameters("SignInFlowHandler: Cannot resolve resign prompt because presenting view controller is unavailable")
        }

        let isFreeTeam = try await AuthManager.shared.getAuthenticatedTeam().type == .free

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let storyboard = UIStoryboard(name: "Authentication", bundle: nil)
            let resignViewController = storyboard.instantiateViewController(withIdentifier: "resignAltStoreViewController") as! ResignAltStoreViewController
            resignViewController.context = context
            resignViewController.mismatchReason = mismatchReason
            resignViewController.isFreeTeam = isFreeTeam ?? false
            resignViewController.completionHandler = { result in
                guard !hasResumed else {
                    debugLog("[SignInFlowHandler] resolveResign completionHandler invoked more than once. Ignoring.")
                    return
                }
                hasResumed = true
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure:
                    continuation.resume(returning: false)
                }
            }
            self.present(resignViewController)
        }
    }
    
    @MainActor
    func complete() async {
        if self.navigationController.presentingViewController != nil {
            self.navigationController.dismiss(animated: true)
        }
    }
    
    @MainActor
    private func present(_ viewController: UIViewController) {
        let anchorVC = self.activePresenter
        if viewController is UIAlertController {
            anchorVC?.present(viewController, animated: true)
            return
        }
        
        if self.navigationController.presentingViewController != nil {
            if self.navigationController.viewControllers.contains(viewController) {
                // Already in stack
            } else {
                viewController.navigationItem.leftBarButtonItem = nil
                self.navigationController.pushViewController(viewController, animated: true)
            }
        } else {
            self.navigationController.setViewControllers([viewController], animated: false)
            anchorVC?.present(self.navigationController, animated: true)
        }
    }

    @MainActor
    func warnOutdatedAnisetteServer() async throws -> Bool {
        guard let presenter = self.activePresenter else {
            throw OperationError.invalidParameters("SignInFlowHandler: Cannot show outdated anisette warning because presenting view controller is unavailable")
        }
        
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: "警告：Anisette 服务器已过时", message: "检测到你正在使用较旧的 Anisette 服务器，使用此服务器更可能导致账号被锁定并引发其他问题，确定要继续吗？", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "继续", style: UIAlertAction.Style.destructive, handler: { action in
                continuation.resume(returning: true)
            }))
            alert.addAction(UIAlertAction(title: "取消", style: UIAlertAction.Style.cancel, handler: { action in
                continuation.resume(returning: false)
            }))
            
            presenter.present(alert, animated: true)
        }
    }
}
