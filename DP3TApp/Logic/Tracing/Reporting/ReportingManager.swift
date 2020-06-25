/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import DP3TSDK

import Foundation

class ReportingManager {
    // MARK: - Shared

    static let shared = ReportingManager()

    // MARK: - Init

    private init() {}

    // MARK: - Variables

    enum ReportingProblem {
        case failure(error: CodedError)
        case invalidCode
    }

    // in memory dictionary for codes we already have a token and date,
    // if only the second request (iWasExposed) fails
    private var codeDictionary: [String: (String, Date)] = [:]

    let codeValidator = CodeValidator()

    // MARK: - API

    private static var fakeCode: String {
        String(Int.random(in: 100_000_000_000 ... 999_999_999_999))
    }

    func report(covidCode: String = ReportingManager.fakeCode, isFakeRequest fake: Bool = false, completion: @escaping (ReportingProblem?) -> Void) {
        if let tokenDate = codeDictionary[covidCode] {
            // only second part needed
            sendIWasExposed(token: tokenDate.0, date: tokenDate.1, isFakeRequest: fake, covidCode: covidCode, completion: completion)
        } else {
            // get token and date first
            codeValidator.sendCodeRequest(code: covidCode, isFakeRequest: fake) { [weak self] result in
                guard let strongSelf = self else { return }

                switch result {
                case let .success(token: token, date: date):
                    // save in code dictionary
                    strongSelf.codeDictionary[covidCode] = (token, date)

                    // second part
                    strongSelf.sendIWasExposed(token: token, date: date, isFakeRequest: fake, covidCode: covidCode, completion: completion)
                case let .failure(error: error):
                    completion(.failure(error: error))
                case .invalidTokenError:
                    completion(.invalidCode)
                }
            }
        }
    }

    // MARK: - Second part: I was exposed

    private func sendIWasExposed(token: String, date: Date, isFakeRequest fake: Bool, covidCode: String, completion: @escaping (ReportingProblem?) -> Void) {
        DP3TTracing.iWasExposed(onset: date, authentication: .HTTPAuthorizationBearer(token: token), isFakeRequest: fake) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.codeDictionary.removeValue(forKey: covidCode)
                switch result {
                case .success:
                    if !fake {
                        // during infection, tracing is disabled
                        // after infection, it works again, but user must manually
                        // enable if desired
                        TracingManager.shared.isActivated = false
                    }

                    TracingManager.shared.updateStatus(shouldSync: false) { error in
                        if let error = error {
                            completion(.failure(error: error))
                        } else {
                            completion(nil)
                        }
                    }
                case let .failure(error):
                    completion(.failure(error: error))
                }
            }
        }
    }
}
