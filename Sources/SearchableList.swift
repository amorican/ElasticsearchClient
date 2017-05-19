//
//  SearchableList.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
//

import Foundation
import Gloss

public protocol SearchableList : Searchable, CustomStringConvertible {
    
    /**
     When set to `false`, the `SearchableListFetcher` will automatically page the results for better performance.
     Set this to `true` when the SearchableList requires for some reason all the item documents to be loaded, most typically
     for a local sort.
     - Remark: Use wisely! Make sure the the SearchableList query generated from `getItemQueryCondition<T>(_:)` is restrictive
     enough to prevent from fetching an un-reasonable amount of Elasticsearch documents.
     */
    var editorRequiresAllDocuments: Bool { get }
    
    /**
     The known number of items in the `SearchableList`.
     This only has a value when the `SearchableList` is able to provide the number of items before fetching the item documents.
     */
    var listItemsCount: Int? { get }
    
    /**
     Defines the field names that a `SearchableListEditor` should use to sort the fetched items locally (i.e. on the client side).
     When the `SearchableListEditor` is init'd with a `sortedBy` value contained in this array, the `SearchableListFetched` will
     automatically fetch all the items so they can be sorted locally.
     */
    var keysRequiringLocalSort: [String] { get }
    
    /**
     Creates one or many `SearchableListItem` representing the fetched document items.
     */
    func createListItems<U>(forDocument document: U) -> [SearchableListItem<U>]
    
    /**
     - Returns: The Elasticsearch `JSON` query to run on the type `T` to get the `SearchableList`'s items of type `T`.
     */
    func getItemQueryCondition<T: Searchable>(forType type: T.Type) -> JSON?
    
    func canRemoveListItems<U: Searchable>(_: [SearchableListItem<U>]) -> Bool
    mutating func removeListItems<U: Searchable>(_ listItems: [SearchableListItem<U>], fromItemList originalList: [SearchableListItem<U>]) -> [SearchableListItem<U>]
    mutating func moveListItems<U: Searchable>(_ listItems: [SearchableListItem<U>], toPosition position: Int, inItemList originalList: [SearchableListItem<U>]) -> [SearchableListItem<U>]
    
    /** Creates the edit options available on the `SearchableList` for a selection of items
     */
    static func createEditOptions<T: SearchableList, U: Searchable>(forItems: [SearchableListItem<U>], inItemList originalList: [SearchableListItem<U>], ofSearchableList: T, completion: @escaping (_ mutatedSearchableList: T, _ updatedItems: [SearchableListItem<U>]) -> Void) -> [SearchableListEditOption]
}

extension SearchableList {
    
    public func localSortIsRequired(forFieldName key: String) -> Bool {
        return self.keysRequiringLocalSort.contains(key)
    }
    
    public func sortedItems<T>(_ listItems: [SearchableListItem<T>], withKey key: String, ascending: Bool) -> [SearchableListItem<T>] {
        let items = listItems.sorted { (item1:SearchableListItem<T>, item2:SearchableListItem<T>) -> Bool in
            //TODO: Implement other types
            guard let value1 = item1.attributes[key] as? Int, let value2 = item2.attributes[key] as? Int else {
                return false
            }
            return ascending ? value1 < value2 : value1 > value2
        }
        return items
    }
}

extension SearchableList {

    public var description: String {
        get {
            var description = "<\(type(of: self)) -"
            let id = self.id == nil ? "nil" : String(self.id!)
            let name = self.json?["name"] ?? "-nil-"
            description = description + " id:\(id) name:\(name)"
            description = description + ">"
            return description
        }
    }

    public func titleForListItems<T: Searchable>(_ items: [SearchableListItem<T>]) -> String {

        var title = "\(items.count) \(T.self)"
        if items.count > 1 {
            title = title + "s"
        }

        if items.count == 1, let name = items[0].document?.json?["name"] as? String {
            title = "\"\(name)\""
        }
        return title
    }
    
    public func indexSet<U: Equatable>(ofItems items: [U], inList list: [U]) -> IndexSet {
        var indexSet = IndexSet()
        for item in items {
            if let index = list.index(of: item), index > -1 {
                indexSet.insert(index)
            }
        }
        return indexSet
    }
}

