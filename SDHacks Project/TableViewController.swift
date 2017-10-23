//
//  TableViewController.swift
//  SDHacks Project
//
//  Created by Toshitaka on 10/21/17.
//  Copyright © 2017 Toshitaka. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {
    
    var check = false
    var settings = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if check {
            settings =  ["Automatic Switching","Front: ","Back: ","Speaker Recognition"]
        }
        else {
            settings =  ["Automatic Switching","Speaker Recognition"]
        }
        
        tableView.tableFooterView = UIView()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settings.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if check {
            if (indexPath.row == 0)||(indexPath.row == 3) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "mainSettingCell", for: indexPath) as! mainSettingCell
                cell.settingLabel.text = settings[indexPath.row]
                cell.switchButton.restorationIdentifier = settings[indexPath.row]
                cell.selectionStyle = .none
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "subSettingCell", for: indexPath) as! subSettingCell
                cell.settingLabel.text = settings[indexPath.row]
                cell.selectionStyle = .none
                return cell
            }
        }
        else {
            //automatic switching not on
            let cell = tableView.dequeueReusableCell(withIdentifier: "mainSettingCell", for: indexPath) as! mainSettingCell
            cell.settingLabel.text = settings[indexPath.row]
            cell.switchButton.restorationIdentifier = settings[indexPath.row]
            cell.selectionStyle = .none
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if check {
            if (indexPath.row == 0)||(indexPath.row == 3) {
                return 70
            }
            else {
                return 60
            }
        }
        else {
            return 70
        }
    }
    
    @IBAction func switchPressed(_ sender: UISwitch) {
        if(sender.restorationIdentifier == settings[0]) {
            if check {
                check = false
            } else {
                check = true
            }
        
            if check {
                settings =  ["Automatic Switching","Front: ","Back: ","Speaker Recognition"]
            }
            else {
                settings =  ["Automatic Switching","Speaker Recognition"]
            }
            tableView.reloadData()
        }
    }
}
