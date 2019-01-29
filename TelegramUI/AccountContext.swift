import Foundation
import SwiftSignalKit
import UIKit
import Postbox
import TelegramCore
import Display

public final class TelegramApplicationOpenUrlCompletion {
    public let completion: (Bool) -> Void
    
    public init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
}

public final class TelegramApplicationBindings {
    public let isMainApp: Bool
    public let containerPath: String
    public let appSpecificScheme: String
    public let openUrl: (String) -> Void
    public let openUniversalUrl: (String, TelegramApplicationOpenUrlCompletion) -> Void
    public let canOpenUrl: (String) -> Bool
    public let getTopWindow: () -> UIWindow?
    public let displayNotification: (String) -> Void
    public let applicationInForeground: Signal<Bool, NoError>
    public let applicationIsActive: Signal<Bool, NoError>
    public let clearMessageNotifications: ([MessageId]) -> Void
    public let pushIdleTimerExtension: () -> Disposable
    public let openSettings: () -> Void
    public let openAppStorePage: () -> Void
    public let registerForNotifications: (@escaping (Bool) -> Void) -> Void
    public let requestSiriAuthorization: (@escaping (Bool) -> Void) -> Void
    public let siriAuthorization: () -> AccessType
    public let getWindowHost: () -> WindowHost?
    public let presentNativeController: (UIViewController) -> Void
    public let dismissNativeController: () -> Void
    
    public init(isMainApp: Bool, containerPath: String, appSpecificScheme: String, openUrl: @escaping (String) -> Void, openUniversalUrl: @escaping (String, TelegramApplicationOpenUrlCompletion) -> Void, canOpenUrl: @escaping (String) -> Bool, getTopWindow: @escaping () -> UIWindow?, displayNotification: @escaping (String) -> Void, applicationInForeground: Signal<Bool, NoError>, applicationIsActive: Signal<Bool, NoError>, clearMessageNotifications: @escaping ([MessageId]) -> Void, pushIdleTimerExtension: @escaping () -> Disposable, openSettings: @escaping () -> Void, openAppStorePage: @escaping () -> Void, registerForNotifications: @escaping (@escaping (Bool) -> Void) -> Void, requestSiriAuthorization: @escaping (@escaping (Bool) -> Void) -> Void, siriAuthorization: @escaping () -> AccessType, getWindowHost: @escaping () -> WindowHost?, presentNativeController: @escaping (UIViewController) -> Void, dismissNativeController: @escaping () -> Void) {
        self.isMainApp = isMainApp
        self.containerPath = containerPath
        self.appSpecificScheme = appSpecificScheme
        self.openUrl = openUrl
        self.openUniversalUrl = openUniversalUrl
        self.canOpenUrl = canOpenUrl
        self.getTopWindow = getTopWindow
        self.displayNotification = displayNotification
        self.applicationInForeground = applicationInForeground
        self.applicationIsActive = applicationIsActive
        self.clearMessageNotifications = clearMessageNotifications
        self.pushIdleTimerExtension = pushIdleTimerExtension
        self.openSettings = openSettings
        self.openAppStorePage = openAppStorePage
        self.registerForNotifications = registerForNotifications
        self.requestSiriAuthorization = requestSiriAuthorization
        self.siriAuthorization = siriAuthorization
        self.presentNativeController = presentNativeController
        self.dismissNativeController = dismissNativeController
        self.getWindowHost = getWindowHost
    }
}

public final class AccountContext {
    public let sharedContext: SharedAccountContext
    public let account: Account
    
    public let fetchManager: FetchManager
    public var callManager: PresentationCallManager?
    
    public var keyShortcutsController: KeyShortcutsController?
    
    let downloadedMediaStoreManager: DownloadedMediaStoreManager
    
    public let liveLocationManager: LiveLocationManager?
    
    let peerChannelMemberCategoriesContextsManager = PeerChannelMemberCategoriesContextsManager()
    
    public let currentPresentationData: Atomic<PresentationData>
    private let _presentationData = Promise<PresentationData>()
    public var presentationData: Signal<PresentationData, NoError> {
        return self._presentationData.get()
    }
    
    public let currentInAppNotificationSettings: Atomic<InAppNotificationSettings>
    private var inAppNotificationSettingsDisposable: Disposable?
    
    public let currentAutomaticMediaDownloadSettings: Atomic<AutomaticMediaDownloadSettings>
    private let _automaticMediaDownloadSettings = Promise<AutomaticMediaDownloadSettings>()
    public var automaticMediaDownloadSettings: Signal<AutomaticMediaDownloadSettings, NoError> {
        return self._automaticMediaDownloadSettings.get()
    }
    
    public let currentLimitsConfiguration: Atomic<LimitsConfiguration>
    private let _limitsConfiguration = Promise<LimitsConfiguration>()
    public var limitsConfiguration: Signal<LimitsConfiguration, NoError> {
        return self._limitsConfiguration.get()
    }
    
    public let currentMediaInputSettings: Atomic<MediaInputSettings>
    private var mediaInputSettingsDisposable: Disposable?
    
    private let presentationDataDisposable = MetaDisposable()
    private let automaticMediaDownloadSettingsDisposable = MetaDisposable()
    
    public var presentGlobalController: (ViewController, Any?) -> Void = { _, _ in
    }
    public var presentCrossfadeController: () -> Void = {}
    
    public var navigateToCurrentCall: (() -> Void)?
    public var hasOngoingCall: Signal<Bool, NoError>?
    private var immediateHasOngoingCallValue = Atomic<Bool>(value: false)
    public var immediateHasOngoingCall: Bool {
        return self.immediateHasOngoingCallValue.with { $0 }
    }
    private var hasOngoingCallDisposable: Disposable?
    
    public var watchManager: WatchManager?
    
    private var immediateExperimentalUISettingsValue = Atomic<ExperimentalUISettings>(value: ExperimentalUISettings.defaultSettings)
    public var immediateExperimentalUISettings: ExperimentalUISettings {
        return self.immediateExperimentalUISettingsValue.with { $0 }
    }
    private var experimentalUISettingsDisposable: Disposable?
    
    private var storedPassword: (String, CFAbsoluteTime, SwiftSignalKit.Timer)?
    
    public var isCurrent: Bool = false {
        didSet {
            if !self.isCurrent {
                self.callManager = nil
            }
        }
    }
    
    public init(sharedContext: SharedAccountContext, account: Account, initialPresentationDataAndSettings: InitialPresentationDataAndSettings) {
        self.sharedContext = sharedContext
        self.account = account
        
        self.downloadedMediaStoreManager = DownloadedMediaStoreManager(postbox: account.postbox, accountManager: sharedContext.accountManager)
        
        if let locationManager = self.sharedContext.locationManager {
            self.liveLocationManager = LiveLocationManager(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, viewTracker: account.viewTracker, stateManager: account.stateManager, locationManager: locationManager, inForeground: self.sharedContext.applicationBindings.applicationInForeground)
        } else {
            self.liveLocationManager = nil
        }
        self.fetchManager = FetchManager(postbox: account.postbox, storeManager: self.downloadedMediaStoreManager)
        self.currentPresentationData = Atomic(value: initialPresentationDataAndSettings.presentationData)
        self.currentAutomaticMediaDownloadSettings = Atomic(value: initialPresentationDataAndSettings.automaticMediaDownloadSettings)
        self.currentLimitsConfiguration = Atomic(value: initialPresentationDataAndSettings.limitsConfiguration)
        self.currentMediaInputSettings = Atomic(value: initialPresentationDataAndSettings.mediaInputSettings)
       
        self._presentationData.set(.single(initialPresentationDataAndSettings.presentationData)
        |> then(
            updatedPresentationData(accountManager: sharedContext.accountManager, postbox: account.postbox, applicationBindings: self.sharedContext.applicationBindings)
        ))
        self._automaticMediaDownloadSettings.set(.single(initialPresentationDataAndSettings.automaticMediaDownloadSettings)
        |> then(
            updatedAutomaticMediaDownloadSettings(accountManager: sharedContext.accountManager)
        ))
        
        self.currentInAppNotificationSettings = Atomic(value: initialPresentationDataAndSettings.inAppNotificationSettings)
        
        self.inAppNotificationSettingsDisposable = (sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                    let _ = strongSelf.currentInAppNotificationSettings.swap(settings)
                }
            }
        })
        
        self.mediaInputSettingsDisposable = (sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.mediaInputSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaInputSettings] as? MediaInputSettings {
                    let _ = strongSelf.currentMediaInputSettings.swap(settings)
                }
            }
        })
        
        self.presentationDataDisposable.set((self._presentationData.get()
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                var stringsUpdated = false
                var themeUpdated = false
                var themeNameUpdated = false
                let _ = strongSelf.currentPresentationData.modify { current in
                    if next.strings !== current.strings {
                        stringsUpdated = true
                    }
                    if next.theme !== current.theme {
                        themeUpdated = true
                    }
                    if next.theme.name != current.theme.name {
                        themeNameUpdated = true
                    }
                    return next
                }
                if stringsUpdated {
                    updateLegacyLocalization(strings: next.strings)
                }
                if themeUpdated {
                    updateLegacyTheme()
                }
                if themeNameUpdated {
                    strongSelf.presentCrossfadeController()
                }
            }
        }))
        
        self.automaticMediaDownloadSettingsDisposable.set(self._automaticMediaDownloadSettings.get().start(next: { [weak self] next in
            if let strongSelf = self {
                let _ = strongSelf.currentAutomaticMediaDownloadSettings.swap(next)
            }
        }))
        
        let immediateHasOngoingCallValue = self.immediateHasOngoingCallValue
        self.hasOngoingCallDisposable = self.hasOngoingCall?.start(next: { value in
            let _ = immediateHasOngoingCallValue.swap(value)
        })
        
        let immediateExperimentalUISettingsValue = self.immediateExperimentalUISettingsValue
        let _ = immediateExperimentalUISettingsValue.swap(initialPresentationDataAndSettings.experimentalUISettings)
        self.experimentalUISettingsDisposable = (sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings])
        |> deliverOnMainQueue).start(next: { sharedData in
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings] as? ExperimentalUISettings {
                let _ = immediateExperimentalUISettingsValue.swap(settings)
            }
        })
        
        let _ = self.sharedContext.contactDataManager?.personNameDisplayOrder().start(next: { order in
            let _ = updateContactSettingsInteractively(postbox: account.postbox, { settings in
                var settings = settings
                settings.nameDisplayOrder = order
                return settings
            }).start()
        })
    }
    
    deinit {
        self.presentationDataDisposable.dispose()
        self.automaticMediaDownloadSettingsDisposable.dispose()
        self.inAppNotificationSettingsDisposable?.dispose()
        self.mediaInputSettingsDisposable?.dispose()
    }
    
    public func attachOverlayMediaController(_ controller: OverlayMediaController) {
        self.sharedContext.mediaManager.overlayMediaManager.attachOverlayMediaController(controller)
    }
    
    public func storeSecureIdPassword(password: String) {
        self.storedPassword?.2.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 1.0 * 60.0 * 60.0, repeat: false, completion: { [weak self] in
            self?.storedPassword = nil
        }, queue: Queue.mainQueue())
        self.storedPassword = (password, CFAbsoluteTimeGetCurrent(), timer)
        timer.start()
    }
    
    public func getStoredSecureIdPassword() -> String? {
        if let (password, timestamp, timer) = self.storedPassword {
            if CFAbsoluteTimeGetCurrent() > timestamp + 1.0 * 60.0 * 60.0 {
                timer.invalidate()
                self.storedPassword = nil
            }
            return password
        } else {
            return nil
        }
    }
}
