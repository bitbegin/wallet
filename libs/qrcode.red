Red []

qrcode: context [
	mode-indicators: [
		terminator		#{0000}
		fnc1-first		#{0101}
		fnc1-second		#{1001}
		struct			#{0011}
		kanji			#{1000}
		byte			#{0100}
		alphanumber		#{0010}
		number			#{0001}
		eci				#{0111}
		chinese			#{1101}
	]
	version-base: 21x21
	version-step: 4x4
	version-end: 40

	get-version-size: function [version [integer!]][
		if version > version-end [return none]
		(version - 1) * version-step + version-base
	]

	error-group: [
		L	7%
		M	15%
		Q	25%
		H	30%
	]

	alphanumber: [
		#"0" 0
		#"1" 1
		#"2" 2
		#"3" 3
		#"4" 4
		#"5" 5
		#"6" 6
		#"7" 7
		#"8" 8
		#"9" 9
		#"A" 10
		#"B" 11
		#"C" 12
		#"D" 13
		#"E" 14
		#"F" 15
		#"G" 16
		#"H" 17
		#"I" 18
		#"J" 19
		#"K" 20
		#"L" 21
		#"M" 22
		#"N" 23
		#"O" 24
		#"P" 25
		#"Q" 26
		#"R" 27
		#"S" 28
		#"T" 29
		#"U" 30
		#"V" 31
		#"W" 32
		#"X" 33
		#"Y" 34
		#"Z" 35
		#" " 36
		#"$" 37
		#"%" 38
		#"*" 39
		#"+" 40
		#"-" 41
		#"." 42
		#"/" 43
		#":" 44
	]

	number-mode?: function [str [string!]][
		forall str [
			int: to integer! str/1
			if any [
				int < 30h
				int > 39h
			][return false]
		]
		true
	]

	alphanumber-mode?: function [str [string!]][
		forall str [
			unless find alphanumber str/1 [return false]
		]
		true
	]

	byte-mode?: function [str [string!]][
		forall str [
			if 255 < to integer! str/1 [return false]
		]
		true
	]

	get-mode: function [str [string!]][
		if number-mode? str [
			return 'number
		]
		if alphanumber-mode? str [
			return 'alphanumber
		]
		if byte-mode? str [
			return 'byte
		]
		;-- not support
		none
	]

	encode-number: function [str [string!] ver [integer!]][
		unless mode: get-mode str [return none]
		len: length? str

	]

	get-encode-bits: function [mode [word!] ver [integer!]][
		if mode = 'number [
			if ver <= 9 [return 10]
			if ver <= 26 [return 12]
			if ver <= 40 [return 14]
			return none
		]
		if mode = 'alphanumber [
			if ver <= 9 [return 9]
			if ver <= 26 [return 11]
			if ver <= 40 [return 13]
			return none
		]
		if mode = 'byte [
			if ver <= 9 [return 8]
			if ver <= 26 [return 16]
			if ver <= 40 [return 16]
			return none
		]
		if mode = 'kanji [
			if ver <= 9 [return 8]
			if ver <= 26 [return 10]
			if ver <= 40 [return 12]
			return none
		]
		none
	]

	encode-number: function [str [string!] ver [integer!]][
		str-len: length? str
		item-bits: get-encode-bits 'number ver
		item: str
		bits: make string! 64
		while [0 < len: length? item][
			either len > 3 [
				part: copy/part item 3
				part-bin: to binary! to integer! part
				part-str: enbase/base part-bin 2
				if item-bits > part-len: length? part-str [return none]
				begin: skip part-str part-len - item-bits
				append bits copy/part begin item-bits
				item: skip item 3
			][
				either len = 1 [
					part-bin: to binary! to integer! item
					part-str: enbase/base part-bin 2
					if 4 > part-len: length? part-str [return none]
					begin: skip part-str part-len - 4
					append bits copy/part begin 4
					item: skip item 1
				][
					part-bin: to binary! to integer! item
					part-str: enbase/base part-bin 2
					if 7 > part-len: length? part-str [return none]
					begin: skip part-str part-len - 7
					append bits copy/part begin 7
					item: skip item 2
				]
			]
		]
		part-bin: to binary! str-len
		part-str: enbase/base part-bin 2
		if item-bits > part-len: length? part-str [return none]
		begin: skip part-str part-len - item-bits
		res: rejoin ["0001" copy/part begin item-bits bits "0000"]
		res-len: length? res
		m: res-len % 8
		if m <> 0 [
			append/dup res "0" 8 - m
		]
		res
	]

	encode-alphanumber: function [str [string!] ver [integer!]][
		str-len: length? str
		item-bits: get-encode-bits 'alphanumber ver
		table: make block! str-len
		forall str [
			append table select alphanumber str/1
		]
		item: table
		bits: make string! 64
		while [0 < len: length? item][
			either len > 2 [
				part-bin: to binary! (item/1 * 45 + item/2)
				part-str: enbase/base part-bin 2
				if 11 > part-len: length? part-str [return none]
				begin: skip part-str part-len - 11
				append bits copy/part begin 11
				item: skip item 2
			][
				part-bin: to binary! item/1
				part-str: enbase/base part-bin 2
				if 6 > part-len: length? part-str [return none]
				begin: skip part-str part-len - 6
				append bits copy/part begin 6
				item: skip item 1
			]
		]
		part-bin: to binary! str-len
		part-str: enbase/base part-bin 2
		if item-bits > part-len: length? part-str [return none]
		begin: skip part-str part-len - item-bits
		res: rejoin ["0010" copy/part begin item-bits bits "0000"]
		res-len: length? res
		m: res-len % 8
		if m <> 0 [
			append/dup res "0" 8 - m
		]
		res
	]
]

print "000100000010000000001100010101100110000110000000" = qrcode/encode-number "01234567" 1
print "001000000010100111001110111001110010000100000000" = qrcode/encode-alphanumber "AC-42" 1
print "00100000010110110000101101111000110100010111001011011100010011010100001101000000" = qrcode/encode-alphanumber "HELLO WORLD" 1
