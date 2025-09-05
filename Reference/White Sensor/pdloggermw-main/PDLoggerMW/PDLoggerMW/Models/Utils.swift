//
//  Utils.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 14/11/24.
//

import Foundation
import UIKit

struct Utils
{
    static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            return formatter
        }()
    
    static func log(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line)
    {
        let filename = file.components(separatedBy: "/").last!
        print("\(dateFormatter.string(from: Date()))|DEBUG|\(filename.prefix(filename.count-6))|\(function)|\(line)|\(message)")
    }
    
    /// convert dictionary to JSON string
    static func json(dict: [String:Any]) -> String?
    {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
    
    /// convert JSON string or data to dictionary of type String:Any
    static func dict(json: Any) -> [String:Any]
    {
        if let jsonData = json as? Data {
            return (try? JSONSerialization.jsonObject(with: jsonData) as? [String:Any]) ?? [:]
        }
        if let jsonString = json as? String {
            return (try? JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as? [String:Any]) ?? [:]
        }
        return [:]
    }
    
    /// pop up an alert prompt
    /// - parameter vc: presenting UI view controller
    /// - parameter title: pop up title
    /// - parameter message: message
    /// - parameter actions: array of UIAlertAction, default is OK
    /// - parameter hold: time to dismiss pop up if actions is empty and hold is > 0
    /// - parameter configure: configure alert view controller before presenting
    /// - parameter completion: code to run after presenting UI before UI actions
    static func alert(_ vc:UIViewController, title:String?, message:String?, actions:[UIAlertAction] = [], hold:TimeInterval = 0, configure:((UIAlertController)->())? = nil, completion:((UIAlertController)->())? = nil)
    {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.view.tintColor = #colorLiteral(red: 0, green: 0.6784313725, blue: 0.7098039216, alpha: 1)
            let currentTime = Date()
            if actions.isEmpty && configure == nil {  // default action only when actions and configure are not provided
                if hold == 0 {  // ok prompt
                    let okAction = UIAlertAction(title: "OK", style: .default) {_ in
                        Utils.log("[\(title ?? "")] ok pressed")
                    }
                    alertController.addAction(okAction)
                }
            }
            else {
                for action in actions {
                    alertController.addAction(action)
                }
                configure?(alertController)
            }
            vc.present(alertController, animated: true) {
                if hold > 0 { // time to dismiss pop up
                    DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                        Utils.log("[\(title ?? "")] dismissed after \(-currentTime.timeIntervalSinceNow) sec")
                        alertController.dismiss(animated: true)
                    }
                }
                completion?(alertController)
            }
        }
    }
    
    /// format byte to human readable form
    static func sizeFormat(bytes: UInt64) -> String {
        if bytes == 0 {
            return "0 byte"
        }
        // Adapted from http://stackoverflow.com/a/18650828
        let suffixes = ["bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
        let k: Double = 1000
        let i = floor(log10(Double(bytes))/log10(k))

        // Format below 1 GB with no decimal places else 1 decimal.
        let formatStr = i < 3 ?  "%.0f %@" : "%.1f %@"
        return String(format: formatStr, Double(bytes)/pow(k,i), suffixes[Int(i)])
    }
    
    /// sum array
    static func sum<T:FloatingPoint>(_ array:[T])->T
    {
        array.reduce(0){$0 + $1}
    }
    
    /// average array
    static func average<T:FloatingPoint>(_ array:[T])->T
    {
        sum(array) / T(array.count)
    }
    
    enum MatchType {
        case inAll, notInAny, subset
    }
    
    /// Check if string has all matching or does not have any matching
    /// - parameter string: input string
    /// - parameter patterns: array of character set for testing
    /// - parameter matchAll: true = string has character matching all character sets in patterns, false = string has character not matching any of the character sets in patterns
    static func validateString(string:String, patterns:[CharacterSet], match:MatchType) -> Bool
    {
        let inStr = CharacterSet(charactersIn: string)
        return switch match {
            case .inAll: patterns.reduce(true, {res, pattern in res && !inStr.isDisjoint(with: pattern)})
            case .notInAny: patterns.reduce(true, {res, pattern in res && inStr.isDisjoint(with: pattern)})
            case .subset: patterns.reduce(true, {res, pattern in res && inStr.isSubset(of: pattern)})
        }
    }
}

extension UIImageView {

    func setRounded() {
        self.layer.cornerRadius = (self.frame.width / 2) //instead of let radius = CGRectGetWidth(self.frame) / 2
        self.layer.masksToBounds = true
    }
}

// Global configuration for app colours
extension UIColor {
    static let primaryColor = #colorLiteral(red: 0, green: 0.6784313725, blue: 0.7098039216, alpha: 1) // #00ADB5
    static let backgroundColor = #colorLiteral(red: 0.9333333333, green: 0.9333333333, blue: 0.9333333333, alpha: 1) // #EEEEEE
    static let textFieldTextColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1) // #000000
    static let textFieldBorderColor = #colorLiteral(red: 0.2235294133, green: 0.2431372553, blue: 0.2745098174, alpha: 1.0) // #393E46
    static let textFieldBackgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1) // #FFFFFF
        
    static let csvRow1 = #colorLiteral(red: 0.8392156863, green: 0.9176470588, blue: 0.9725490196, alpha: 1) // #D6EAF8
    static let csvRow2 = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1) // #FFFFFF
}


extension UIImage
{
    func resizedImage(Size sizeImage: CGSize) -> UIImage?
    {
        let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: sizeImage.width, height: sizeImage.height))
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0)
        self.draw(in: frame)
        let resizedImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.withRenderingMode(.alwaysOriginal)
        return resizedImage
    }
}
