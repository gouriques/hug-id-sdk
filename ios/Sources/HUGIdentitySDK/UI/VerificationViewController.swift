import UIKit
import AVKit

/// Fluxo: sessão → selfie → escolha de canal OTP → código → sucesso.
final class VerificationViewController: UIViewController {
    private enum Step {
        case loading
        case sessionError(String)
        case takePhoto
        case chooseChannel
        case enterCode
        case success
    }

    private static let resendCooldownSeconds = 60

    private let config: IdentityServiceConfig
    private let api: IdentityApiClient
    private var completion: (VerificationResult) -> Void

    private var step: Step = .loading
    private var sessionId: String = ""
    private var availableChannels: [AvailableChannel] = []
    private var selectedChannel: String?
    private var maskedDestination: String?
    private var resendSeconds = 0
    private var resendTimer: Timer?

    private let labelTitle = UILabel()
    private let labelDescription = UILabel()
    private let channelStack = UIStackView()
    private var channelButtons: [ChannelOptionView] = []

    private let buttonPhoto = UIButton(type: .system)
    private let buttonSendCode = UIButton(type: .system)
    private let fieldCode: UITextField = {
        let f = UITextField()
        f.placeholder = "000000"
        f.keyboardType = .numberPad
        f.borderStyle = .roundedRect
        f.textAlignment = .center
        f.font = .systemFont(ofSize: 28, weight: .medium)
        f.textContentType = .oneTimeCode
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()
    private lazy var codeFieldDelegate = CodeFieldDelegate(maxDigits: 6)
    private let labelSendNewCode = UILabel()
    private let labelCounter = UILabel()
    private let buttonSendNewCode = UIButton(type: .system)
    private var photoTapOverlay: UIView?
    private let locationCapture = DeviceLocationCapture()

    init(config: IdentityServiceConfig, completion: @escaping (VerificationResult) -> Void) {
        self.config = config
        self.api = IdentityApiClient(baseURL: config.baseURL, authorizationToken: config.authorizationToken)
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { resendTimer?.invalidate() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verificação HUG-ID"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapToDismiss)
        setupView()
        startSession()
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in self?.completion(.cancelled) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        photoTapOverlay.map { view.bringSubviewToFront($0) }
        if case .enterCode = step {
            fieldCode.becomeFirstResponder()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if photoTapOverlay == nil, !buttonPhoto.isHidden {
            let overlay = UIView()
            overlay.backgroundColor = .clear
            overlay.isUserInteractionEnabled = true
            overlay.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: buttonPhoto.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: buttonPhoto.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: buttonPhoto.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: buttonPhoto.bottomAnchor)
            ])
            overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(sendPhotoTapped)))
            photoTapOverlay = overlay
        }
    }

    // MARK: - Layout

    private func setupView() {
        channelStack.axis = .vertical
        channelStack.spacing = 16
        channelStack.distribution = .fillEqually
        channelStack.translatesAutoresizingMaskIntoConstraints = false

        [labelTitle, labelDescription, buttonPhoto, buttonSendCode, fieldCode,
         labelSendNewCode, labelCounter, buttonSendNewCode].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        view.addSubview(channelStack)

        labelTitle.font = .systemFont(ofSize: 22, weight: .semibold)
        labelTitle.numberOfLines = 0
        labelDescription.font = .systemFont(ofSize: 16)
        labelDescription.numberOfLines = 0
        labelDescription.textColor = .label

        labelSendNewCode.font = .systemFont(ofSize: 14)
        labelSendNewCode.text = "Não recebeu? Novo código em "
        labelCounter.font = .systemFont(ofSize: 14)

        applyPrimaryStyle(buttonPhoto, title: "Tirar minha foto")
        buttonPhoto.addTarget(self, action: #selector(sendPhotoTapped), for: .touchUpInside)

        applyPrimaryStyle(buttonSendCode, title: "Enviar código")
        buttonSendCode.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)

        buttonSendNewCode.setTitle("Enviar novo código", for: .normal)
        buttonSendNewCode.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)

        fieldCode.delegate = codeFieldDelegate
        codeFieldDelegate.onComplete = { [weak self] code in
            self?.fieldCode.text = code
            self?.confirmTapped()
        }

        NSLayoutConstraint.activate([
            labelTitle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            labelTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            labelTitle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            labelDescription.topAnchor.constraint(equalTo: labelTitle.bottomAnchor, constant: 24),
            labelDescription.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            labelDescription.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            channelStack.topAnchor.constraint(equalTo: labelDescription.bottomAnchor, constant: 32),
            channelStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            channelStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            buttonPhoto.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonPhoto.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            buttonPhoto.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),

            buttonSendCode.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonSendCode.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            buttonSendCode.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),

            fieldCode.topAnchor.constraint(equalTo: labelDescription.bottomAnchor, constant: 32),
            fieldCode.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            fieldCode.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            fieldCode.heightAnchor.constraint(equalToConstant: 56),

            labelSendNewCode.topAnchor.constraint(equalTo: fieldCode.bottomAnchor, constant: 12),
            labelSendNewCode.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            labelCounter.centerYAnchor.constraint(equalTo: labelSendNewCode.centerYAnchor),
            labelCounter.leadingAnchor.constraint(equalTo: labelSendNewCode.trailingAnchor),

            buttonSendNewCode.topAnchor.constraint(equalTo: fieldCode.bottomAnchor, constant: 24),
            buttonSendNewCode.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24)
        ])
        updateUI()
    }

    private func applyPrimaryStyle(_ button: UIButton, title: String) {
        let tint = view.tintColor ?? .systemGreen
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = tint
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
    }

    private func updateUI() {
        switch step {
        case .loading:
            labelTitle.text = "Verificação HUG-ID"
            labelDescription.text = "Preparando verificação..."
            hideChannelUI(true)
            buttonPhoto.isHidden = true
            photoTapOverlay?.isHidden = true
            buttonSendCode.isHidden = true
            hideCodeUI(true)

        case .sessionError(let message):
            labelTitle.text = "Verificação HUG-ID"
            labelDescription.text = message
            hideChannelUI(true)
            buttonPhoto.isHidden = true
            photoTapOverlay?.isHidden = true
            buttonSendCode.isHidden = true
            hideCodeUI(true)

        case .takePhoto:
            labelTitle.text = "Verificação HUG-ID"
            labelDescription.text = "Tire uma selfie para comprovar sua identidade e ativar o Token."
            hideChannelUI(true)
            applyPrimaryStyle(buttonPhoto, title: "Tirar minha foto")
            buttonPhoto.isHidden = false
            photoTapOverlay?.isHidden = false
            buttonSendCode.isHidden = true
            hideCodeUI(true)

        case .chooseChannel:
            labelTitle.text = "Verificação HUG-ID"
            if availableChannels.isEmpty {
                labelDescription.text = "Nenhum canal de envio está disponível no momento. Tente novamente mais tarde."
                buttonSendCode.isEnabled = false
                buttonSendCode.alpha = 0.5
            } else {
                labelDescription.text = "Escolha onde deseja receber o código"
                buttonSendCode.isEnabled = selectedChannel != nil
                buttonSendCode.alpha = selectedChannel != nil ? 1 : 0.5
            }
            configureChannelOptions()
            hideChannelUI(false)
            buttonPhoto.isHidden = true
            photoTapOverlay?.isHidden = true
            applyPrimaryStyle(buttonSendCode, title: "Enviar código")
            buttonSendCode.isHidden = false
            hideCodeUI(true)

        case .enterCode:
            labelTitle.text = "Verificação HUG-ID"
            if let dest = maskedDestination, !dest.isEmpty {
                labelDescription.text = "Digite o código enviado para \(dest)"
            } else {
                labelDescription.text = "Digite o código recebido"
            }
            hideChannelUI(true)
            buttonPhoto.isHidden = true
            photoTapOverlay?.isHidden = true
            buttonSendCode.isHidden = true
            hideCodeUI(false)
            fieldCode.becomeFirstResponder()

        case .success:
            labelTitle.text = "Verificação HUG-ID"
            labelDescription.text = "Verificação concluída."
            hideChannelUI(true)
            buttonPhoto.isHidden = true
            photoTapOverlay?.isHidden = true
            buttonSendCode.isHidden = true
            hideCodeUI(true)
        }
    }

    private func hideChannelUI(_ hidden: Bool) {
        channelStack.isHidden = hidden
    }

    private func hideCodeUI(_ hidden: Bool) {
        fieldCode.isHidden = hidden
        labelSendNewCode.isHidden = hidden || resendSeconds <= 0
        labelCounter.isHidden = hidden || resendSeconds <= 0
        buttonSendNewCode.isHidden = hidden || resendSeconds > 0
    }

    private func configureChannelOptions() {
        channelStack.arrangedSubviews.forEach {
            channelStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        channelButtons.removeAll()
        for option in availableChannels {
            let card = ChannelOptionView(option: option)
            card.isSelectedOption = (option.channel == selectedChannel)
            card.onTap = { [weak self] channel in
                self?.didSelectChannel(channel)
            }
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
            channelStack.addArrangedSubview(card)
            channelButtons.append(card)
        }
    }

    private func didSelectChannel(_ channel: String) {
        selectedChannel = channel
        configureChannelOptions()
        buttonSendCode.isEnabled = true
        buttonSendCode.alpha = 1
    }

    // MARK: - Fluxo

    private func startSession() {
        step = .loading
        updateUI()
        Task { @MainActor in
            do {
                let result = try await api.createSession(userId: config.userId, email: config.email, phone: config.phone)
                sessionId = result.sessionId
                availableChannels = result.availableChannels
                if availableChannels.count == 1 {
                    selectedChannel = availableChannels[0].channel
                }
                step = .takePhoto
                updateUI()
                await submitLocationIfEnabled(context: "verification-session-start")
            } catch {
                step = .sessionError("Erro ao criar sessão: \(error.localizedDescription)")
                updateUI()
            }
        }
    }

    @objc private func sendPhotoTapped() {
        guard !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            step = .sessionError("Não foi possível criar a sessão HUG-ID. Tente abrir a verificação novamente.")
            updateUI()
            return
        }
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.openCamera() }
                    else {
                        self?.step = .sessionError("Permita acesso à câmera nas configurações.")
                        self?.updateUI()
                    }
                }
            }
            return
        }
        openCamera()
    }

    private func openCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = self
        picker.cameraOverlayView = faceOvalOverlayView()
        present(picker, animated: true)
    }

    private func faceOvalOverlayView() -> UIView {
        let overlay = FaceOvalOverlay()
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        overlay.frame = UIScreen.main.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return overlay
    }

    private func uploadPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        labelDescription.text = "Enviando foto..."
        buttonPhoto.isEnabled = false
        Task { @MainActor in
            do {
                try await api.uploadPhoto(sessionId: sessionId, imageData: data)
                await submitLocationIfEnabled(context: "verification-photo-uploaded")
                step = .chooseChannel
                updateUI()
            } catch {
                labelDescription.text = "Erro: \(error.localizedDescription)"
                step = .takePhoto
                updateUI()
            }
            buttonPhoto.isEnabled = true
        }
    }

    @objc private func sendCodeTapped() {
        guard let channel = selectedChannel else {
            labelDescription.text = "Selecione um canal para receber o código."
            return
        }
        buttonSendCode.isEnabled = false
        labelDescription.text = "Enviando código..."
        Task { @MainActor in
            do {
                maskedDestination = try await api.sendCode(sessionId: sessionId, channel: channel)
                startResendCooldown()
                step = .enterCode
                updateUI()
            } catch {
                labelDescription.text = "Erro: \(error.localizedDescription)"
                step = .chooseChannel
                updateUI()
            }
            buttonSendCode.isEnabled = true
        }
    }

    @objc private func confirmTapped() {
        let code = (fieldCode.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 6 else {
            labelDescription.text = "Digite o código de 6 dígitos."
            return
        }
        labelDescription.text = "Verificando..."
        Task { @MainActor in
            do {
                try await api.confirmCode(sessionId: sessionId, code: String(code.prefix(6)))
                await submitLocationIfEnabled(context: "verification-code-confirmed")
                step = .success
                updateUI()
                dismiss(animated: true) { [weak self] in self?.completion(.success) }
            } catch {
                labelDescription.text = "Erro: \(error.localizedDescription)"
            }
        }
    }

    private func submitLocationIfEnabled(context: String) async {
        guard config.enableLocationSignals, !sessionId.isEmpty else { return }
        guard let sample = await locationCapture.capture(from: self) else { return }
        do {
            try await api.recordSessionLocation(
                sessionId: sessionId,
                userId: config.userId,
                context: context,
                sample: sample
            )
        } catch {
            // Best-effort
        }
    }

    private func startResendCooldown() {
        resendTimer?.invalidate()
        resendSeconds = Self.resendCooldownSeconds
        updateResendLabels()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.resendSeconds -= 1
            self.updateResendLabels()
            if self.resendSeconds <= 0 {
                self.resendTimer?.invalidate()
                self.resendTimer = nil
            }
        }
    }

    private func updateResendLabels() {
        guard case .enterCode = step else { return }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        labelCounter.text = formatter.string(from: TimeInterval(max(0, resendSeconds))) ?? "0:00"
        hideCodeUI(false)
    }
}

extension VerificationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        uploadPhoto(image)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

private final class ChannelOptionView: UIControl {
    var onTap: ((String) -> Void)?
    private let channel: String
    private let titleLabel = UILabel()
    private let destinationLabel = UILabel()

    var isSelectedOption: Bool = false {
        didSet { applySelectionStyle() }
    }

    init(option: AvailableChannel) {
        self.channel = option.channel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 16
        layer.borderWidth = 2
        backgroundColor = .secondarySystemBackground

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.text = option.displayTitle

        destinationLabel.translatesAutoresizingMaskIntoConstraints = false
        destinationLabel.font = .systemFont(ofSize: 18)
        destinationLabel.textColor = .secondaryLabel
        destinationLabel.numberOfLines = 2
        destinationLabel.text = option.maskedDestination ?? ""

        addSubview(titleLabel)
        addSubview(destinationLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            destinationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            destinationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            destinationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            destinationLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        applySelectionStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?(channel) }

    private func applySelectionStyle() {
        let brand = tintColor ?? .systemGreen
        layer.borderColor = (isSelectedOption ? brand : UIColor.separator).cgColor
        backgroundColor = isSelectedOption ? brand.withAlphaComponent(0.08) : .secondarySystemBackground
    }
}

private final class CodeFieldDelegate: NSObject, UITextFieldDelegate {
    let maxDigits: Int
    var onComplete: ((String) -> Void)?
    init(maxDigits: Int) { self.maxDigits = maxDigits }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard string.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) else { return false }
        let current = (textField.text ?? "") as NSString
        let result = current.replacingCharacters(in: range, with: string)
        if result.count == maxDigits {
            DispatchQueue.main.async { [weak self] in self?.onComplete?(result) }
        }
        return result.count <= maxDigits
    }
}

private final class FaceOvalOverlay: UIView {
    private let ovalLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor.clear.cgColor
        l.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
        l.lineWidth = 3
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(ovalLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let ovalWidth = bounds.width * 0.76
        let ovalHeight = bounds.height * 0.48
        let centerY = (bounds.height - ovalHeight) / 2
        let shiftUp = bounds.height * 0.1
        let rect = CGRect(x: (bounds.width - ovalWidth) / 2, y: centerY - shiftUp, width: ovalWidth, height: ovalHeight)
        ovalLayer.path = UIBezierPath(ovalIn: rect).cgPath
        ovalLayer.frame = bounds
    }
}
