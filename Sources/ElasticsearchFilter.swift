//
//  ElasticsearchFilter.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/15/17.
//
//

import Foundation
import Gloss

public protocol ElasticsearchFilter {
    static func getQuery(forFilters trackFilters: [Self]) -> JSON
}

fileprivate class SearchableDateFormatter {
    
    static let elasticSearchDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

public extension ElasticsearchFilter {
    
    static private var dateFormatter: DateFormatter {
        get {
            return SearchableDateFormatter.elasticSearchDateFormatter
        }
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIntValue intValue: Int?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getCondition(forIntValue: intValue, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIntValues values: [Int]?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getCondition(forIntValues: values, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIds stringValues: [String]?, mustIncludeAll includeAll: Bool, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        
        if let condition = getCondition(forStringValues: stringValues, mustIncludeAllTags: includeAll, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        
        return amendedConditions
    }
    
    static public func wildcardCondition(forExistingConditions conditions: [JSON], withSearchText searchText: String?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getWildcardCondition(forSeachText: searchText, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withSearchText searchText: String?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getCondition(forSeachText: searchText, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withDateRangeFrom minDate: Date?, toDate maxDate: Date?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        
        if let condition = getContition(forDateRangeMinDate: minDate, maxDate: maxDate, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIntRangeFrom minValue: Int?, toValue maxValue: Int?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        
        if let condition = getContition(ForIntRangeMinValue: minValue, maxValue: maxValue, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func getCondition(forIntValue intValue: Int?, fieldName: String) -> JSON? {
        guard let searchValue = intValue else {
            return nil
        }
        return ["term": [fieldName: searchValue]]
    }
    
    static fileprivate func getCondition(forStringValues stringValues: [String]?, mustIncludeAllTags includeAll: Bool, fieldName: String) -> JSON? {
        guard let stringValues = stringValues, stringValues.count > 0 else {
            return nil
        }
        
        let includeAny = !includeAll
        if includeAny {
            return ["terms": [fieldName: stringValues]]
        }
        
        var tagFilters = [JSON]()
        
        for id in stringValues {
            tagFilters.append(["term": [fieldName: id]])
        }
        return ["bool": ["must": tagFilters]]
    }

    static public func getCondition(forIntValues values: [Int]?, fieldName: String) -> JSON? {
        guard let searchValues = values else {
            return nil
        }
        return ["terms": [fieldName: searchValues]]
    }
    
    static public func getCondition(forSeachText searchText: String?, fieldName: String) -> JSON? {
        guard let searchText = searchText, !searchText.isEmpty else {
            return nil
        }
        
        return ["term" : [fieldName : searchText]]
    }
    
    static public func getWildcardCondition(forSeachText searchText: String?, fieldName: String) -> JSON? {
        guard var searchText = searchText, !searchText.isEmpty else {
            return nil
        }
        
        var termLevelKey = "term"
        
        // We add wildcard characters, unless the string is quoted.
        if searchText.hasPrefix("\"") && searchText.hasSuffix("\"") {
            searchText.remove(at: searchText.characters.index(before: searchText.endIndex))
            searchText.remove(at: searchText.startIndex)
        }
        else {
            if !searchText.contains("*") {
                searchText = "*\(searchText)*"
            }
            termLevelKey = "wildcard"
        }
        var fieldName = fieldName
        if !fieldName.hasSuffix(".raw_lowercase") {
            fieldName = fieldName.appending(".raw_lowercase")
        }
        
        return [termLevelKey : [fieldName : searchText.lowercased()]]
    }
    
    static public func getContition(forDateRangeMinDate minDate: Date?, maxDate: Date?, fieldName: String) -> JSON? {
        if minDate == nil && maxDate == nil {
            return nil
        }
        
        var dateRange = JSON()
        if let minDate = minDate {
            dateRange["gte"] = dateFormatter.string(from: minDate)
        }
        
        if let maxDate = maxDate {
            var components = DateComponents()
            components.day = 1
            if let adjustedMaxDate = Calendar.current.date(byAdding: components, to: maxDate) {
                dateRange["lt"] = dateFormatter.string(from: adjustedMaxDate)
            }
        }
        
        dateRange["format"] = "yyyy-MM-dd hh:mm:ss||yyyy-MM-dd"
        
        return ["range": [fieldName: dateRange]]
    }
    
    static public func getContition(ForIntRangeMinValue minValue: Int?, maxValue: Int?, fieldName: String) -> JSON? {
        if minValue == nil && maxValue == nil {
            return nil
        }
        var valueRange = JSON()
        if minValue ?? 0 > 0 {
            valueRange["gte"] = minValue ?? 0
        }
        if maxValue ?? 0 > 0 {
            valueRange["lte"] = maxValue ?? 0
        }
        
        return ["range": [fieldName: valueRange]]
    }
}














public protocol SearchableFilter {
    
}

public extension SearchableFilter {
    
    static private var dateFormatter: DateFormatter {
        get {
            return SearchableDateFormatter.elasticSearchDateFormatter
        }
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIntValue intValue: Int?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getCondition(forIntValue: intValue, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIntValues values: [Int]?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getCondition(forIntValues: values, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIds stringValues: [String]?, mustIncludeAll includeAll: Bool, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        
        if let condition = getCondition(forStringValues: stringValues, mustIncludeAllTags: includeAll, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        
        return amendedConditions
    }
    
    static public func wildcardCondition(forExistingConditions conditions: [JSON], withSearchText searchText: String?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getWildcardCondition(forSeachText: searchText, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withSearchText searchText: String?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        if let condition = getCondition(forSeachText: searchText, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withDateRangeFrom minDate: Date?, toDate maxDate: Date?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        
        if let condition = getContition(forDateRangeMinDate: minDate, maxDate: maxDate, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func condition(forExistingConditions conditions: [JSON], withIntRangeFrom minValue: Int?, toValue maxValue: Int?, forFieldName fieldName: String) -> [JSON] {
        var amendedConditions = conditions
        
        if let condition = getContition(ForIntRangeMinValue: minValue, maxValue: maxValue, fieldName: fieldName) {
            amendedConditions.append(condition)
        }
        return amendedConditions
    }
    
    static public func getCondition(forIntValue intValue: Int?, fieldName: String) -> JSON? {
        guard let searchValue = intValue else {
            return nil
        }
        return ["term": [fieldName: searchValue]]
    }
    
    static fileprivate func getCondition(forStringValues stringValues: [String]?, mustIncludeAllTags includeAll: Bool, fieldName: String) -> JSON? {
        guard let stringValues = stringValues, stringValues.count > 0 else {
            return nil
        }
        
        let includeAny = !includeAll
        if includeAny {
            return ["terms": [fieldName: stringValues]]
        }
        
        var tagFilters = [JSON]()
        
        for id in stringValues {
            tagFilters.append(["term": [fieldName: id]])
        }
        return ["bool": ["must": tagFilters]]
    }
    
    static public func getCondition(forIntValues values: [Int]?, fieldName: String) -> JSON? {
        guard let searchValues = values else {
            return nil
        }
        return ["terms": [fieldName: searchValues]]
    }
    
    static public func getCondition(forSeachText searchText: String?, fieldName: String) -> JSON? {
        guard let searchText = searchText, !searchText.isEmpty else {
            return nil
        }
        
        return ["term" : [fieldName : searchText]]
    }
    
    static public func getWildcardCondition(forSeachText searchText: String?, fieldName: String) -> JSON? {
        guard var searchText = searchText, !searchText.isEmpty else {
            return nil
        }
        
        var termLevelKey = "term"
        
        // We add wildcard characters, unless the string is quoted.
        if searchText.hasPrefix("\"") && searchText.hasSuffix("\"") {
            searchText.remove(at: searchText.characters.index(before: searchText.endIndex))
            searchText.remove(at: searchText.startIndex)
        }
        else {
            if !searchText.contains("*") {
                searchText = "*\(searchText)*"
            }
            termLevelKey = "wildcard"
        }
        var fieldName = fieldName
        if !fieldName.hasSuffix(".raw_lowercase") {
            fieldName = fieldName.appending(".raw_lowercase")
        }
        
        return [termLevelKey : [fieldName : searchText.lowercased()]]
    }
    
    static public func getContition(forDateRangeMinDate minDate: Date?, maxDate: Date?, fieldName: String) -> JSON? {
        if minDate == nil && maxDate == nil {
            return nil
        }
        
        var dateRange = JSON()
        if let minDate = minDate {
            dateRange["gte"] = dateFormatter.string(from: minDate)
        }
        
        if let maxDate = maxDate {
            var components = DateComponents()
            components.day = 1
            if let adjustedMaxDate = Calendar.current.date(byAdding: components, to: maxDate) {
                dateRange["lt"] = dateFormatter.string(from: adjustedMaxDate)
            }
        }
        
        dateRange["format"] = "yyyy-MM-dd hh:mm:ss||yyyy-MM-dd"
        
        return ["range": [fieldName: dateRange]]
    }
    
    static public func getContition(ForIntRangeMinValue minValue: Int?, maxValue: Int?, fieldName: String) -> JSON? {
        if minValue == nil && maxValue == nil {
            return nil
        }
        var valueRange = JSON()
        if minValue ?? 0 > 0 {
            valueRange["gte"] = minValue ?? 0
        }
        if maxValue ?? 0 > 0 {
            valueRange["lte"] = maxValue ?? 0
        }
        
        return ["range": [fieldName: valueRange]]
    }
}


