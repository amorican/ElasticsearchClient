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

public enum SearchableListEditError: Error {
    case custom([LocalizedError])
}

extension SearchableListEditError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .custom(let errors):
            var errorText = ""
            for (index, error) in errors.enumerated() {
                if index > 0 {
                    errorText.append("\n")
                }
                errorText.append(error.localizedDescription)
            }
            return errorText
        }
    }
}


public class SearchableListEditMonitor {
    
    public var editOptions = [SearchableListEditOption]()
    public var editOptionStateDidChange: ((_: SearchableListEditOption) -> Void)?
    
    public func editOption(withTitle title: String, isInternal: Bool, isEnabled: Bool, executer: @escaping SearchableListEditExecution) -> BaseEditOption {
        return BaseEditOption(title: title, isInternal: isInternal, isEnabled: isEnabled, monitor: self, executer: executer)
    }
    
    func start(_ editOption: SearchableListEditOption) {
        self.editOptions.append(editOption)
        self.editOptionStateDidChange?(editOption)
    }
    
    func finish(_ editOption: SearchableListEditOption) {
        self.editOptionStateDidChange?(editOption)
    }
}

public protocol SearchableListEditOption: class {
    
    var monitor: SearchableListEditMonitor? { get set }
    var title: String { get set }
    var isEnabled: Bool { get set }
    var backgroundStateIsOn: Bool { get set }
    var errors: [Error] { get set }
    
    /// When set to `true`, indicates that the option is not made available to the app user (thru the UI).
    var isInternal: Bool { get set }
    
    var executer: SearchableListEditExecution { get set }
    
    init()
    init(title: String, isInternal: Bool, isEnabled: Bool, monitor: SearchableListEditMonitor, executer: @escaping SearchableListEditExecution)
}

extension SearchableListEditOption {
    
    public init(title: String, isInternal: Bool, isEnabled: Bool, monitor: SearchableListEditMonitor, executer: @escaping SearchableListEditExecution) {
        self.init()
        self.title = title
        self.isInternal = isInternal
        self.isEnabled = isEnabled
        self.monitor = monitor
        self.executer = executer
        self.backgroundStateIsOn = false
    }
    
    public init(title: String, isInternal: Bool, isEnabled: Bool, executer: @escaping SearchableListEditExecution) {
        self.init()
        self.title = title
        self.isInternal = isInternal
        self.isEnabled = isEnabled
        self.executer = executer
        self.backgroundStateIsOn = false
    }
    
    public func run(completion: SearchableListEditCompletion?) {
        self.backgroundStateIsOn = true
        self.monitor?.start(self)
        self.executer() { results, error in
            
            if let theError = error {
                self.errors.append(theError)
            }
            
            self.backgroundStateIsOn = false
            self.monitor?.finish(self)
            completion?(results, error)
        }
    }
    
    public var hasErrors: Bool {
        get {
            return self.errors.count > 0
        }
    }
}

public class BaseEditOption: SearchableListEditOption {
    
    public var monitor: SearchableListEditMonitor?
    public var title: String
    public var identifier: String?
    public var isEnabled: Bool
    public var isInternal: Bool
    public var executer: SearchableListEditExecution
    public var backgroundStateIsOn: Bool
    public var errors = [Error]()
    
    required public init() {
        title = ""
        isEnabled = false
        isInternal = true
        backgroundStateIsOn = false
        executer = { completion in }
    }
}
