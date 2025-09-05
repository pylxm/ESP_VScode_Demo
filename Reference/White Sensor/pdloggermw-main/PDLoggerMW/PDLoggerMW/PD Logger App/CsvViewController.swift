//
//  CsvViewController.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 20/11/24.
//

import UIKit

class CsvViewController: UIViewController
{
    @IBOutlet var csvView: CsvViewer!
    var filePath:URL!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        //Just one line of code to show csv here
        csvView.readAndShowCsv(filePath: filePath)
    }
}
