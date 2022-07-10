//___FILEHEADER___

import UIKit
import Combine

final class ___FILEBASENAME___: UIViewController, StoryboardView{
    typealias Action = ___VARIABLE_productName___Way.Action
    
    //MARK: - Propeties
    
    private let way: ___VARIABLE_productName___Way
    private var cancellables = Set<AnyCancellable>()
    
    //MARK: - Init
    init(way : ___VARIABLE_productName___Way) {
        self.way = way
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
