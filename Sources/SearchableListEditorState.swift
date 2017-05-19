//
//  SearchableListEditorState.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
//

import Foundation
import SimpleStateMachine


public enum SearchableListEditorState<T: SearchableList, U: Searchable>: SimpleStateMachineState, Equatable {
    case ready
    case fetchingSearchableList
    case searchableListFetched(T)
    case fetchingDocuments
    case partialDocumentsFetched([SearchableListItem<U>])
    case allDocumentsFetched([SearchableListItem<U>])
    case failure(Error)
    
    public func canTransition(from: SearchableListEditorState, to: SearchableListEditorState) -> Bool {

        switch (from, to) {
        case (_, .ready):
            return true
        case (_, .failure(_)):
            return true
        case (.ready, .fetchingDocuments):
            return true
        case (.ready, .fetchingSearchableList):
            return true
        case (.fetchingSearchableList, .searchableListFetched(_)):
            return true
        case (.searchableListFetched(_), .fetchingDocuments):
            return true
        case (.fetchingDocuments, .partialDocumentsFetched(_)):
            return true
        case (.fetchingDocuments, .allDocumentsFetched(_)):
            return true
        case (.partialDocumentsFetched(_), .fetchingDocuments):
            return true
        case (.partialDocumentsFetched(_), .partialDocumentsFetched(_)):
            return true
        case (.partialDocumentsFetched(_), .allDocumentsFetched(_)):
            return true
        default:
            return false
        }
    }
    
    public static func == (left: SearchableListEditorState, right: SearchableListEditorState) -> Bool {
        switch (left, right) {
        case (.ready, .ready):
            return true
        case (.fetchingSearchableList, .fetchingSearchableList):
            return true
        case (.searchableListFetched, .searchableListFetched):
            return true
        case (.fetchingDocuments, .fetchingDocuments):
            return true
        case (.partialDocumentsFetched, .partialDocumentsFetched):
            return true
        case (.allDocumentsFetched, .allDocumentsFetched):
            return true
        case (.failure, .failure):
            return true
        default:
            return true
        }
    }
}
