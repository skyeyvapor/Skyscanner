//
//  CustomTableCell.swift
//  Skyscanner
//
//  Created by Ching-Lan Chen on 2018/1/7.
//  Copyright © 2018年 Ching-Lan Chen. All rights reserved.
//

import Foundation
import UIKit
class CustomTableCell: UITableViewCell {


    @IBOutlet weak var outboundImageView: UIImageView!
    
    @IBOutlet weak var outboundTimeLabel: UILabel!
    
    @IBOutlet weak var outboundStationLabel: UILabel!
    
    @IBOutlet weak var outboundDurationLabel: UILabel!
    
    @IBOutlet weak var inboundImageView: UIImageView!
    
    @IBOutlet weak var inboundTimeLabel: UILabel!
    
    @IBOutlet weak var inboundStationLabel: UILabel!
    
    @IBOutlet weak var inboundDurationLabel: UILabel!
    
    
    @IBOutlet weak var priceLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        

    }

    override func layoutIfNeeded() {
        super.layoutIfNeeded()
    }

    
}

