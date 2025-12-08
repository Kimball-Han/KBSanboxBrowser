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
        statusLabel.text = "Server Stopped"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 100)
        
        statusLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyServerURL))
        statusLabel.addGestureRecognizer(tapGesture)
        
        view.addSubview(statusLabel)
        
        toggleButton.setTitle("Start Server", for: .normal)
        toggleButton.frame = CGRect(x: 100, y: 250, width: view.bounds.width - 200, height: 50)
        toggleButton.addTarget(self, action: #selector(toggleServer), for: .touchUpInside)
        view.addSubview(toggleButton)
    }
    
    @objc func copyServerURL() {
        guard let url = KBSandboxBrowser.shared.serverURL?.absoluteString else { return }
        UIPasteboard.general.string = url
        
        let alert = UIAlertController(title: "Copied", message: "Server URL copied to clipboard:\n\(url)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
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

