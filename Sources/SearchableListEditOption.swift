//
//  SearchableListEditOption.swift
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

public typealias SearchableListEditCompletion = (_: Any?, _: Error?) -> Void
public typealias SearchableListEditExecution = (_: SearchableListEditCompletion?) -> Void

public protocol SearchableListEditOption {
    var title: String { get set }
    var isEnabled: Bool { get set }
    
    /// When set to `true`, indicates that the option is not made available to the app user (thru the UI).
    var isInternal: Bool { get set }
    
    var executer: SearchableListEditExecution { get set }
    
    init()
    init(title: String, isInternal: Bool, isEnabled: Bool, executer: @escaping SearchableListEditExecution)
}

extension SearchableListEditOption {
    
    public init(title: String, isInternal: Bool, isEnabled: Bool, executer: @escaping SearchableListEditExecution) {
        self.init()
        self.title = title
        self.isInternal = isInternal
        self.isEnabled = isEnabled
        self.executer = executer
    }
    
    public func run(completion: SearchableListEditCompletion?) {
        self.executer(completion)
    }
}

public class BaseEditOption: SearchableListEditOption {
    
    public var title: String
    public var isEnabled: Bool
    public var isInternal: Bool
    public var executer: SearchableListEditExecution
    
    required public init() {
        title = ""
        isEnabled = false
        isInternal = true
        executer = { completion in }
    }
}
