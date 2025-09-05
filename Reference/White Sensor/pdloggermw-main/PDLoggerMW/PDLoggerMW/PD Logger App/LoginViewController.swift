//
//  LoginViewController.swift
//  PDLoggerMW
//
//  Created by Rio on 14/11/24.
//

import UIKit
import LocalAuthentication

class LoginViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet var usernameField: UITextField!
    @IBOutlet var passwordField: UITextField!
    @IBOutlet weak var passwordHint: UILabel!
    @IBOutlet weak var pdLogo: UIImageView!
    @IBOutlet weak var biometricLogin: UIButton!
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        usernameField.delegate = self
        passwordField.delegate = self
        
        pdLogo.setRounded()
        
        // set up Biometric login
        //if biometricType() == .none {
        biometricLogin.isHidden = true
        biometricLogin.isEnabled = false
        //}
//        else {
//            let biometricLoginImage = biometricLogin.currentImage
//            let newImage = biometricLoginImage?.resizedImage(Size: biometricLogin.frame.size)
//            biometricLogin.setImage(newImage, for: .normal)
//            biometricLogin.setTitle("", for: .normal)
//        }
        
        
        if let navigationBar = navigationController?.navigationBar {
                navigationBar.setBackgroundImage(UIImage(), for: .default) // Clear the background image
                navigationBar.shadowImage = UIImage()                     // Remove the shadow line
                navigationBar.isTranslucent = true                        // Enable translucency
                navigationBar.backgroundColor = UIColor.clear             // Set background color to clear
            }
    }
    
    @IBAction func loginTapped()
    {
        // when username and password are filled, and current user is "me", save user
        if usernameField.hasText && passwordField.hasText {
            if Settings.shared.user.name == "me" || usernameField.text == "me" { // if no user or resetting user
                createNewUser()
                navigateToParticipants()
            }
            else if validPassword() {  // check if password matches
                navigateToParticipants()
            }
            else {
                showHint()
            }
        }
        else if Settings.shared.user.name == "me" { // login without password if no user set
            navigateToParticipants()
        }
    }
    
    private func navigateToParticipants()
    {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ParticipantsViewController") as? ParticipantsViewController {
            //self.present(vc, animated: false , completion: nil)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func createNewUser()
    {
        let newUser = User(name: usernameField.text!.lowercased(),
                           passwordHash: EncDec.SHA512(passwordField.text!),
                           passwordHint: "\(usernameField.text!) created this password on \(Date())")
        Settings.shared.user = newUser
        Settings.shared.saveUser()
    }
    
    private func validPassword()->Bool
    {
        Settings.shared.user.name == usernameField.text!.lowercased()
        && Settings.shared.user.passwordHash == EncDec.SHA512(passwordField.text!)
    }
    
    func showHint()
    {
        passwordHint.text = Settings.shared.user.passwordHint
        passwordHint.isHidden = false
        passwordHint.textColor = .brown
    }
    
    // MARK: - Biometric login
    enum BiometricType
    {
        case none, touch, face
    }
    
    /// Get device supported biometric type in LocalAuthentication
    func biometricType() -> BiometricType
    {
        let authContext = LAContext()
        if #available(iOS 11, *) {
            let _ = authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            return switch authContext.biometryType {
                case .touchID: .touch
                case .faceID: .face
                default: .none
            }
        } else {
            return authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? .touch : .none
        }
    }
    
    @IBAction func biometricAuth(_ sender: Any) 
    {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "PDLogger authentication"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) {
                [weak self] success, authenticationError in
                guard let self = self else {return}
                DispatchQueue.main.async {
                    if success {
                        self.navigateToParticipants()
                    }
                    else {
                        Utils.alert(self, title: "Authentication failed", message: "Touch/Face ID not recognised")
                    }
                }
            }
        }
    }
    
}
