/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import SnapKit
import UIKit

class NSViewController: UIViewController {
    // MARK: - Views

    private let loadingView = NSLoadingView()
    private let swissFlagImage = UIImage(named: "ic_navbar_schweiz_wappen")?.withRenderingMode(.alwaysOriginal)

    // MARK: - Public API

    public func startLoading() {
        view.bringSubviewToFront(loadingView)
        loadingView.startLoading()
    }

    public func stopLoading(error: CodedError? = nil, reloadHandler: (() -> Void)? = nil) {
        loadingView.stopLoading(error: error, reloadHandler: reloadHandler)
    }

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "unavailable")
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.ns_background

        setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.backBarButtonItem = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)
        if navigationController?.viewControllers.count == 1 {
            let imgv = UIImageView(image: swissFlagImage)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: imgv)
            #if ENABLE_TESTING
                imgv.isUserInteractionEnabled = true
                let tr = UITapGestureRecognizer(target: self, action: #selector(swissFlagTouched))
                tr.numberOfTapsRequired = 3
                imgv.addGestureRecognizer(tr)
            #endif
        }
    }

    #if ENABLE_TESTING
        @objc func swissFlagTouched() {
            let alert = UIAlertController(title: "DEBUG FUNKTIONEN", message: "Zum Testen der App", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Test Meldung", style: .default, handler: { _ in
                let task = UIApplication.shared.beginBackgroundTask(expirationHandler: {})
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    UIStateManager.shared.overwrittenInfectionState = .exposed
                    TracingLocalPush.shared.exposureIdentifiers = [UUID().uuidString]
                    UIApplication.shared.endBackgroundTask(task)
                }
            }))

            alert.addAction(UIAlertAction(title: "Debug Screen", style: .default, handler: { _ in
                self.navigationController?.pushViewController(NSDebugscreenViewController(), animated: true)
            }))

            alert.addAction(UIAlertAction(title: "Upload Database", style: .default, handler: { _ in
                self.uploadDatabaseForDebugPurposes()
            }))

            alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel, handler: nil))

            present(alert, animated: true, completion: nil)
        }

        private let uploadHelper = NSDebugDatabaseUploadHelper()
        private func uploadDatabaseForDebugPurposes() {
            let alert = UIAlertController(title: "Username", message: nil, preferredStyle: .alert)
            alert.addTextField { $0.text = "" }
            alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [weak alert, weak self] _ in
                let username = alert?.textFields?.first?.text ?? ""
                self?.uploadDB(with: username)
        }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }

        private func uploadDB(with username: String) {
            let loading = UIAlertController(title: "Uploading...", message: "Please wait", preferredStyle: .alert)
            present(loading, animated: true)

            uploadHelper.uploadDatabase(username: username) { result in
                let alert: UIAlertController
                switch result {
                case .success:
                    alert = UIAlertController(title: "Upload successful", message: nil, preferredStyle: .alert)
                case let .failure(error):
                    alert = UIAlertController(title: "Upload failed", message: error.message, preferredStyle: .alert)
                }

                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                loading.dismiss(animated: false) {
                    self.present(alert, animated: false)
                }
            }
        }

    #endif

    // MARK: - Setup

    private func setup() {
        view.addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
