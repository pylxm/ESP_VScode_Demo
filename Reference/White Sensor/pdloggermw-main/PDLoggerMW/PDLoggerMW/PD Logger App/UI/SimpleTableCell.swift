//
//  SimpleTableViewCell.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 28/11/24.
//

import UIKit

class SimpleTableCell: UITableViewCell
{
    @IBOutlet var parameterLabels: [UILabel]!
    @IBOutlet var parameterValues: [UILabel]!
    @IBOutlet weak var patientIDLabel: UILabel!
    @IBOutlet weak var exerciseDateLabel: UILabel!
    @IBOutlet weak var repLabel: UILabel!
}
