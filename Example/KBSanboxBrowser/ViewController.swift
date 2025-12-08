//
//  ViewController.swift
//  KBSanboxBrowser
//
//  Created by kimball on 12/08/2025.
//  Copyright (c) 2025 kimball. All rights reserved.
//

import UIKit
import KBSanboxBrowser

class ViewController: UIViewController {

    let statusLabel = UILabel()
    let toggleButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    func setupUI() {
        // Configure status label
        statusLabel.text = "Server Stopped"
        statusLabel.textColor = .black
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Configure toggle button
        toggleButton.setTitle("Start Server", for: .normal)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.addTarget(self, action: #selector(toggleServer), for: .touchUpInside)
        view.addSubview(toggleButton)
        
        // Setup Auto Layout constraints
        NSLayoutConstraint.activate([
            // Status Label constraints
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Toggle Button constraints
            toggleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toggleButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 50),
            toggleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            toggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            toggleButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc func toggleServer() {
        if toggleButton.title(for: .normal) == "Start Server" {
            KBSandboxBrowser.shared.start()
            if let url = KBSandboxBrowser.shared.serverURL {
                statusLabel.text = "Server Started at:\n\(url.absoluteString)"
            } else {
                statusLabel.text = "Server Started (URL unknown)"
            }
            toggleButton.setTitle("Stop Server", for: .normal)
        } else {
            KBSandboxBrowser.shared.stop()
            statusLabel.text = "Server Stopped"
            toggleButton.setTitle("Start Server", for: .normal)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

