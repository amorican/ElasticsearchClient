//
//  SearchableListEditOption.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
//

import Foundation

public protocol SearchableListEditOption {
    var title: String { get set }
    var isEnabled: Bool { get set }
    
    /// When set to `true`, indicates that the option is not made available to the app user (thru the UI).
    var isInternal: Bool { get set }
    
    var runner: (Void) -> Void { get set }
    
    init()
    init(title: String, isInternal: Bool, isEnabled: Bool, runner: @escaping (() -> Void))
}

extension SearchableListEditOption {
    
    public init(title: String, isInternal: Bool, isEnabled: Bool, runner: @escaping (() -> Void)) {
        self.init()
        self.title = title
        self.isInternal = isInternal
        self.isEnabled = isEnabled
        self.runner = runner
    }
}

public class BaseEditOption: SearchableListEditOption {
    
    public var title: String
    public var isEnabled: Bool
    public var isInternal: Bool
    public var runner: (Void) -> Void
    
    required public init() {
        title = ""
        isEnabled = false
        isInternal = true
        runner = {}
    }
}
