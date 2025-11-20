import SwiftUI
import UniformTypeIdentifiers

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

struct ContentView: View {
    let origMGURL, modMGURL, featFlagsURL: URL
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("PairingFile") var pairingFile: String?
    @State var mbdb: Backup?
    @State var eligibilityData = Data()
    @State var featureFlagsData = Data()
    @State var mobileGestalt: NSMutableDictionary
    @State var productType = machineName()
    @State var minimuxerReady = false
    @State var reboot = true
    @State var showPairingFileImporter = false
    @State var showErrorAlert = false
    @State var taskRunning = false
    @State var initError: String?
    @State var lastError: String?
    @State var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Text("HTTP server port \(Utils.port)")
                } header: {
                    Text("Debug")
                }
                Section {
                    Button(pairingFile == nil ? "Select pairing file" : "Reset pairing file") {
                        if pairingFile == nil {
                            showPairingFileImporter.toggle()
                        } else {
                            pairingFile = nil
                        }
                    }
                    .dropDestination(for: Data.self) { items, location in
                        guard let item = items.first else { return false }
                        pairingFile = try! String(decoding: item, as: UTF8.self)
                        guard pairingFile?.contains("DeviceCertificate") ?? false else {
                            lastError = "The file you just dropped is not a pairing file"
                            showErrorAlert.toggle()
                            pairingFile = nil
                            return false
                        }
                        startMinimuxer()
                        return true
                    }
                } footer: {
                    if pairingFile != nil {
                        Text("Pairing file selected")
                    } else {
                        Text("Select or drag and drop a pairing file to continue. More info: https://docs.sidestore.io/docs/getting-started/pairing-file")
                    }
                }
                Section {
                    Button("List installed apps") {
                        testListApps()
                    }
                    Button("Bypass 3 app limit") {
                        testBypassAppLimit()
                    }
                    .disabled(taskRunning)
                } footer: {
                    Text("Hide free developer apps from installd, so you could install more than 3 apps. You need to apply this for each 3 apps you install or update.")
                }
                Section {
                    Toggle("Action Button", isOn: bindingForMGKeys(["cT44WE1EohiwRzhsZ8xEsw"]))
                        .disabled(Utils.requiresVersion(17))
                    Toggle("Allow installing iPadOS apps", isOn: bindingForMGKeys(["9MZ5AdH43csAUajl/dU+IQ"], type: [Int].self, defaultValue: [1], enableValue: [1, 2]))
                    Toggle("Always on Display (18.0+)", isOn: bindingForMGKeys(["j8/Omm6s1lsmTDFsXjsBfA", "2OOJf1VhaM7NxfRok3HbWQ"]))
                        .disabled(Utils.requiresVersion(18))
                    Toggle("Apple Intelligence", isOn: bindingForAppleIntelligence())
                        .disabled(Utils.requiresVersion(18))
                    Toggle("Apple Pencil", isOn: bindingForMGKeys(["yhHcB0iH0d1XzPO/CFd3ow"]))
                    Toggle("Boot chime", isOn: bindingForMGKeys(["QHxt+hGLaBPbQJbXiUJX3w"]))
                    Toggle("Camera button (18.0rc+)", isOn: bindingForMGKeys(["CwvKxM2cEogD3p+HYgaW0Q", "oOV1jhJbdV3AddkcCg0AEA"]))
                        .disabled(Utils.requiresVersion(18))
                    Toggle("Charge limit", isOn: bindingForMGKeys(["37NVydb//GP/GrhuTN+exg"]))
                        .disabled(Utils.requiresVersion(17))
                    Toggle("Crash Detection (might not work)", isOn: bindingForMGKeys(["HCzWusHQwZDea6nNhaKndw"]))
                    Toggle("Dynamic Island (17.4+, might not work)", isOn: bindingForMGKeys(["YlEtTtHlNesRBMal1CqRaA"]))
                        .disabled(Utils.requiresVersion(17, 4))
                    Toggle("Disable region restrictions", isOn: bindingForRegionRestriction())
                    Toggle("Internal Storage info", isOn: bindingForMGKeys(["LBJfwOEzExRxzlAnSuI7eg"]))
                    Toggle("Metal HUD for all apps", isOn: bindingForMGKeys(["EqrsVvjcYDdxHBiQmGhAWw"]))
                    Toggle("Stage Manager", isOn: bindingForMGKeys(["qeaj75wk3HF4DwQ8qbIi7g"]))
                        .disabled(UIDevice.current.userInterfaceIdiom != .pad)
                    if UIDevice._hasHomeButton() {
                        Toggle("Tap to Wake (iPhone SE)", isOn: bindingForMGKeys(["yZf3GTRMGTuwSV/lD7Cagw"]))
                    }
                } header: {
                    Text("MobileGestalt")
                }
                Section {
                    Picker("Device model", selection:$productType) {
                        Text("unchanged").tag(ContentView.machineName())
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Text("iPad Pro 11 inch 5th Gen").tag("iPad16,3")
                        } else {
                            Text("iPhone 15 Pro Max").tag("iPhone16,2")
                            Text("iPhone 16 Pro Max").tag("iPhone17,2")
                        }
                    }
                    //.disabled(Utils.requiresVersion(18, 1))
                } header: {
                    Text("Device spoofing")
                } footer: {
                    Text("Only change device model if you're downloading Apple Intelligence models. Face ID may break.")
                }
                Section {
                    let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary
                    Toggle("Become iPadOS", isOn: bindingForTrollPad())
                    // validate DeviceClass
                        .disabled(cacheExtra?["+3Uf0Pm5F8Xy7Onyvko0vA"] as? String != "iPhone")
                } footer: {
                    Text("Override user interface idiom to iPadOS, so you could use all iPadOS multitasking features on iPhone. Gives you the same capabilities as TrollPad, but may cause some issues.\nPLEASE DO NOT TURN OFF SHOW DOCK IN STAGE MANAGER OTHERWISE YOUR PHONE WILL BOOTLOOP WHEN ROTATING TO LANDSCAPE.")
                }
                Section {
                    Toggle("Reboot after finish restoring", isOn: $reboot)
                    Button("Apply changes") {
                        saveProductType()
                        try! mobileGestalt.write(to: modMGURL)
                        applyChanges()
                    }
                    .disabled(taskRunning)
                    Button("Reset changes") {
                        try! FileManager.default.removeItem(at: modMGURL)
                        try! FileManager.default.copyItem(at: origMGURL, to: modMGURL)
                        mobileGestalt = try! NSMutableDictionary(contentsOf: modMGURL, error: ())
                        applyChanges()
                    }
                    .disabled(taskRunning)
                }
                Section {
                    //ShareLink("Export Modified MobileGestalt", item: modMGURL)
                    Button("Export Modified MobileGestalt", systemImage: "square.and.arrow.up") {
                        saveProductType()
                        try! mobileGestalt.write(to: modMGURL)
                        let activityVC = UIActivityViewController(activityItems: [modMGURL], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            scene.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
                        }
                    }
                    ShareLink("Export Original MobileGestalt", item: origMGURL)
                }
                Section {
                } footer: {
                    VStack {
                        Text("""
A terrible app by @khanhduytran0. Use it at your own risk.
Thanks to:
@SideStore: em_proxy and minimuxer
@JJTech0130: SparseRestore and backup exploit
@PoomSmart: MobileGestalt dump
@Lakr233: BBackupp
@libimobiledevice
""")
                    }
                }
            }
            .fileImporter(isPresented: $showPairingFileImporter, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!], onCompletion: { result in
                switch result {
                case .success(let url):
                    pairingFile = try! String(contentsOf: url)
                    startMinimuxer()
                case .failure(let error):
                    lastError = error.localizedDescription
                    showErrorAlert.toggle()
                }
            })
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(lastError ?? "???")
            }
            .navigationDestination(for: String.self) { view in
                if view == "ApplyChanges" {
                    LogView()
                        .onAppear {
                            DispatchQueue.global(qos: .background).async {
                                performApplyMobileGestalt()
                            }
                        }
                } else if view == "Apply3AppLimitBypass" {
                    LogView()
                        .onAppear {
                            DispatchQueue.global(qos: .background).async {
                                reboot = false
                                performApply3AppLimitBypass()
                            }
                        }
                } else if view == "ListApps" {
                    AppListView()
                }
            }
            .navigationTitle("SparseBox")
        }
        .onAppear {
            if initError != nil {
                lastError = initError
                initError = nil
                showErrorAlert.toggle()
                return
            }
            
            _ = start_emotional_damage("127.0.0.1:51820")
            if let altPairingFile = Bundle.main.object(forInfoDictionaryKey: "ALTPairingFile") as? String, altPairingFile.count > 5000, pairingFile == nil {
                pairingFile = altPairingFile
            }
            startMinimuxer()
            
            if let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary {
                productType = cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as! String
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // keep HTTP server alive in the background for a while
            if scenePhase == .inactive {
                Utils.bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                    // This executes when time is about to run out
                    UIApplication.shared.endBackgroundTask(Utils.bgTask)
                    Utils.bgTask = .invalid
                })
                if Utils.bgTask == .invalid {
                    print("Failed to start background task")
                    return
                }
            } else if scenePhase == .active {
                if Utils.bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(Utils.bgTask)
                    Utils.bgTask = .invalid
                }
            }
        }
    }
    
    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        featFlagsURL = documentsDirectory.appendingPathComponent("FeatureFlags.plist", conformingTo: .data)
        origMGURL = documentsDirectory.appendingPathComponent("OriginalMobileGestalt.plist", conformingTo: .data)
        modMGURL = documentsDirectory.appendingPathComponent("ModifiedMobileGestalt.plist", conformingTo: .data)
        
        do {
            if !FileManager.default.fileExists(atPath: origMGURL.path) {
                let url = URL(filePath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")
                try FileManager.default.copyItem(at: url, to: origMGURL)
            }
            chmod(origMGURL.path, 0o644)
            
            if !FileManager.default.fileExists(atPath: modMGURL.path) {
                try FileManager.default.copyItem(at: origMGURL, to: modMGURL)
            }
            chmod(modMGURL.path, 0o644)
            
            _mobileGestalt = State(initialValue: try NSMutableDictionary(contentsOf: modMGURL, error: ()))
        } catch {
            _mobileGestalt = State(initialValue: [:])
            _initError = State(initialValue: "Failed to copy MobileGestalt: \(error)")
            taskRunning = true
        }
        
        // Fix file picker
        let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:)))!
        let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)))!
        method_exchangeImplementations(origMethod, fixMethod)
    }

    func testBypassAppLimit() {
        guard Restore.supportedExploitLevel() == .dotAndSlashes else {
            lastError = "Unsupported iOS version. Must be running iOS 18.1b4 or older."
            showErrorAlert.toggle()
            return
        }
        Task {
            taskRunning = true
            if ready() {
                mbdb = Restore.createBypassAppLimit()
                path.append("Apply3AppLimitBypass")
            } else {
                lastError = "minimuxer is not ready. Ensure you have WiFi and WireGuard VPN set up."
                showErrorAlert.toggle()
            }
            taskRunning = false
        }
    }
    
    func testListApps() {
        if ready() {
            path.append("ListApps")
        } else {
            lastError = "minimuxer is not ready. Ensure you have WiFi and WireGuard VPN set up."
            showErrorAlert.toggle()
        }
    }
    
    func applyChanges() {
        Task {
            taskRunning = true
            if ready() {
                //mbdb = Restore.createMobileGestalt(file: FileToRestore(from: modMGURL, to: URL(filePath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"), owner: 501, group: 501))
                //Restore.createBackupFiles(files: generateFilesToRestore())
                path.append("ApplyChanges")
            } else {
                lastError = "minimuxer is not ready. Ensure you have WiFi and WireGuard VPN set up."
                showErrorAlert.toggle()
            }
            taskRunning = false
        }
    }
    
    func bindingForAppleIntelligence() -> Binding<Bool> {
        guard let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        let key = "A62OafQ85EJAiiqKn4agtg"
        return Binding(
            get: {
                if let value = cacheExtra[key] as? Int? {
                    return value == 1
                }
                return false
            },
            set: { enabled in
                if enabled {
                    eligibilityData = try! Data(contentsOf: Bundle.main.url(forResource: "eligibility", withExtension: "plist")!)
                    featureFlagsData = try! Data(contentsOf: Bundle.main.url(forResource: "FeatureFlags_Global", withExtension: "plist")!)
                    cacheExtra[key] = 1
                } else {
                    featureFlagsData = try! PropertyListSerialization.data(fromPropertyList: [:], format: .xml, options: 0)
                    eligibilityData = featureFlagsData
                    // just remove the key as it will be pulled from device tree if missing
                    cacheExtra.removeObject(forKey: key)
                }
            }
        )
    }

    func bindingForRegionRestriction() -> Binding<Bool> {
        guard let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        return Binding<Bool>(
            get: {
                return cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "US" &&
                    cacheExtra["zHeENZu+wbg7PUprwNwBWg"] as? String == "LL/A"
            },
            set: { enabled in
                if enabled {
                    cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] = "US"
                    cacheExtra["zHeENZu+wbg7PUprwNwBWg"] = "LL/A"
                } else {
                    cacheExtra.removeObject(forKey: "h63QSdBCiT/z0WU6rdQv6Q")
                    cacheExtra.removeObject(forKey: "zHeENZu+wbg7PUprwNwBWg")
                }
            }
        )
    }
    
    func bindingForTrollPad() -> Binding<Bool> {
        // We're going to overwrite DeviceClassNumber but we can't do it via CacheExtra, so we need to do it via CacheData instead
        guard let cacheData = mobileGestalt["CacheData"] as? NSMutableData,
              let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        let valueOffset = UserDefaults.standard.integer(forKey: "MGCacheDataDeviceClassNumberOffset")
        //print("Read value from \(cacheData.mutableBytes.load(fromByteOffset: valueOffset, as: Int.self))")
        
        let keys = [
            "uKc7FPnEO++lVhHWHFlGbQ", // ipad
            "mG0AnH/Vy1veoqoLRAIgTA", // MedusaFloatingLiveAppCapability
            "UCG5MkVahJxG1YULbbd5Bg", // MedusaOverlayAppCapability
            "ZYqko/XM5zD3XBfN5RmaXA", // MedusaPinnedAppCapability
            "nVh/gwNpy7Jv1NOk00CMrw", // MedusaPIPCapability,
            "qeaj75wk3HF4DwQ8qbIi7g", // DeviceSupportsEnhancedMultitasking
        ]
        return Binding(
            get: {
                if let value = cacheExtra[keys.first!] as? Int? {
                    return value == 1
                }
                return false
            },
            set: { enabled in
                cacheData.mutableBytes.storeBytes(of: enabled ? 3 : 1, toByteOffset: valueOffset, as: Int.self)
                for key in keys {
                    if enabled {
                        cacheExtra[key] = 1
                    } else {
                        // just remove the key as it will be pulled from device tree if missing
                        cacheExtra.removeObject(forKey: key)
                    }
                }
            }
        )
    }
    
    func bindingForMGKeys<T: Equatable>(_ keys: [String], type: T.Type = Int.self, defaultValue: T? = 0, enableValue: T? = 1) -> Binding<Bool> {
        guard let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        return Binding(
            get: {
                if let value = cacheExtra[keys.first!] as? T?, let enableValue {
                    return value == enableValue
                }
                return false
            },
            set: { enabled in
                for key in keys {
                    if enabled {
                        cacheExtra[key] = enableValue
                    } else {
                        // just remove the key as it will be pulled from device tree if missing
                        cacheExtra.removeObject(forKey: key)
                    }
                }
            }
        )
    }
    
    func generateFilesToRestore() -> [FileToRestore] {
        return [
            FileToRestore(from: modMGURL, to: URL(filePath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"), owner: 501, group: 501),
            FileToRestore(contents: eligibilityData, to: URL(filePath: "/var/db/eligibilityd/eligibility.plist")),
            FileToRestore(contents: featureFlagsData, to: URL(filePath: "/var/preferences/FeatureFlags/Global.plist")),
        ]
    }
    
    // https://stackoverflow.com/questions/26028918/how-to-determine-the-current-iphone-device-model
    // read device model from kernel
    static func machineName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    func saveProductType() {
        let cacheExtra = mobileGestalt["CacheExtra"] as! NSMutableDictionary
        cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] = productType
    }
    
    func startMinimuxer() {
        guard pairingFile != nil else {
            return
        }
        // set USBMUXD_SOCKET_ADDRESS
        target_minimuxer_address()
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].absoluteString
            try start(pairingFile!, documentsDirectory)
        } catch {
            lastError = error.localizedDescription
            showErrorAlert.toggle()
        }
    }
    
    func performApplyMobileGestalt() {
        let deviceList = MobileDevice.deviceList()
        guard deviceList.count == 1 else {
            print("Invalid device count: \(deviceList.count)")
            return
        }
        Utils.udid = deviceList.first!
        D28BookChain.replaceMobileGestalt(udid: Utils.udid, path: "/aaaaa")
        
        /*
        MobileDevice.requireAppleFileConduitService(udid: Utils.udid) { client in
            var file: UInt64 = 0
            let ret = afc_file_open(client, "/Downloads/downloads.28.sqlitedb", AFC_FOPEN_RW, &file)
            guard ret == AFC_E_SUCCESS else {
                print("AFC open failed with code \(ret)")
                return
            }
            
            let d28LocalPath = Bundle.main.url(forResource: "downloads", withExtension: "28.sqlitedb")!
            let d28Data = try! Data(contentsOf: d28LocalPath)
            d28Data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let writeRet = afc_file_write(client, file, ptr.baseAddress!, UInt32(d28Data.count), <#UnsafeMutablePointer<UInt32>?#>)
                guard writeRet == AFC_E_SUCCESS else {
                    print("AFC write failed with code \(writeRet)")
                    return
                }
            }
        }
         */
    }
    
    func performApply3AppLimitBypass() {
        let deviceList = MobileDevice.deviceList()
        guard deviceList.count == 1 else {
            print("Invalid device count: \(deviceList.count)")
            return
        }
        Utils.udid = deviceList.first!
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documentsDirectory.appendingPathComponent(Utils.udid, conformingTo: .data)
        try? FileManager.default.removeItem(at: folder)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try mbdb!.writeTo(directory: folder)
            // Restore now
            let restoreArgs = [
                "idevicebackup2",
                "-n", "restore", "--no-reboot", "--system",
                documentsDirectory.path(percentEncoded: false)
            ]
            print("Executing args: \(restoreArgs)")
            var argv = restoreArgs.map{ strdup($0) }
            let result = idevicebackup2_main(Int32(restoreArgs.count), &argv)
            print("idevicebackup2 exited with code \(result)")
            
            print()
            let log = GLOBAL_LOG.text
            if log.contains("Domain name cannot contain a slash") {
                print("Result: this iOS version is not supported.")
            } else if log.contains("crash_on_purpose") || result == 0 {
                print("Result: restore successful.")
                if reboot {
                    MobileDevice.rebootDevice(udid: Utils.udid)
                }
            }
            
            logPipe.fileHandleForReading.readabilityHandler = nil
        } catch {
            print(error.localizedDescription)
            return
        }
    }
}
