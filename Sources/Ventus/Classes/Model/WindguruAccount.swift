//
//  WindguruAccount.swift
//  Ventus package
//
//  Created by Javier Fuchs on 07/30/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Combine
import Foundation

@MainActor
public final class WindguruAccount: ObservableObject {
    @Published public private(set) var username: String
    @Published public private(set) var isProUser: Bool
    @Published public private(set) var profile: User?

    private let credentialStore: WindguruCredentialStoring

    public var password: String? { credentialStore.password(for: username) }
    public var isAuthenticated: Bool { !username.isEmpty && password != nil }

    public init(credentialStore: WindguruCredentialStoring) {
        self.credentialStore = credentialStore
        username = credentialStore.activeUsername() ?? ""
        isProUser = credentialStore.activeProUser()
    }

    public init(username: String, isProUser: Bool = false, credentialStore: WindguruCredentialStoring) {
        self.credentialStore = credentialStore
        self.username = username
        self.isProUser = isProUser
    }

    public func signIn(username: String, isProUser: Bool) {
        self.username = username
        self.isProUser = isProUser
        try? credentialStore.saveActiveUsername(username)
        try? credentialStore.saveActiveProUser(isProUser)
    }

    public func update(profile: User) {
        self.profile = profile
        isProUser = profile.isPro
        try? credentialStore.saveActiveProUser(profile.isPro)
    }

    public func signOut() {
        credentialStore.removePassword(for: username)
        username = ""
        isProUser = false
        profile = nil
        credentialStore.removeActiveUsername()
        credentialStore.removeActiveProUser()
    }
}
