//
//  ElasticsearchHit.swift
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

public struct ElasticsearchHit<T : Searchable> : ElasticsearchDocumentHeader {
    
    typealias documentSourceType = T
    var json : JSON?
    
    public var esId: String?
    public var esIndex: String?
    public var esType: String?
    public var esScore: Float?
    public var esSource: T?
    
    public init?(json: JSON) {
        self.json = json
        self.esId = "_id" <~~ json
        self.esIndex = "_index" <~~ json
        self.esType = "_type" <~~ json
        self.esScore = "_score" <~~ json
        self.esSource = "_source" <~~ json
    }
    
    public func toJSON() -> JSON? {
        return self.json
    }
}

