//
//  SearchableListEditorState.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
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
