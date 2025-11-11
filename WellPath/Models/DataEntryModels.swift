//
//  DataEntryModels.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation

struct DataEntryField: Codable, Identifiable {
    var id: String { fieldId }
    let fieldId: String
    let fieldName: String
    let category: String?
    let inputType: String?
    let fieldType: String?
    let defaultUnit: String?
    let isActive: Bool?
    let dataEntryMethod: String?

    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case fieldName = "field_name"
        case category
        case inputType = "input_type"
        case fieldType = "field_type"
        case defaultUnit = "default_unit"
        case isActive = "is_active"
        case dataEntryMethod = "data_entry_method"
    }
}
