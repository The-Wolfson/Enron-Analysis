//
//  main.swift
//  Enron Analysis
//
//  Created by Joshua Wolfson on 8/9/2024.
//

import Foundation
import OSLog

let parentPathtoEnronData = "/Users/joshuawolfson/Downloads"
let outputPath = "/Users/joshuawolfson/Documents/Coding/Enron Analysis/Enron Analysis/graph.gv"

var users: [User] = [] //defines user array, for keeping track of nodes
var graph: [Connection] = []// defines graph array, for keeping track of edges

let logger = Logger(subsystem: "EnronAnalysis", category: "main") //defines logger for logging messages to console

struct User { //declares user/node struct
    var email: String
}

struct Connection { //declares connection/edge struct
    var from: User
    var to: User
    var label: String
}

func addConnection(fromEmail: String, toEmail: String, messageId: String) {// adds a connection/edge
    let from = addUserIfNotExists(email: fromEmail)
    let to = addUserIfNotExists(email: toEmail)
    guard from.email != to.email else { return }
    let connection = Connection(from: from, to: to, label: messageId)
    
    graph.append(connection)//adds connection/edge to 'graph' array
}

func addUserIfNotExists(email: String) -> User {
    if let existingUser = users.first(where: { $0.email == email }) {
        return existingUser
    } else {
        let newUser = User(email: email)
        users.append(newUser)
        return newUser
    }
}

func parseData(filePath: String) {
    do {
        let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)//gets the contents of the file
        let lines = fileContents.components(separatedBy: .newlines)//seperates the contents into components seperated by newline
        //TODO: Figure out why there are double the amount o flines as should be
        
        guard let messageIdLine = lines.first else {//skips the file if there is no 'Message ID', should not happen, all Enron dataset files have a unique Message ID
            logger.warning("Skipping file \(filePath), no 'Message-ID:' line")
            return
        }
        
        guard let fromLine = lines.first(where: { $0.hasPrefix("From:") }) else {//Skips the file if there is no sender
            logger.warning("Skipping file \(filePath), no 'From:' line")
            return
        }
        
        guard let toLineIndex = lines.firstIndex(where: { $0.hasPrefix("To:") }), toLineIndex < 10 else {//skips the file if it is not addressed to anyone, or if the two line is not within the first 10
            logger.warning("Skipping file \(filePath), no 'To:' line")
            return
        }
        
        let messageId = messageIdLine.dropFirst(12).trimmingCharacters(in: .whitespacesAndNewlines)
        let from = fromLine.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines)
        var to: [String] = lines[toLineIndex].dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ", ")
        
        var i = toLineIndex + 2
        while i < lines.count && lines[i].first?.isWhitespace == true {
            let additionalRecipients = lines[i].trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ", ")
            to.append(contentsOf: additionalRecipients)
            i += 2
        }
        
        if let ccLineIndex = lines.firstIndex(where: { $0.hasPrefix("To:") }), ccLineIndex < 16 {
            var n = ccLineIndex + 2
            while n < lines.count && lines[n].first?.isWhitespace == true {
                let additionalRecipients = lines[n].trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ", ")
                to.append(contentsOf: additionalRecipients)
                n += 2
            }
        }
        
        for recipient in to {
            guard !recipient.isEmpty else { continue }
            addConnection(fromEmail: from.trimmingCharacters(in: .punctuationCharacters).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\'", with: ""), toEmail: recipient.trimmingCharacters(in: .punctuationCharacters).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\'", with: ""), messageId: messageId)
        }
        //logger.info("Processed file \(filePath) with \(to.count) connections.")
    } catch {
        logger.error("Error reading file \(filePath): \(error)")
    }
}

//MARK: ChatGPT generated function
func iterateDocumentFilesRecursively(in directory: String) {
    let fileManager = FileManager.default
    
    if let enumerator = fileManager.enumerator(atPath: directory) {
        for case let filePath as String in enumerator {
            let fullPath = (directory as NSString).appendingPathComponent(filePath)
            
            //Get URL for the file
            let fileURL = URL(fileURLWithPath: fullPath)
            do {
                //Check if it's a regular file (not a directory)
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    //Process the file (since it's a "Document" without an extension)
                    parseData(filePath: fullPath)
                }
            } catch {
                logger.error("Error accessing resource values for \(fullPath): \(error)")
            }
        }
    } else {
        logger.error("Error accessing directory \(directory)")
    }
}

func printGraph(graph: [Connection]) {
    for user in users {
        print(user.email)
    }
    print("--------------------------------------")
    for connection in graph {
        print("\(connection.from.email) -> \(connection.to.email)")
    }
}

func generateDotFormat(for graph: [Connection]) -> String {//for generating .DOT file format, it is also possible to print this to console with print(generateDotFormat). Takes the array containing all the conections as input
    var dotString = "digraph G {\n"
    for connection in graph {
        dotString += "    \"\(connection.from.email)\" -> \"\(connection.to.email)\" [ label = \"\(connection.label)\" ];\n"
    }
    dotString += "}\n"
    return dotString
}

func saveDotFile(filePath: String) {//writes the .DOT file to disk
    do {
        let data = generateDotFormat(for: graph).data(using: .utf8)
        
        try data?.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        logger.info("File saved successfully at \(filePath)")
    } catch {
        logger.error("Error saving file: \(error)")
    }
}

iterateDocumentFilesRecursively(in: "\(parentPathtoEnronData)/2018487913/maildir")
print(users.count, graph.count)
saveDotFile(filePath: outputPath)
