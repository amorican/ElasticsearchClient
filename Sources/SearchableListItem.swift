//
//  SearchableListItem.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
//

import Foundation
import Gloss

public class SearchableListItem<T: Searchable> {
    
    public var id: Int
    public var document: T?
    public var attributes = JSON()
    
    public init(withSearchableId searchableId: Int) {
        self.id = searchableId
    }
    
    public convenience init(withDocument document: T) {
        let id = document.id ?? -1
        self.init(withSearchableId: id)
        self.document = document
    }
}

extension SearchableListItem: Equatable {
    public static func ==(lhs:SearchableListItem, rhs:SearchableListItem) -> Bool {
        return lhs === rhs
    }
}

extension SearchableListItem: CustomStringConvertible {
    
    public var description: String {
        get {
            var description = "<\(type(of: self)) - id:\(self.id)"
            var attributesStringArray = [String]()
            for (key, value) in attributes {
                attributesStringArray.append("\(key):\(value)")
            }
            if attributesStringArray.count > 0 {
                description = description + " <attributes - \(attributesStringArray.joined(separator: ", "))>"
            }
            if let item = document {
                description = description + " item:\(item)"
            }

            description = description + ">"
            return description
        }
    }
}
