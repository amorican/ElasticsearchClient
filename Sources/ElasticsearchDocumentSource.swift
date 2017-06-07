//
//  ElasticsearchDocumentSource.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
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


public struct ElasticsearchDocumentSource : Searchable {
    
    public static var typeName = ""
    public static var excludedFieldsInDefaultSearch : [String]?
    
    
    public var json : JSON?
    public var id : Int?
    
    public init?(json: JSON) {
        
        self.json = json
        
        self.id = anyToInt(json["id"])
        
    }
    
    public func toJSON() -> JSON? {
        return self.json
    }
    
    public func convert<U : Searchable>() -> U? {
        guard let json = self.json else {
            return nil
        }
        return U(json: json)
    }
}

// MARK: - Query Builder

extension ElasticsearchDocumentSource {
    
    public static var sortFieldNamesMap: [String: String]? {
        get {
            return nil
        }
    }
    
    public static func buildQuery(from filtersObject: Any) -> JSON {
        return filtersObject as? JSON ?? JSON()
    }
}
