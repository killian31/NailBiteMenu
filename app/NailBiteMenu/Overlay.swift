import AppKit
import QuartzCore

final class Overlay {
    private static var window: NSWindow?
    private static weak var countdownLabel: NSTextField?
    private static var autoDismissTask: DispatchWorkItem?
    private static var countdownTimer: Timer?
    private static var keyMonitor: Any?
    private static let autoDismissInterval: TimeInterval = 3

    static func show(message: String) {
        DispatchQueue.main.async {
            guard let screen = NSScreen.main else { return }

            dismiss()

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.55)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false

            let container = NSView(frame: screen.frame)
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor

            let card = NSVisualEffectView()
            card.translatesAutoresizingMaskIntoConstraints = false
            card.material = .hudWindow
            card.blendingMode = .withinWindow
            card.state = .active
            card.wantsLayer = true
            card.layer?.cornerRadius = 32
            card.layer?.borderColor = NSColor.white.withAlphaComponent(0.06).cgColor
            card.layer?.borderWidth = 1
            card.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
            card.layer?.shadowOpacity = 1
            card.layer?.shadowRadius = 22
            card.layer?.shadowOffset = CGSize(width: 0, height: 18)

            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 18
            stack.translatesAutoresizingMaskIntoConstraints = false

            let (titleText, detailText) = split(message: message)

            let iconContainer = NSView()
            iconContainer.wantsLayer = true
            iconContainer.translatesAutoresizingMaskIntoConstraints = false
            iconContainer.layer?.cornerRadius = 22
            iconContainer.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.25).cgColor
            iconContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
            iconContainer.layer?.borderWidth = 1
            let iconImage = NSImageView(image: NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil) ?? NSImage())
            iconImage.contentTintColor = .white
            iconImage.translatesAutoresizingMaskIntoConstraints = false
            iconImage.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
            iconContainer.addSubview(iconImage)

            NSLayoutConstraint.activate([
                iconContainer.widthAnchor.constraint(equalToConstant: 64),
                iconContainer.heightAnchor.constraint(equalToConstant: 64),
                iconImage.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
                iconImage.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
            ])

            let titleLabel = NSTextField(labelWithString: titleText)
            titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
            titleLabel.textColor = .white
            titleLabel.alignment = .center
            titleLabel.lineBreakMode = .byWordWrapping
            titleLabel.maximumNumberOfLines = 2

            let detailLabel = NSTextField(labelWithString: detailText)
            detailLabel.font = .systemFont(ofSize: 18, weight: .medium)
            detailLabel.textColor = NSColor.white.withAlphaComponent(0.85)
            detailLabel.alignment = .center
            detailLabel.lineBreakMode = .byWordWrapping
            detailLabel.maximumNumberOfLines = 2

            let countdownLabel = NSTextField(labelWithString: "Dismisses in 3s")
            countdownLabel.font = .systemFont(ofSize: 13, weight: .regular)
            countdownLabel.textColor = NSColor.white.withAlphaComponent(0.75)
            countdownLabel.alignment = .center

            let button = OverlayButton(title: "Stay mindful", target: self, action: #selector(dismiss))
            button.translatesAutoresizingMaskIntoConstraints = false
            button.keyEquivalent = "\r"
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true

            stack.addArrangedSubview(iconContainer)
            stack.addArrangedSubview(titleLabel)
            if !detailText.isEmpty {
                stack.addArrangedSubview(detailLabel)
            }
            stack.addArrangedSubview(countdownLabel)
            stack.addArrangedSubview(button)

            card.addSubview(stack)
            container.addSubview(card)

            NSLayoutConstraint.activate([
                card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                card.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
                card.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),

                stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
                stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
                stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
                stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28)
            ])

            window.contentView = container
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()

            self.window = window
            self.countdownLabel = countdownLabel
            self.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 36 {
                    dismiss()
                    return nil
                }
                return event
            }
            scheduleAutoDismiss()
        }
    }

    @objc static func dismiss() {
        if Thread.isMainThread {
            performDismiss()
        } else {
            DispatchQueue.main.async {
                performDismiss()
            }
        }
    }

    private static func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        countdownTimer?.invalidate()

        var remaining = Int(autoDismissInterval)
        updateCountdownLabel(with: remaining)

        let task = DispatchWorkItem {
            dismiss()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissInterval, execute: task)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            remaining -= 1
            if remaining > 0 {
                updateCountdownLabel(with: remaining)
            } else {
                timer.invalidate()
            }
        }
        if let timer = countdownTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private static func updateCountdownLabel(with seconds: Int) {
        countdownLabel?.stringValue = "Dismisses in \(seconds)s"
    }

    private static func split(message: String) -> (String, String) {
        let parts = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let title = parts.first.map(String.init) ?? message
        let detail = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return (title, detail)
    }

    private static func performDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownLabel = nil

        window?.orderOut(nil)
        window = nil
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

private final class OverlayButton: NSButton {
    private let gradientLayer = CAGradientLayer()
    private let highlightLayer = CALayer()

    override var wantsUpdateLayer: Bool { true }

    init(title: String, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.title = ""
        self.target = target
        self.action = action
        self.isBordered = false
        focusRingType = .none
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
            .kern: 0.4
        ]
        attributedTitle = NSAttributedString(string: title.uppercased(), attributes: attributes)
        font = .systemFont(ofSize: 17, weight: .semibold)
        contentTintColor = .white
        alignment = .center
        wantsLayer = true
        let baseLayer = CALayer()
        baseLayer.masksToBounds = false
        baseLayer.cornerRadius = 18
        baseLayer.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        baseLayer.shadowOpacity = 1
        baseLayer.shadowRadius = 12
        baseLayer.shadowOffset = CGSize(width: 0, height: 6)
        layer = baseLayer
        setupGradient()
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        let baseLayer = CALayer()
        baseLayer.masksToBounds = false
        baseLayer.cornerRadius = 18
        baseLayer.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        baseLayer.shadowOpacity = 1
        baseLayer.shadowRadius = 12
        baseLayer.shadowOffset = CGSize(width: 0, height: 6)
        layer = baseLayer
        setupGradient()
    }

    private func setupGradient() {
        guard let layer = layer else { return }
        gradientLayer.colors = [
            NSColor.systemPink.withAlphaComponent(0.9).cgColor,
            NSColor.systemBlue.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = layer.cornerRadius

        highlightLayer.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        highlightLayer.opacity = 0
        highlightLayer.cornerRadius = layer.cornerRadius

        layer.backgroundColor = NSColor.clear.cgColor
        if gradientLayer.superlayer == nil {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        if highlightLayer.superlayer == nil {
            layer.insertSublayer(highlightLayer, above: gradientLayer)
        }
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
        highlightLayer.frame = bounds
    }

    override func updateLayer() {
        super.updateLayer()
        highlightLayer.opacity = isHighlighted ? 0.35 : 0
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: base.width + 40, height: max(44, base.height + 14))
    }
}
