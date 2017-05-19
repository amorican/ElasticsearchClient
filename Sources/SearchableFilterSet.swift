//
//  SearchableFilterSet.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
//

import Foundation
import Gloss

public protocol SearchableFilterSet {
    
    func convertToQuery() -> JSON
    func setListDocument<T: SearchableList>(_: T)
}
