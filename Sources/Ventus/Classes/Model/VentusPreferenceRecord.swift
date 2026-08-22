//
//  VentusPreferenceRecord.swift
//  VentusPackage
//
//  Created by Javier on 19/08/2026.
//  

import SwiftData

@Model final class VentusPreferenceRecord {
    @Attribute(.unique) var key: String
    var value: String
    init(key: String, value: String) { self.key = key; self.value = value }
}
