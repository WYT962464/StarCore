import UIKit

class StarCoreViewController: UIViewController {
    
    let helloLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 最最简单的黑底
        view.backgroundColor = .black
        
        // 只显示一个文本，确保能跑起来
        helloLabel.frame = CGRect(x: 0, y: 200, width: view.frame.width, height: 100)
        helloLabel.text = "✨ 星核启动！✨"
        helloLabel.textColor = .white
        helloLabel.textAlignment = .center
        helloLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        view.addSubview(helloLabel)
    }
}
