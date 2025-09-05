//
//  CsvViewer.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 20/11/24.
//

import WebKit

class CsvViewer: WKWebView
{
    private let js = """
        var metaTag=document.createElement('meta');
        metaTag.name = "viewport";
        metaTag.content = "width=device-width, initial-scale=1.0, maximum-scale=10.0, user-scalable=yes";
        document.getElementsByTagName('head')[0].appendChild(metaTag);
        """
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
    }
    
    func readAndShowCsv(filePath: URL) {
        guard let csvContent = try? String(contentsOf: filePath) else { return }
        let htmlContent = convertCsvToHTML(csvContent: csvContent)
        loadHTMLString(htmlContent, baseURL: nil)
    }
    
    private func convertCsvToHTML(csvContent: String) -> String {
        let rows = csvContent.split(separator: "\n")
        let htmlRows = rows.enumerated().map { index, row -> String in
            let columns = row.split(separator: ",")
            let cells = columns.map { "<td>\($0.trimmingCharacters(in: .whitespacesAndNewlines))</td>" }.joined()
            let rowClass = index == 0 ? "header-row" : (index % 2 == 0 ? "even-row" : "odd-row")
            return "<tr class=\"\(rowClass)\">\(cells)</tr>"
        }.joined()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    margin: 0;
                    padding: 0;
                    background-color: #f8f9fa;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                    font-size: 16px;
                    text-align: left;
                    box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
                }
                th, td {
                    border: 1px solid #ddd;
                    padding: 8px;
                }
                th {
                    background-color: #007bff;
                    color: white;
                    text-align: center;
                }
                .header-row {
                    font-weight: bold;
                }
                .even-row {
                    background-color: #f2f2f2;
                }
                .odd-row {
                    background-color: #ffffff;
                }
                tr:hover {
                    background-color: #ddd;
                }
            </style>
        </head>
        <body>
            <table>
                \(htmlRows)
            </table>
        </body>
        </html>
        """
    }
}
