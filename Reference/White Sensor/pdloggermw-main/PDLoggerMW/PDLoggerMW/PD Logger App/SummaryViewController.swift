//
//  SummaryViewController.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 28/11/24.
//

import UIKit

class SummaryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    @IBOutlet weak var typeOfAssessmentLabel: UILabel!
    @IBOutlet weak var summaryTableView: UITableView!
    @IBOutlet weak var doneButton: UIButton!
    
    var patient:Patient!
    var formatter:DateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        patient = Settings.shared.patient
        formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy HH:mm"
        
        // round buttons
        doneButton.layer.cornerRadius = doneButton.frame.height * 0.2
        
        // set up table
        typeOfAssessmentLabel.text = "Summary of \(patient.assessment.name)"
        let cellNib = UINib(nibName: "SimpleTableCell", bundle:nil)
        summaryTableView.register(cellNib, forCellReuseIdentifier: "SimpleTableCell")
        summaryTableView.delegate = self
        summaryTableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        summaryTableView.reloadData()
    }
    
    @IBAction func doneButtonPressed(_ sender: Any) 
    {
        self.dismiss(animated: true)
    }
    
    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int
    {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        patient.assessmentRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SimpleTableCell", for: indexPath) as! SimpleTableCell
        cell.repLabel.text = "Rep: \(indexPath.row + 1)"
        cell.patientIDLabel.text = patient.id
        cell.exerciseDateLabel.text = formatter.string(from: patient.assessmentDates[indexPath.row])
        Utils.log("Table data: cell at \(indexPath.row)")
        let summaryData = patient.assessmentRecords[indexPath.row]
        for (i, row) in summaryData.enumerated() {
            if i == cell.parameterLabels.count {break}  // limit to number of parameters available for display
            let label = row.split(separator: ",")[0]
            let value = row.split(separator: ",")[1]
            cell.parameterLabels[i].text = String(label)
            cell.parameterValues[i].text = String(value)
        }
        
        // hide the rest of the parameter rows
        for i in summaryData.count..<cell.parameterLabels.count {
            cell.parameterLabels[i].isHidden = true
            cell.parameterValues[i].isHidden = true
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        350
    }
}
