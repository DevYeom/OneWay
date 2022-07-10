//___FILEHEADER___

import Foundation
import OneWay

final class ___FILEBASENAME___: Way<___FILEBASENAME___.Action, ___FILEBASENAME___.State> {
    
    enum Action {
        // actiom cases
    }
    
    struct State {
        //state
    }
        
    init(initialState: State) {
        super.init(initialState: initialState)
    }
    
    //MARK: - reduce
    override func reduce(state: inout State, action: Action) -> SideWay<Action, Never> {
//        switch action{
//        }
    }
    
    //MARK: - Bind
    override func bind() -> SideWay<Action, Never> {
        
    }
}
