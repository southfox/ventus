#!/usr/bin/env swift
//
//  upload-testflight.swift
//  Forescoop
//
//  Bumps the build number, archives the iOSnowatch app, exports an IPA,
//  validates it, and uploads it to App Store Connect / TestFlight.
//
//  Usage:
//    ./upload-testflight.swift
//    ./upload-testflight.swift --ipa build/export/iOSnowatch.ipa   # skip archive/export, just validate+upload
//

import Foundation

// MARK: - Configuration

let projectPath = "Example/Forescoop.xcodeproj"
let scheme = "iOSnowatch"
let teamID = "27XTSJS68A"
let appInfoPlist = "Example/Forescoop_Example-Info.plist"
let widgetInfoPlist = "Example/ForescoopWidgets/Info.plist"
let buildDir = "build"
let archivePath = "\(buildDir)/iOSnowatch.xcarchive"
let exportDir = "\(buildDir)/export"
let exportOptionsPlist = "\(buildDir)/ExportOptions.plist"
let keychainItemName = ProcessInfo.processInfo.environment["ALTOOL_KEYCHAIN_ITEM"] ?? "Forescoop-AppStoreConnect"

// MARK: - Helpers

let xcodeFriendlyEnvironment: [String: String] = {
    var environment = ProcessInfo.processInfo.environment
    let existingPath = environment["PATH"] ?? ""
    environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:\(existingPath)"
    return environment
}()

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("\n❌ \(message)\n".data(using: .utf8)!)
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

// MARK: - Argument parsing

var explicitIPAPath: String? = nil
let arguments = CommandLine.arguments.dropFirst()
if let ipaFlagIndex = arguments.firstIndex(of: "--ipa"), arguments.index(after: ipaFlagIndex) < arguments.endIndex {
    explicitIPAPath = arguments[arguments.index(after: ipaFlagIndex)]
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

/// -authenticationKey* flags for xcodebuild (archive/export), empty when using Apple ID auth.
let xcodebuildAuthArgs: [String] = {
    guard case let .apiKey(keyID, issuerID, keyPath) = credentials else { return [] }
    return ["-authenticationKeyPath", keyPath, "-authenticationKeyID", keyID, "-authenticationKeyIssuerID", issuerID]
}()

/// --apiKey/--apiIssuer or -u/-p flags for altool.
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

var ipaPath: String

if let explicitIPAPath {
    ipaPath = explicitIPAPath
    guard fileManager.fileExists(atPath: ipaPath) else { fail("No IPA found at \(ipaPath)") }
    step("Using existing IPA at \(ipaPath), skipping increment/archive/export.")
} else {
    // 1. Increment build number
    step("Incrementing build number")
    let plistBuddy = "/usr/libexec/PlistBuddy"
    let currentBuild = capture(plistBuddy, ["-c", "Print :CFBundleVersion", appInfoPlist])
    guard let currentBuildNumber = Int(currentBuild) else {
        fail("Could not read CFBundleVersion from \(appInfoPlist) (got \"\(currentBuild)\")")
    }
    let newBuildNumber = currentBuildNumber + 1
    for plist in [appInfoPlist, widgetInfoPlist] {
        let status = run(plistBuddy, ["-c", "Set :CFBundleVersion \(newBuildNumber)", plist])
        guard status == 0 else { fail("Failed to update CFBundleVersion in \(plist)") }
    }
    print("Build number: \(currentBuildNumber) -> \(newBuildNumber)")

    // 2. Archive
    step("Archiving \(scheme) (this can take a while)")
    try? fileManager.removeItem(atPath: archivePath)
    let archiveStatus = run("/usr/bin/xcodebuild", [
        "archive",
        "-project", projectPath,
        "-scheme", scheme,
        "-configuration", "Release",
        "-destination", "generic/platform=iOS",
        "-archivePath", archivePath,
        "-allowProvisioningUpdates",
        "DEVELOPMENT_TEAM=\(teamID)",
    ] + xcodebuildAuthArgs)
    guard archiveStatus == 0 else { fail("xcodebuild archive failed (status \(archiveStatus))") }

    let archivedAppsDir = "\(archivePath)/Products/Applications"
    guard let archivedAppName = (try? fileManager.contentsOfDirectory(atPath: archivedAppsDir))?.first(where: { $0.hasSuffix(".app") }) else {
        fail("No .app found in \(archivedAppsDir) after archive")
    }
    let archivedAppPath = "\(archivedAppsDir)/\(archivedAppName)"
    let signingInfo = capture("/usr/bin/codesign", ["-dvv", archivedAppPath])
    if !signingInfo.contains("Apple Distribution") {
        let authorityLine = signingInfo.split(separator: "\n").first(where: { $0.contains("Authority") }) ?? "(no Authority line found)"
        print("Note: archive is currently signed with: \(authorityLine). Proceeding to export, which re-signs for distribution.")
    }

    // 3. Export
    step("Exporting IPA")
    let exportOptions = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>method</key>
        <string>app-store-connect</string>
        <key>teamID</key>
        <string>\(teamID)</string>
        <key>signingStyle</key>
        <string>automatic</string>
    </dict>
    </plist>
    """
    do {
        try exportOptions.write(toFile: exportOptionsPlist, atomically: true, encoding: .utf8)
    } catch {
        fail("Could not write \(exportOptionsPlist): \(error)")
    }

    try? fileManager.removeItem(atPath: exportDir)
    let exportStatus = run("/usr/bin/xcodebuild", [
        "-exportArchive",
        "-archivePath", archivePath,
        "-exportPath", exportDir,
        "-exportOptionsPlist", exportOptionsPlist,
        "-allowProvisioningUpdates",
    ] + xcodebuildAuthArgs)
    guard exportStatus == 0 else { fail("xcodebuild -exportArchive failed (status \(exportStatus))") }

    guard let exportedIPA = (try? fileManager.contentsOfDirectory(atPath: exportDir))?.first(where: { $0.hasSuffix(".ipa") }) else {
        fail("No .ipa found in \(exportDir) after export")
    }
    ipaPath = "\(exportDir)/\(exportedIPA)"
}

print("IPA: \(ipaPath)")

// 4. Validate
step("Validating IPA")
let validateStatus = run("/usr/bin/xcrun", [
    "altool", "--validate-app",
    "-f", ipaPath,
    "-t", "ios",
] + altoolAuthArgs)
guard validateStatus == 0 else { fail("Validation failed (status \(validateStatus))") }

// 5. Upload
step("Uploading to App Store Connect / TestFlight")
let uploadStatus = run("/usr/bin/xcrun", [
    "altool", "--upload-app",
    "-f", ipaPath,
    "-t", "ios",
] + altoolAuthArgs)
guard uploadStatus == 0 else { fail("Upload failed (status \(uploadStatus))") }

print("\n✅ Uploaded \(ipaPath) to App Store Connect. It will appear in TestFlight once Apple finishes processing.")
