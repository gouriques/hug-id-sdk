import UIKit
import AVKit

final class VerificationViewController: UIViewController {
    private enum Step {
        case loading
        case takePhoto(sessionId: String)
        case enterCode(sessionId: String)
        case success
    }

    private let config: IdentityServiceConfig
    private let api: IdentityApiClient
    private var completion: (VerificationResult) -> Void

    private var step: Step = .loading
    private var sessionId: String = ""
    private var maskedEmail: String?
    private var maskedPhone: String?
    private var maskedDestinationFromPhoto: String?

    private let stack = UIStackView()
    private let labelStatus = UILabel()
    private let labelDestination = UILabel()
    private let buttonPhoto = UIButton(type: .system)
    private let photoWrapper = UIView()
    private lazy var fieldCode: UITextField = {
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
    private let buttonConfirm = UIButton(type: .system)
    private let confirmWrapper = UIView()
    private var photoTapOverlay: UIView?
    private var confirmTapOverlay: UIView?

    init(config: IdentityServiceConfig, completion: @escaping (VerificationResult) -> Void) {
        self.config = config
        self.api = IdentityApiClient(baseURL: config.baseURL, authorizationToken: config.authorizationToken)
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verificação HUG-ID"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapToDismiss)
        setupStack()
        startSession()
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in self?.completion(.cancelled) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        photoTapOverlay.map { view.bringSubviewToFront($0) }
        confirmTapOverlay.map { view.bringSubviewToFront($0) }
        if case .enterCode = step {
            updateUI()
            view.bringSubviewToFront(confirmWrapper)
            confirmTapOverlay.map { view.bringSubviewToFront($0) }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if photoTapOverlay == nil, !photoWrapper.isHidden {
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
        if confirmTapOverlay == nil, !confirmWrapper.isHidden {
            let overlay = UIView()
            overlay.backgroundColor = .clear
            overlay.isUserInteractionEnabled = true
            overlay.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: buttonConfirm.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: buttonConfirm.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: buttonConfirm.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: buttonConfirm.bottomAnchor)
            ])
            overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(confirmTapped)))
            confirmTapOverlay = overlay
        }
    }

    private func setupStack() {
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
        labelStatus.numberOfLines = 0
        labelStatus.textAlignment = .center
        labelStatus.font = .systemFont(ofSize: 17)
        stack.addArrangedSubview(labelStatus)
        labelDestination.numberOfLines = 0
        labelDestination.textAlignment = .center
        labelDestination.textColor = .secondaryLabel
        labelDestination.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(labelDestination)
        photoWrapper.translatesAutoresizingMaskIntoConstraints = false
        buttonPhoto.translatesAutoresizingMaskIntoConstraints = false
        applyPhotoButtonStyle()
        buttonPhoto.setTitle("Enviar foto", for: .normal)
        buttonPhoto.addTarget(self, action: #selector(sendPhotoTapped), for: .touchUpInside)
        photoWrapper.addSubview(buttonPhoto)
        NSLayoutConstraint.activate([
            buttonPhoto.topAnchor.constraint(equalTo: photoWrapper.topAnchor),
            buttonPhoto.leadingAnchor.constraint(equalTo: photoWrapper.leadingAnchor),
            buttonPhoto.trailingAnchor.constraint(equalTo: photoWrapper.trailingAnchor),
            buttonPhoto.bottomAnchor.constraint(equalTo: photoWrapper.bottomAnchor)
        ])
        stack.addArrangedSubview(photoWrapper)
        NSLayoutConstraint.activate([photoWrapper.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        stack.addArrangedSubview(fieldCode)
        NSLayoutConstraint.activate([
            fieldCode.heightAnchor.constraint(equalToConstant: 56),
            fieldCode.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        fieldCode.delegate = codeFieldDelegate
        confirmWrapper.translatesAutoresizingMaskIntoConstraints = false
        buttonConfirm.translatesAutoresizingMaskIntoConstraints = false
        buttonConfirm.setTitle("Confirmar código", for: .normal)
        buttonConfirm.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmWrapper.addSubview(buttonConfirm)
        NSLayoutConstraint.activate([
            buttonConfirm.topAnchor.constraint(equalTo: confirmWrapper.topAnchor),
            buttonConfirm.leadingAnchor.constraint(equalTo: confirmWrapper.leadingAnchor),
            buttonConfirm.trailingAnchor.constraint(equalTo: confirmWrapper.trailingAnchor),
            buttonConfirm.bottomAnchor.constraint(equalTo: confirmWrapper.bottomAnchor)
        ])
        stack.addArrangedSubview(confirmWrapper)
        NSLayoutConstraint.activate([confirmWrapper.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        updateUI()
    }

    private func applyPhotoButtonStyle() {
        buttonPhoto.setTitleColor(.white, for: .normal)
        buttonPhoto.setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)
        buttonPhoto.backgroundColor = .systemBlue
        buttonPhoto.layer.cornerRadius = 12
        buttonPhoto.clipsToBounds = true
        buttonPhoto.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        buttonPhoto.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
    }

    private func updateUI() {
        switch step {
        case .loading:
            labelStatus.text = "Criando sessão..."
            labelDestination.text = nil
            labelDestination.isHidden = true
            buttonPhoto.isHidden = true
            photoWrapper.isHidden = true
            photoTapOverlay?.isHidden = true
            fieldCode.isHidden = true
            buttonConfirm.isHidden = true
            confirmWrapper.isHidden = true
            confirmTapOverlay?.isHidden = true
        case .takePhoto:
            labelStatus.text = "Tire uma selfie para enviar."
            labelDestination.text = nil
            labelDestination.isHidden = true
            applyPhotoButtonStyle()
            buttonPhoto.isHidden = false
            photoWrapper.isHidden = false
            photoTapOverlay?.isHidden = false
            fieldCode.isHidden = true
            buttonConfirm.isHidden = true
            confirmWrapper.isHidden = true
            confirmTapOverlay?.isHidden = true
        case .enterCode:
            labelStatus.text = "Digite o código recebido por e-mail ou SMS."
            if let dest = maskedDestinationFromPhoto, !dest.isEmpty {
                labelDestination.text = "Código enviado para: " + dest
                labelDestination.isHidden = false
            } else {
                var parts: [String] = []
                if let e = maskedEmail, !e.isEmpty { parts.append(e) }
                if let p = maskedPhone, !p.isEmpty { parts.append(p) }
                labelDestination.text = parts.isEmpty ? nil : "Código enviado para: " + parts.joined(separator: " e ")
                labelDestination.isHidden = parts.isEmpty
            }
            buttonPhoto.isHidden = true
            photoWrapper.isHidden = true
            photoTapOverlay?.isHidden = true
            fieldCode.isHidden = false
            buttonConfirm.isHidden = false
            confirmWrapper.isHidden = false
            confirmTapOverlay?.isHidden = false
        case .success:
            labelStatus.text = "Verificação concluída."
            labelDestination.isHidden = true
            buttonPhoto.isHidden = true
            photoWrapper.isHidden = true
            fieldCode.isHidden = true
            buttonConfirm.isHidden = true
            confirmWrapper.isHidden = true
        }
    }

    private func startSession() {
        maskedDestinationFromPhoto = nil
        Task { @MainActor in
            do {
                let (id, _, maskedE, maskedP) = try await api.createSession(userId: config.userId, email: config.email, phone: config.phone)
                sessionId = id
                maskedEmail = maskedE
                maskedPhone = maskedP
                step = .takePhoto(sessionId: id)
                updateUI()
            } catch {
                labelStatus.text = "Erro ao criar sessão: \(error.localizedDescription)"
                step = .takePhoto(sessionId: "")
                updateUI()
            }
        }
    }

    @objc private func sendPhotoTapped() {
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.pickOrTakePhoto() }
                    else { self?.labelStatus.text = "Permita acesso à câmera nas configurações." }
                }
            }
            return
        }
        pickOrTakePhoto()
    }

    private func pickOrTakePhoto() {
        let alert = UIAlertController(title: "Foto", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Câmera", style: .default) { [weak self] _ in self?.openCamera() })
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = buttonPhoto
            popover.sourceRect = buttonPhoto.bounds
        }
        present(alert, animated: true)
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

    private func openPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    private func uploadPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        labelStatus.text = "Enviando foto..."
        buttonPhoto.isEnabled = false
        Task { @MainActor in
            do {
                maskedDestinationFromPhoto = try await api.uploadPhoto(sessionId: sessionId, imageData: data)
                step = .enterCode(sessionId: sessionId)
                updateUI()
            } catch {
                labelStatus.text = "Erro: \(error.localizedDescription)"
            }
            buttonPhoto.isEnabled = true
        }
    }

    @objc private func confirmTapped() {
        let code = (fieldCode.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 6 else {
            labelStatus.text = "Digite o código de 6 dígitos."
            return
        }
        buttonConfirm.isEnabled = false
        labelStatus.text = "Verificando..."
        Task { @MainActor in
            do {
                try await api.confirmCode(sessionId: sessionId, code: String(code.prefix(6)))
                step = .success
                updateUI()
                dismiss(animated: true) { [weak self] in self?.completion(.success) }
            } catch {
                labelStatus.text = "Erro: \(error.localizedDescription)"
                buttonConfirm.isEnabled = true
            }
        }
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

private final class CodeFieldDelegate: NSObject, UITextFieldDelegate {
    let maxDigits: Int
    init(maxDigits: Int) { self.maxDigits = maxDigits }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard string.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) else { return false }
        let current = (textField.text ?? "") as NSString
        let result = current.replacingCharacters(in: range, with: string)
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
