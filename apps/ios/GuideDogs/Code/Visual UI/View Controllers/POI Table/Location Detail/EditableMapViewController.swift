//
//  EditableMapViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import MapKit

class EditableMapViewController: UIViewController {
    
    private let mapView = MKMapView()
    private let annotationImageView = UIImageView(image: UIImage(named: "baseline_place_red_36pt"))
    private let label = UILabel()
    
    // MARK: Properties
    
    weak var delegate: EditableMapViewControllerDelegate?
    var locationDetail: LocationDetail?
    private var isReconfiguringView = false
    
    // MARK: View Life Cycle
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(named: "Background Base")

        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = UIColor(named: "Background Base")

        let hint = UIView()
        hint.backgroundColor = UIColor(named: "Excluded")
        label.translatesAutoresizingMaskIntoConstraints = false
        hint.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: hint.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: hint.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: hint.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: hint.bottomAnchor, constant: -8)
        ])

        mapView.delegate = self
        mapView.showsUserLocation = true
        let stack = UIStackView(arrangedSubviews: [hint, mapView])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        annotationImageView.isHidden = true
        annotationImageView.contentMode = .scaleAspectFit
        annotationImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(annotationImageView)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            annotationImageView.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            annotationImageView.bottomAnchor.constraint(equalTo: mapView.centerYAnchor),
            annotationImageView.widthAnchor.constraint(equalToConstant: 36),
            annotationImageView.heightAnchor.constraint(equalToConstant: 36)
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: GDLocalizedString("general.alert.cancel"), style: .plain,
            target: self, action: #selector(onLeftBarButtonItemSelected)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: GDLocalizedString("general.alert.edit"), style: .plain,
            target: self, action: #selector(onRightBarButtonItemSelected)
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Use default iOS styling
        navigationController?.navigationBar.configureAppearance(for: .default)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Use default iOS styling
        navigationController?.navigationBar.configureAppearance(for: .default)
        
        if let detail = locationDetail {
            // Configure text and buttons for viewing a location
            configureForViewLocation(detail: detail)
            
            // If we are defaulting to edit view, then set the flag to set up edit mode as soon as the map loads it's initial position
            if let delegate = delegate, delegate.defaultToEditMode {
                self.isReconfiguringView = true
            }
            
            // Center the region at the given annotation
            self.mapView.setCenter(detail.centerLocation.coordinate, animated: true)
        } else {
            // `locationDetail` should not be `nil`
            mapView.configureEmptyMapView()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Reset styling
        navigationController?.navigationBar.configureAppearance(for: .default)
    }
    
    // MARK: `MapKit`
    
    private func configureForViewLocation(detail: LocationDetail) {
        // Update title and hint text
        self.navigationItem.title = GDLocalizedString("location_detail.map.view.title")
        self.label.text = GDLocalizedString("location_detail.map.view.hint")
        
        // Add "Edit" button
        self.navigationItem.rightBarButtonItem?.title = GDLocalizedString("general.alert.edit")
        self.navigationItem.rightBarButtonItem?.style = .plain
        
        // Hide fixed annotation image view
        self.annotationImageView.isHidden = true
        
        // Add an annotation at the given location
        let annotation = LocationDetailAnnotation(detail: detail)
        self.mapView.addAnnotation(annotation)
        
        // Adjust the map region to display the given annotation
        self.mapView.showAnnotations([annotation], animated: true)
    }
    
    private func configureForEditLocation() {
        // Update title and hint text
        self.navigationItem.title = GDLocalizedString("location_detail.map.edit.title")
        self.label.text = GDLocalizedString("location_detail.map.edit.hint")
        
        // Add "Done" button
        self.navigationItem.rightBarButtonItem?.title = GDLocalizedString("general.alert.done")
        self.navigationItem.rightBarButtonItem?.style = .done
        
        // If necessary, remove previous annotations
        self.mapView.removeAllAnnotations()
        
        // Show fixed annotation image view
        self.annotationImageView.isHidden = false
    }
    
    // MARK: `IBAction`
    
    @objc func onLeftBarButtonItemSelected(_ sender: Any) {
        // `Cancel` selected
        // Dismiss view
        dismiss(animated: true, completion: nil)
    }
    
    @objc func onRightBarButtonItemSelected(_ sender: Any) {
        guard let sender = sender as? UIBarButtonItem else {
            return
        }
        
        guard let detail = self.locationDetail else {
            // `locationDetail` should not be `nil`
            return
        }
        
        if sender.style == .done {
            // `Done` selected
            // Selected location is at the center of the map
            let newLocation = CLLocation(mapView.centerCoordinate)
            
            if newLocation.coordinate != detail.centerLocation.coordinate {
                // Notify the delegate
                delegate?.viewController(self, didUpdateLocation: LocationDetail(detail, withUpdatedLocation: newLocation))
            }
            
            // Dismiss view
            dismiss(animated: true, completion: nil)
        } else {
            // `Edit` selected
            if detail.centerLocation.coordinate == mapView.centerCoordinate {
                // Map region is centered at the given location
                // Immediately configure the view
                configureForEditLocation()
            } else {
                self.isReconfiguringView = true
                
                // Adjust map region to place the given location at the center
                //
                // After map rendering is complete, reconfigure the view to support
                // editing (see `func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
                self.mapView.setCenter(detail.centerLocation.coordinate, animated: true)
            }
        }
    }
    
}

extension EditableMapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? LocationDetailAnnotation else {
            return nil
        }
        
        return self.mapView(mapView, viewForLocationDetailAnnotation: annotation)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard isReconfiguringView else {
            // Return if we are not reconfiguring the view to edit
            return
        }
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5) { [weak self] in
                guard let `self` = self else {
                    return
                }
                
                // Configure text and buttons for editing a location
                self.configureForEditLocation()
                
                // Update statue
                self.isReconfiguringView = false
            }
        }
    }
    
}
