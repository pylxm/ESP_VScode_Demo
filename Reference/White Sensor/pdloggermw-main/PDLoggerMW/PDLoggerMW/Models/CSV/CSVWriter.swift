//
//  CSVWriter.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import Foundation

struct CSVWriter
{
    static func save(header:String = "", body:[String], filename:String)
    {
        let fileManager = Settings.shared.fileManager
        if !body.isEmpty {
            let pathName = fileManager.newURL(withName: filename).path
            if fileManager.createFile(atPath: pathName, contents: nil, attributes: nil) {
                if let fileHandler = FileHandle(forWritingAtPath: pathName) {
                    Utils.log("Saving to file \(pathName)")
                    
                    if !header.isEmpty {
                        let headerString = header + "\n"
                        fileHandler.write(Data(headerString.utf8))
                    }
                    let bodyString = body.joined(separator: "\n") + "\n"
                    fileHandler.write(Data(bodyString.utf8))
                }
            }
        }
    }
    
    static func loadToHTML(csv:URL)->String
    {
        var csvContent: String = ""
        var htmlContent: String = ""
        let htmlBegin = """
            <!DOCTYPE html>
            <html>
              <head>
                <meta charset="UTF-8"/>
                <title>\(csv.lastPathComponent)</title>
              </head>
              <body>
                <table>
                  <tbody>
        """
        
        let htmlEnd = """
                  </tbody>
                </table>
              </body>
            </html>
        """
        
        do {
            csvContent = try String(contentsOf: csv, encoding:  .utf8)
            let csvLines = csvContent.split(separator: "\n")
            if csvLines.count > 0 {
                var htmlBody:[String] = []
                csvLines.forEach { line in
                    let csvFields = line.split(separator: ",")
                    htmlBody.append("<tr>")
                    csvFields.forEach { field in
                        htmlBody.append("<td>\(field)</td>")
                    }
                    htmlBody.append("</tr>")
                }
                htmlContent = ([htmlBegin] + htmlBody + [htmlEnd]).joined(separator: "\n")
            }
            else {
                htmlContent = [ htmlBegin, "Empty file", htmlEnd ].joined(separator: "\n")
            }
        }
        catch {
            Utils.log("Error reading \(csv.path)")
            htmlContent = [ htmlBegin, "Error reading \(csv.path)", htmlEnd ].joined(separator: "\n")
        }
        return htmlContent
    }
}
