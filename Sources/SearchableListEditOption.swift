//
//  SearchableListEditOption.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
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
