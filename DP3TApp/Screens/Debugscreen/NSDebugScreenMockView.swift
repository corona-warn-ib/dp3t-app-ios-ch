/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

#if ENABLE_TESTING

    import SnapKit
    import UIKit

    class NSDebugScreenMockView: NSSimpleModuleBaseView {
        private let stackView = UIStackView()

        private let checkboxes = [NSCheckBoxView(text: "debug_state_setting_option_none".ub_localized), NSCheckBoxView(text: "debug_state_setting_option_ok".ub_localized), NSCheckBoxView(text: "debug_state_setting_option_exposed".ub_localized), NSCheckBoxView(text: "debug_state_setting_option_infected".ub_localized)]

        // MARK: - Init

        init() {
            super.init(title: "debug_state_setting_title".ub_localized)
            setup()
            #if ENABLE_STATUS_OVERRIDE
                UIStateManager.shared.addObserver(self) { [weak self] stateModel in
                    guard let strongSelf = self else { return }
                    strongSelf.update(stateModel)
                }
            #endif
        }

        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func setup() {
            contentView.spacing = NSPadding.small

            let label = NSLabel(.textLight)
            label.text = "debug_state_setting_text".ub_localized

            contentView.addArrangedView(label)

            let checkBoxStackView = UIStackView()
            checkBoxStackView.spacing = NSPadding.small
            checkBoxStackView.axis = .vertical

            for c in checkboxes {
                checkBoxStackView.addArrangedView(c)
                c.radioMode = true
                c.touchUpCallback = { [weak self, weak c] in
                    guard let strongSelf = self, let strongC = c else { return }
                    strongSelf.select(strongC)
                }
            }

            let cbc = UIView()
            cbc.addSubview(checkBoxStackView)

            checkBoxStackView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0.0, left: NSPadding.medium + NSPadding.small, bottom: 0.0, right: NSPadding.medium))
            }

            contentView.addArrangedView(cbc)
        }

        // MARK: - Logic

        #if ENABLE_STATUS_OVERRIDE
            private func select(_ checkBox: NSCheckBoxView) {
                let stateManager = UIStateManager.shared

                if let index = checkboxes.firstIndex(of: checkBox) {
                    switch index {
                    case 1:
                        stateManager.overwrittenInfectionState = .healthy
                    case 2:
                        stateManager.overwrittenInfectionState = .exposed
                    case 3:
                        stateManager.overwrittenInfectionState = .infected
                    default:
                        stateManager.overwrittenInfectionState = nil
                    }
                }
            }

            private func update(_ stateModel: UIStateModel) {
                // only set once because it's animated
                let status = stateModel.debug.overwrittenInfectionState
                checkboxes[0].isChecked = status == nil

                if let s = status {
                    checkboxes[1].isChecked = s == .healthy
                    checkboxes[2].isChecked = s == .exposed
                    checkboxes[3].isChecked = s == .infected
                } else {
                    checkboxes[1].isChecked = false
                    checkboxes[2].isChecked = false
                    checkboxes[3].isChecked = false
                }
            }
        #endif
    }

#endif
