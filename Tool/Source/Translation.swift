//
//  Translation.swift
//  POET
//
//  Created by Oliver Drobnik on 08.11.16.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

/// A translated term, either with a single definition or multiple plural forms
enum TranslatedTerm
{
	/// if there is a single definition for the term
	case hasDefinition(String?)
	
	/// if there are multiple plural forms
	case hasPlurals([String: String])
}

/// A translation from a term into another langauge.
struct Translation
{
	/// A comment to help the translator
	var comment: String?
	
	/// The original term/token
	var term: String
	
	/// The translation
	var translated: TranslatedTerm
}

/// An Array of Translations can be written to a file
extension Collection where Iterator.Element == Translation
{
	/// Writing files representing the strings and stringsdict entries
	func writeFile(name: String, to url: URL) throws
	{
		// only output strings files
		let fileName = (name as NSString).lastPathComponent
		
		guard (fileName as NSString).pathExtension == "strings" else
		{
			return
		}

		// create output folder if needed
		let fileManager = FileManager.default
		
		if !fileManager.fileExists(atPath: url.path)
		{
			try fileManager.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
		}
		
		let justName = (fileName as NSString).deletingPathExtension
		
		var tmpStr = ""
		
		for transUnit in self
		{
			var translatedTerm: String!
			
			switch transUnit.translated
			{
				case .hasDefinition(let translation):
					translatedTerm = translation
				
				case .hasPlurals(let plurals):
					translatedTerm = plurals["other"]
			}
			
			if translatedTerm == nil
			{
				continue
			}
			
			if !tmpStr.isEmpty
			{
				tmpStr += "\n"
			}

			if let note = transUnit.comment, !note.isEmpty
			{
				let noteWithLinebreaks = note.replacingOccurrences(of: "\\n", with: "\n", options: [], range: nil)
				tmpStr += "/* \(noteWithLinebreaks) */\n"
			}

			// escape double quotes to be safe
			let cleanTranslation = translatedTerm.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\"", with: "\\\"")
			
			tmpStr += "\"\(transUnit.term)\" = \"\(cleanTranslation)\";\n"
		}
		
		let outputName = justName + ".strings"
		let outputPath = (url.path as NSString).appendingPathComponent(outputName)
		
		if !tmpStr.isEmpty
		{
			try (tmpStr as NSString).write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8.rawValue);
			
			print("\t✓ " + outputName)
		}
		
		let stringsDictItems = self.filter { (translation) -> Bool in
			
			if case .hasPlurals(_) = translation.translated
			{
				return true
			}
			
			return false
		}
		
		if stringsDictItems.count > 0
		{
			var outputDict = [String: Any]()
			
			for translation in stringsDictItems
			{
				var itemDict = [String: Any]()
				
				itemDict["NSStringLocalizedFormatKey"] = "%#@items@"
				
				var pluralsDict = [String: Any]()
				
				switch translation.translated
				{
				case .hasDefinition(_):
					preconditionFailure()
					
				case .hasPlurals(let plurals):
					for key in plurals.keys.sorted()
					{
						if let form = plurals[key], !form.isEmpty
						{
							pluralsDict[key] = form
						}
					}
				}
				
				if pluralsDict.count > 0
				{
					pluralsDict["NSStringFormatSpecTypeKey"] = "NSStringPluralRuleType"
					pluralsDict["NSStringFormatValueTypeKey"] = "d"
					
					itemDict["items"] = pluralsDict
					
					outputDict[translation.term] = itemDict
				}
			}
			
			guard outputDict.count > 0 else
			{
				return
			}
			
			let outputName = justName + ".stringsdict"
			let outputPath = (url.path as NSString).appendingPathComponent(outputName)
			
			(outputDict as NSDictionary).write(toFile: outputPath, atomically: true)
			
			print("\t✓ " + outputName)
		}
	}
}
