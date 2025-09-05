//
//  ParticipantsViewController.swift
//  PDLoggerMW
//
//  Created by Rio on 14/11/24.
//

import UIKit

class ParticipantsViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var participantIdField: UITextField!
    @IBOutlet weak var pdLogo: UIImageView!
    var allowedCharacterSet:CharacterSet!
    
    override func viewDidLoad()
    {
        participantIdField.delegate = self
        pdLogo.setRounded()
        
        // set allowed characters for participant ID
        allowedCharacterSet = CharacterSet.alphanumerics
        allowedCharacterSet.insert(charactersIn: "-_")
    }
    
    @IBAction func selectionTapped(_ sender: UIButton)
    {
        // Dismiss the keyboard
        view.endEditing(true)

        // Exit if patient id is not filled
        guard let participantId = participantIdField.text, !participantId.isEmpty else {return}
        Utils.log("Participant ID: \(participantId)")
        
        // Create the Assessment Selection alert controller
        let alertController = UIAlertController(title:  nil, message: nil, preferredStyle: .actionSheet)
        
        // Define your list of exercises
        let assessments = Settings.shared.assessments.map{$0.name}

        // Add an action for each exercise
        for (i, assessment) in assessments.enumerated() {
            let action = UIAlertAction(title: assessment, style: .default) { _ in
                // Handle exercise selection here
                Settings.shared.patient = Patient(id: participantId, assessment: Settings.shared.assessments[i])
                
                // Present to Sensor View Controller
                let storyboard = UIStoryboard(name: "Main", bundle: .main)
                if let vc = storyboard.instantiateViewController(withIdentifier: "SensorViewController") as? SensorViewController {
                    self.navigationController?.pushViewController(vc, animated: false)
                }
            }
            alertController.addAction(action)
        }

        // Add a cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        // Set the popover presentation controller's sourceView and sourceRect
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = sender  // The button that triggers the alert
            popoverController.sourceRect = sender.bounds  // Anchor to the button
            popoverController.permittedArrowDirections = .up
        }

        // Present the alert controller
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func showPastRecords(_ sender: Any) 
    {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "FileMan") as? FilesTableViewController {
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool 
    {
        // can validate characters allowed for participant ID
        string.isEmpty || Utils.validateString(string: string, patterns: [allowedCharacterSet], match: .inAll)
    }
}
