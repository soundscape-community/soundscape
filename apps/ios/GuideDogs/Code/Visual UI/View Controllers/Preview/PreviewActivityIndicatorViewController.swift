//
//  PreviewActivityIndicatorViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

class PreviewActivityIndicatorViewController: UIViewController {
    
    enum State {
        case activating(progress: Progress?)
        case deactivating
        
        var localizedString: String {
            switch self {
            case .activating: return GDLocalizedString("general.loading.start")
            case .deactivating: return GDLocalizedString("general.loading.end")
            }
        }
    }
    
    // MARK: Properties

    private let imageView = UIImageView()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressViewLabel = UILabel()
    
    private var token: NSKeyValueObservation?
    
    var state: State = .activating(progress: nil) {
        didSet {
            guard isViewLoaded else {
                return
            }
            
            configureView(for: state)
        }
    }
    
    // MARK: View Life Cycle

    override func loadView() {
        let view = UIView()
        view.backgroundColor = Colors.Background.tertiary
        view.accLabelLocalization = "general.loading.no_punctuation"

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 48
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        imageView.contentMode = .scaleAspectFit
        imageView.adjustsImageSizeForAccessibilityContentSizeCategory = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        progressView.progressTintColor = Colors.Highlight.yellow

        progressViewLabel.accessibilityIdentifier = "label.getting_things_ready"
        progressViewLabel.textAlignment = .center
        progressViewLabel.numberOfLines = 0
        progressViewLabel.adjustsFontForContentSizeCategory = true
        progressViewLabel.font = .preferredFont(forTextStyle: .footnote)
        progressViewLabel.textColor = Colors.Highlight.yellow

        let progressStack = UIStackView(arrangedSubviews: [progressView, progressViewLabel])
        progressStack.axis = .vertical
        progressStack.spacing = 16

        contentStack.addArrangedSubview(imageView)
        contentStack.addArrangedSubview(progressStack)
        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 102),
            contentStack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(greaterThanOrEqualTo: contentStack.bottomAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(greaterThanOrEqualTo: contentStack.trailingAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 64),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: progressView.trailingAnchor, constant: 64)
        ])

        self.view = view
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Initialize image view
        imageView.image = UIImage(named: "travel1")!
        // Initialize image view animations
        imageView.animationDuration = 1.0
        imageView.animationImages = [
            UIImage(named: "travel2")!,
            UIImage(named: "travel3")!,
            UIImage(named: "travel4")!,
            UIImage(named: "travel5")!
        ]
        
        // Start animations
        imageView.startAnimating()
        
        // Configure progress view
        configureView(for: state)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop animations
        imageView.stopAnimating()
        
        // Stop observing updates
        token?.invalidate()
        token = nil
    }
    
    private func configureView(for state: State) {
        progressViewLabel.text = state.localizedString
        
        if case .activating(let aProgress) = state, let progress = aProgress {
            // Show `progressView`
            progressView.progress = Float(progress.fractionCompleted)
            progressView.isHidden = false
            
            // Start observing progress updates
            token = progress.observe(\.completedUnitCount, changeHandler: { (progress, _) in
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    
                    self.progressView.progress = Float(progress.fractionCompleted)
                }
            })
        } else {
            // Stop observing updates
            token?.invalidate()
            token = nil
            
            // Hide the progress view when there are
            // no updates
            progressView.isHidden = true
        }
    }
    
}
