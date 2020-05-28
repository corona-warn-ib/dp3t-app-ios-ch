/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

import DP3TSDK

class DatabaseSyncer {
    static var shared: DatabaseSyncer {
        TracingManager.shared.databaseSyncer
    }

    private var databaseSyncInterval: TimeInterval = 10

    func performFetch(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        syncDatabaseIfNeeded(completionHandler: completionHandler)
    }

    func syncDatabaseIfNeeded(completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        guard !databaseIsSyncing,
            UserStorage.shared.hasCompletedOnboarding else {
            completionHandler?(.noData)
            return
        }

        /*if lastDatabaseSync == nil || -(lastDatabaseSync!.timeIntervalSinceNow) > databaseSyncInterval {
            syncDatabase(completionHandler: completionHandler)
        }*/
    }

    func forceSyncDatabase() {
        syncDatabase(completionHandler: nil)
    }

    @UBOptionalUserDefault(key: "lastDatabaseSync") private var lastDatabaseSync: Date?
    private var databaseIsSyncing = false

    private func syncDatabase(completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        databaseIsSyncing = true
        let taskIdentifier = UIApplication.shared.beginBackgroundTask {
            // can't stop sync
        }
        Logger.log("Start Database Sync", appState: true)
        DP3TTracing.sync { result in
            switch result {
            case let .failure(e):

                // 3 kinds of errors with different behaviour
                // - network, things that happen on mobile -> only show error if not recovered for 24h
                // - time inconsitency error -> detected during sync, but actually a tracing problem
                // - unexpected errors -> immediately show, backend could  be broken
                UIStateManager.shared.blockUpdate {
                    UIStateManager.shared.syncError = e
                    if case let DP3TTracingError.networkingError(wrappedError) = e {
                        switch wrappedError {
                        case .timeInconsistency:
                            UIStateManager.shared.hasTimeInconsistencyError = true
                        default:
                            break
                        }
                        UIStateManager.shared.lastSyncErrorTime = Date()
                        switch wrappedError {
                        case let DP3TNetworkingError.networkSessionError(netErr as NSError) where netErr.code == -999 && netErr.domain == NSURLErrorDomain:
                            UIStateManager.shared.immediatelyShowSyncError = false
                            UIStateManager.shared.syncErrorIsNetworkError = true
                        case DP3TNetworkingError.networkSessionError:
                            UIStateManager.shared.immediatelyShowSyncError = false
                            UIStateManager.shared.syncErrorIsNetworkError = true
                        default:
                            UIStateManager.shared.immediatelyShowSyncError = true
                            UIStateManager.shared.syncErrorIsNetworkError = false
                        }

                    } else {
                        UIStateManager.shared.immediatelyShowSyncError = true
                        UIStateManager.shared.syncErrorIsNetworkError = false
                    }
                }

                Logger.log("Sync Database failed, \(e)")

                completionHandler?(.failed)
            case .success:

                // reset errors in UI
                UIStateManager.shared.blockUpdate {
                    self.lastDatabaseSync = Date()
                    UIStateManager.shared.firstSyncErrorTime = nil
                    UIStateManager.shared.lastSyncErrorTime = nil
                    UIStateManager.shared.hasTimeInconsistencyError = false
                    UIStateManager.shared.immediatelyShowSyncError = false
                }

                // wait another 2 days befor warning
                TracingLocalPush.shared.resetSyncWarningTriggers()

                // reload status, user could have been exposed
                TracingManager.shared.updateStatus(completion: nil)

                completionHandler?(.newData)
            }
            if taskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
            }
            self.databaseIsSyncing = false
        }
    }
}
