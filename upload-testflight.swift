#!/usr/bin/env swift
//
//  upload-testflight.swift
//  Ventus
//
//  Bumps the build number, archives the iOS and Apple TV apps, exports IPAs,
//  validates them, and uploads them to App Store Connect / TestFlight.
//
//  Usage:
//    ./upload-testflight.swift
//    ./upload-testflight.swift --ios-only
//    ./upload-testflight.swift --ipa build/export/VentusIOS.ipa       # upload an existing iOS IPA only
//    ./upload-testflight.swift --tv-ipa build/export/VentusTVOS.ipa   # upload an existing tvOS IPA only
//

import Foundation

// MARK: - Configuration

let projectPath = "App/Ventus.xcodeproj"
let iOSScheme = "VentusIOS"
let tvOSScheme = "VentusTVOS"
let teamID = "27XTSJS68A"
let appInfoPlist = "App/Ventus_App-Info.plist"
let clipInfoPlist = "App/VentusClip/Info.plist"
let widgetInfoPlist = "App/VentusWidgets/Info.plist"
let watchAppInfoPlist = "App/VentusWatchOnly-Info.plist"
let watchCompanionInfoPlist = "App/VentusWatch-Info.plist"
let watchExtensionInfoPlist = "App/VentusWatch Extension-Info.plist"
let macAppInfoPlist = "App/VentusMacOS/Info.plist"
let tvAppInfoPlist = "App/VentusTVOS/Info.plist"
let buildDir = "build"
let iOSArchivePath = "\(buildDir)/VentusIOS.xcarchive"
let tvOSArchivePath = "\(buildDir)/VentusTVOS.xcarchive"
let iOSExportDir = "\(buildDir)/export/ios"
let tvOSExportDir = "\(buildDir)/export/tvos"
let exportOptionsPlist = "\(buildDir)/ExportOptions.plist"
let keychainItemName = ProcessInfo.processInfo.environment["ALTOOL_KEYCHAIN_ITEM"] ?? "Forescoop-AppStoreConnect"

let bundleVersionPlists = [
    appInfoPlist,
    clipInfoPlist,
    widgetInfoPlist,
    watchAppInfoPlist,
    watchCompanionInfoPlist,
    watchExtensionInfoPlist,
    macAppInfoPlist,
    tvAppInfoPlist,
]

// MARK: - Helpers

let xcodeFriendlyEnvironment: [String: String] = {
    var environment = ProcessInfo.processInfo.environment
    let existingPath = environment["PATH"] ?? ""
    environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:\(existingPath)"
    return environment
}()

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("\n💣 \(message)\n".data(using: .utf8)!)
    exit(1)
}

func step(_ message: String) {
    print("\n▶︎ \(message)")
}

@discardableResult
func run(_ launchPath: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.environment = xcodeFriendlyEnvironment
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    do {
        try process.run()
    } catch {
        fail("Failed to launch \(launchPath): \(error)")
    }
    process.waitUntilExit()
    return process.terminationStatus
}

func capture(_ launchPath: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.environment = xcodeFriendlyEnvironment
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
    } catch {
        fail("Failed to launch \(launchPath): \(error)")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func runSilent(_ launchPath: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
    } catch {
        return -1
    }
    process.waitUntilExit()
    return process.terminationStatus
}

func readSecret(prompt: String) -> String {
    print(prompt, terminator: "")
    var oldTermios = termios()
    tcgetattr(STDIN_FILENO, &oldTermios)
    var newTermios = oldTermios
    newTermios.c_lflag &= ~tcflag_t(ECHO)
    tcsetattr(STDIN_FILENO, TCSANOW, &newTermios)
    let input = readLine() ?? ""
    tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
    print()
    return input
}

let fileManager = FileManager.default

func machOBinaryPaths(under root: String) -> [String] {
    guard let enumerator = fileManager.enumerator(atPath: root) else { return [] }
    var results: [String] = []
    for case let relativePath as String in enumerator {
        let fullPath = "\(root)/\(relativePath)"
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
        guard fileManager.isExecutableFile(atPath: fullPath) else { continue }
        guard capture("/usr/bin/file", ["-b", fullPath]).contains("Mach-O") else { continue }
        results.append(fullPath)
    }
    return results
}

func dwarfUUIDs(forMachO path: String) -> Set<String> {
    let output = capture("/usr/bin/dwarfdump", ["--uuid", path])
    var found = Set<String>()
    for line in output.split(separator: "\n") {
        guard let range = line.range(of: "UUID: ") else { continue }
        let rest = line[range.upperBound...]
        guard let spaceIndex = rest.firstIndex(of: " ") else { continue }
        found.insert(String(rest[..<spaceIndex]))
    }
    return found
}

func checkDSYMs(archivePath: String, appPath: String) {
    let dSYMsDir = "\(archivePath)/dSYMs"
    var availableUUIDs = Set<String>()
    if let dsymBundles = try? fileManager.contentsOfDirectory(atPath: dSYMsDir) {
        for bundle in dsymBundles where bundle.hasSuffix(".dSYM") {
            let dwarfDir = "\(dSYMsDir)/\(bundle)/Contents/Resources/DWARF"
            guard let dwarfFiles = try? fileManager.contentsOfDirectory(atPath: dwarfDir) else { continue }
            for dwarfFile in dwarfFiles {
                availableUUIDs.formUnion(dwarfUUIDs(forMachO: "\(dwarfDir)/\(dwarfFile)"))
            }
        }
    }

    var missing: [(binary: String, uuid: String)] = []
    for binary in machOBinaryPaths(under: appPath) {
        let binaryName = (binary as NSString).lastPathComponent
        for uuid in dwarfUUIDs(forMachO: binary) where !availableUUIDs.contains(uuid) {
            missing.append((binary: binaryName, uuid: uuid))
        }
    }

    if missing.isEmpty {
        print("All embedded binaries have matching dSYMs.")
        return
    }
    print("⚠️  Missing dSYMs for \(missing.count) binary UUID(s) — App Store Connect will report \"Upload Symbols Failed\" for these (expected for closed-source third-party frameworks that don't ship dSYMs, e.g. Firebase/Google Ads):")
    for entry in missing.sorted(by: { $0.binary < $1.binary }) {
        print("   - \(entry.binary): \(entry.uuid)")
    }
}

// MARK: - Argument parsing

var explicitIPAPath: String? = nil
var explicitTVIPAPath: String? = nil
let arguments = CommandLine.arguments.dropFirst()
let iOSOnly = arguments.contains("--ios-only")
if let ipaFlagIndex = arguments.firstIndex(of: "--ipa"), arguments.index(after: ipaFlagIndex) < arguments.endIndex {
    explicitIPAPath = arguments[arguments.index(after: ipaFlagIndex)]
}
if let ipaFlagIndex = arguments.firstIndex(of: "--tv-ipa"), arguments.index(after: ipaFlagIndex) < arguments.endIndex {
    explicitTVIPAPath = arguments[arguments.index(after: ipaFlagIndex)]
}

if iOSOnly, explicitTVIPAPath != nil {
    fail("--ios-only cannot be combined with --tv-ipa")
}

// MARK: - Credentials

enum Credentials {
    case apiKey(keyID: String, issuerID: String, keyPath: String)
    case appleID(email: String, passwordArgument: String)
}

let environment = ProcessInfo.processInfo.environment
let credentials: Credentials

if let apiKeyID = environment["ASC_API_KEY_ID"], let apiIssuerID = environment["ASC_API_ISSUER_ID"] {
    let keysDir = NSString(string: "~/.appstoreconnect/private_keys").expandingTildeInPath
    let standardKeyPath = "\(keysDir)/AuthKey_\(apiKeyID).p8"
    if !fileManager.fileExists(atPath: standardKeyPath) {
        guard let providedPath = environment["ASC_API_KEY_PATH"], fileManager.fileExists(atPath: providedPath) else {
            fail("""
            ASC_API_KEY_ID is set but no key file was found at \(standardKeyPath).
            Set ASC_API_KEY_PATH to the downloaded AuthKey_\(apiKeyID).p8, or place it there yourself.
            """)
        }
        try? fileManager.createDirectory(atPath: keysDir, withIntermediateDirectories: true)
        do {
            try fileManager.copyItem(atPath: providedPath, toPath: standardKeyPath)
        } catch {
            fail("Could not copy API key to \(standardKeyPath): \(error)")
        }
        print("Installed API key at \(standardKeyPath).")
    }
    credentials = .apiKey(keyID: apiKeyID, issuerID: apiIssuerID, keyPath: standardKeyPath)
} else {
    let appleID = environment["APPLE_ID"]
        ?? { print("Apple ID: ", terminator: ""); return readLine() ?? "" }()
    guard !appleID.isEmpty else { fail("An Apple ID is required (or set ASC_API_KEY_ID/ASC_API_ISSUER_ID instead).") }

    let passwordArgument: String
    if let envPassword = environment["APP_SPECIFIC_PASSWORD"] {
        passwordArgument = envPassword
    } else if runSilent("/usr/bin/security", ["find-generic-password", "-s", keychainItemName]) == 0 {
        passwordArgument = "@keychain:\(keychainItemName)"
        print("Using app-specific password from keychain item \"\(keychainItemName)\".")
    } else {
        let entered = readSecret(prompt: "App-specific password: ")
        guard !entered.isEmpty else { fail("An app-specific password is required.") }
        print("Save this password to the keychain as \"\(keychainItemName)\" for next time? [y/N]: ", terminator: "")
        if let answer = readLine(), answer.lowercased().hasPrefix("y") {
            let storeStatus = run("/usr/bin/xcrun", [
                "altool", "--store-password-in-keychain-item", keychainItemName,
                "-u", appleID,
                "-p", entered,
            ])
            print(storeStatus == 0 ? "Saved to keychain." : "Could not save to keychain (continuing anyway).")
        }
        passwordArgument = entered
    }
    credentials = .appleID(email: appleID, passwordArgument: passwordArgument)
}

let xcodebuildAuthArgs: [String] = {
    guard case let .apiKey(keyID, issuerID, keyPath) = credentials else { return [] }
    return ["-authenticationKeyPath", keyPath, "-authenticationKeyID", keyID, "-authenticationKeyIssuerID", issuerID]
}()

let altoolAuthArgs: [String] = {
    switch credentials {
    case let .apiKey(keyID, issuerID, _):
        return ["--apiKey", keyID, "--apiIssuer", issuerID]
    case let .appleID(email, passwordArgument):
        return ["-u", email, "-p", passwordArgument]
    }
}()

// MARK: - Pipeline

try? fileManager.createDirectory(atPath: buildDir, withIntermediateDirectories: true)

struct UploadPlatform {
    let name: String
    let scheme: String
    let destination: String
    let archivePath: String
    let exportDir: String
    let appStorePlatform: String
    let explicitIPAPath: String?
}

let allPlatforms = [
    UploadPlatform(
        name: "iOS",
        scheme: iOSScheme,
        destination: "generic/platform=iOS",
        archivePath: iOSArchivePath,
        exportDir: iOSExportDir,
        appStorePlatform: "ios",
        explicitIPAPath: explicitIPAPath
    ),
    UploadPlatform(
        name: "tvOS",
        scheme: tvOSScheme,
        destination: "generic/platform=tvOS",
        archivePath: tvOSArchivePath,
        exportDir: tvOSExportDir,
        appStorePlatform: "appletvos",
        explicitIPAPath: explicitTVIPAPath
    ),
]

// With no IPA arguments, ship both platforms. Supplying an IPA uploads only
// the explicitly requested platform(s), which keeps the old --ipa workflow.
let platforms: [UploadPlatform]
if iOSOnly {
    platforms = [allPlatforms[0]]
} else if explicitIPAPath == nil && explicitTVIPAPath == nil {
    platforms = allPlatforms
} else {
    platforms = allPlatforms.filter { $0.explicitIPAPath != nil }
}

let platformsToArchive = platforms.filter { $0.explicitIPAPath == nil }
if !platformsToArchive.isEmpty {
    // 1. Increment build number
    step("Incrementing build number")
    let plistBuddy = "/usr/libexec/PlistBuddy"
    let currentBuild = capture(plistBuddy, ["-c", "Print :CFBundleVersion", appInfoPlist])
    guard let currentBuildNumber = Int(currentBuild) else {
        fail("Could not read CFBundleVersion from \(appInfoPlist) (got \"\(currentBuild)\")")
    }
    let newBuildNumber = currentBuildNumber + 1
    for plist in bundleVersionPlists {
        let status = run(plistBuddy, ["-c", "Set :CFBundleVersion \(newBuildNumber)", plist])
        guard status == 0 else { fail("Failed to update CFBundleVersion in \(plist)") }
    }
    print("Build number: \(currentBuildNumber) -> \(newBuildNumber)")
}

func archiveAndExport(_ platform: UploadPlatform) -> String {
    // 2. Archive
    step("Archiving \(platform.name) (this can take a while)")
    try? fileManager.removeItem(atPath: platform.archivePath)
    let archiveStatus = run("/usr/bin/xcodebuild", [
        "archive",
        "-project", projectPath,
        "-scheme", platform.scheme,
        "-configuration", "Release",
        "-destination", platform.destination,
        "-archivePath", platform.archivePath,
        "-allowProvisioningUpdates",
        "DEVELOPMENT_TEAM=\(teamID)",
    ] + xcodebuildAuthArgs)
    guard archiveStatus == 0 else { fail("xcodebuild archive failed (status \(archiveStatus))") }

    let archivedAppsDir = "\(platform.archivePath)/Products/Applications"
    guard let archivedAppName = (try? fileManager.contentsOfDirectory(atPath: archivedAppsDir))?.first(where: { $0.hasSuffix(".app") }) else {
        fail("No .app found in \(archivedAppsDir) after archive")
    }
    let archivedAppPath = "\(archivedAppsDir)/\(archivedAppName)"
    let signingInfo = capture("/usr/bin/codesign", ["-dvv", archivedAppPath])
    if !signingInfo.contains("Apple Distribution") {
        let authorityLine = signingInfo.split(separator: "\n").first(where: { $0.contains("Authority") }) ?? "(no Authority line found)"
        print("Note: archive is currently signed with: \(authorityLine). Proceeding to export, which re-signs for distribution.")
    }

    // 2b. Check dSYMs
    step("Checking dSYMs for embedded binaries")
    checkDSYMs(archivePath: platform.archivePath, appPath: archivedAppPath)

    // 3. Export
    step("Exporting \(platform.name) IPA")
    // The App Store profiles are deliberately selected for iOS. Automatic
    // export signing attempts to use Apple's cloud-managed certificates, which
    // is unavailable for this team even though local distribution profiles
    // are installed.
    let manualIOSProfileOptions = platform.name == "iOS" ? """
        <key>signingStyle</key>
        <string>manual</string>
        <key>signingCertificate</key>
        <string>Apple Distribution</string>
        <key>provisioningProfiles</key>
        <dict>
            <key>org.forescoop.iOSnowatch</key>
            <string>Ventus iOS App Store</string>
            <key>org.forescoop.iOSnowatch.Clip</key>
            <string>Ventus Clip App Store</string>
            <key>org.forescoop.iOSnowatch.ForescoopWidgets</key>
            <string>Ventus iOS Widgets App Store</string>
        </dict>
    """ : """
        <key>signingStyle</key>
        <string>automatic</string>
    """
    let exportOptions = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>method</key>
        <string>app-store-connect</string>
        <key>teamID</key>
        <string>\(teamID)</string>
    \(manualIOSProfileOptions)
    </dict>
    </plist>
    """
    do {
        try exportOptions.write(toFile: exportOptionsPlist, atomically: true, encoding: .utf8)
    } catch {
        fail("Could not write \(exportOptionsPlist): \(error)")
    }

    try? fileManager.removeItem(atPath: platform.exportDir)
    var exportArguments = [
        "-exportArchive",
        "-archivePath", platform.archivePath,
        "-exportPath", platform.exportDir,
        "-exportOptionsPlist", exportOptionsPlist,
    ]
    if platform.name != "iOS" {
        exportArguments.append("-allowProvisioningUpdates")
        exportArguments += xcodebuildAuthArgs
    }
    let exportStatus = run("/usr/bin/xcodebuild", exportArguments)
    guard exportStatus == 0 else { fail("xcodebuild -exportArchive failed (status \(exportStatus))") }

    guard let exportedIPA = (try? fileManager.contentsOfDirectory(atPath: platform.exportDir))?.first(where: { $0.hasSuffix(".ipa") }) else {
        fail("No .ipa found in \(platform.exportDir) after export")
    }
    return "\(platform.exportDir)/\(exportedIPA)"
}

for platform in platforms {
    let ipaPath: String
    if let explicitIPAPath = platform.explicitIPAPath {
        ipaPath = explicitIPAPath
        guard fileManager.fileExists(atPath: ipaPath) else { fail("No IPA found at \(ipaPath)") }
        step("Using existing \(platform.name) IPA at \(ipaPath), skipping increment/archive/export.")
    } else {
        ipaPath = archiveAndExport(platform)
    }

    print("IPA: \(ipaPath)")

    // 4. Validate
    step("Validating \(platform.name) IPA")
    let validateStatus = run("/usr/bin/xcrun", [
        "altool", "--validate-app",
        "-f", ipaPath,
        "-t", platform.appStorePlatform,
    ] + altoolAuthArgs)
    guard validateStatus == 0 else { fail("\(platform.name) validation failed (status \(validateStatus))") }

    // 5. Upload
    step("Uploading \(platform.name) to App Store Connect / TestFlight")
    let uploadStatus = run("/usr/bin/xcrun", [
        "altool", "--upload-app",
        "-f", ipaPath,
        "-t", platform.appStorePlatform,
    ] + altoolAuthArgs)
    guard uploadStatus == 0 else { fail("\(platform.name) upload failed (status \(uploadStatus))") }

    print("\n✅ 🚀 Uploaded \(platform.name) to App Store Connect. It will appear in TestFlight once Apple finishes processing.")
}
