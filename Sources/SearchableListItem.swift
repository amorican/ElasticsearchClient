//
//  SearchableListItem.swift
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
