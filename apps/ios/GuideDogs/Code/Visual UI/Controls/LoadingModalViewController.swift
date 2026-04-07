//
//  LoadingModalViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

class LoadingModalViewController: UIViewController {
    var loadingMessage: String = GDLocalizedString("general.loading.loading") {
        didSet {
            loadingMessageLabel.text = loadingMessage
            activityIndicatorView.accessibilityLabel = loadingMessage
        }
    }

    private let activityIndicatorView: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = Colors.Foreground.primary
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private let loadingMessageLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.isAccessibilityElement = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = Colors.Foreground.primary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(loadingMessage: String = GDLocalizedString("general.loading.loading")) {
        self.loadingMessage = loadingMessage
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LoadingModalViewController must be created programmatically.")
    }

    override func loadView() {
        let view = UIView()
        view.backgroundColor = UIColor(named: "Background Shadow")
        view.addSubview(activityIndicatorView)
        view.addSubview(loadingMessageLabel)

        NSLayoutConstraint.activate([
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingMessageLabel.topAnchor.constraint(equalTo: activityIndicatorView.bottomAnchor),
            loadingMessageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingMessageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingMessageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        loadingMessageLabel.text = loadingMessage
        activityIndicatorView.accessibilityLabel = loadingMessage
    }
}
