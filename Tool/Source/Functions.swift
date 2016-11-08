//
//  Functions.swift
//  POET
//
//  Created by Oliver Drobnik on 08.11.16.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

func xCodeLocaleFromPOEditorCode(code: String) -> String
{
	var tmpCode = code
	
	if tmpCode == "zh-CN"
	{
		tmpCode = "zh-Hans"
	}
	else if tmpCode == "zh-TW"
	{
		tmpCode = "zh-Hant"
	}
	else if tmpCode == "en-us"
	{
		tmpCode = "en"
	}
	
	let locale = Locale(identifier: tmpCode)
	return locale.identifier
}
