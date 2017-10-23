//
//  mainSettingCell.swift
//  SDHacks Project
//
//  Created by Toshitaka on 10/21/17.
//  Copyright © 2017 Toshitaka. All rights reserved.
//

import UIKit

class mainSettingCell: UITableViewCell {

    @IBOutlet weak var settingLabel: UILabel!
    @IBOutlet weak var switchButton: UISwitch!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

//    @IBAction func switchPressed(_ sender: UISwitch) {
//        if(sender.isOn == true) {
//            mode = true
//        }
//        else {
//            mode = false
//        }
//    }
}
