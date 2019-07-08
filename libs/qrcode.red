Red []

qrcode: context [
	buffer-len?: function [ver [integer!]][
		temp: n * 4 + 17
		temp: temp * temp / 8 + 1
		temp
	]
	mode-indicators: [
		terminator		{0000}
		fnc1-first		{0101}
		fnc1-second		{1001}
		struct			{0011}
		kanji			{1000}
		byte			{0100}
		alphanumber		{0010}
		number			{0001}
		eci				{0111}
		chinese			{1101}
	]
	padding-bin: [
		{11101100}
		{00010001}
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

	ECC_CODEWORDS_PER_BLOCK: [
		L	[ 7 10 15 20 26 18 20 24 30 18 20 24 26 30 22 24 28 30 28 28 28 28 30 30 26 28 30 30 30 30 30 30 30 30 30 30 30 30 30 30]
		M	[10 16 26 18 24 16 18 22 22 26 30 22 22 24 24 28 28 26 26 26 26 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28]
		Q	[13 22 18 26 18 24 18 22 20 24 28 26 24 20 30 24 28 28 26 30 28 30 30 30 30 28 30 30 30 30 30 30 30 30 30 30 30 30 30 30]
		H	[17 28 22 16 22 28 26 26 24 28 24 28 22 24 24 30 28 28 26 28 30 24 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30]
	]

	NUM_ERROR_CORRECTION_BLOCKS: [
		L	[ 1  1  1  1  1  2  2  2  2  4  4  4  4  4  6  6  6  6  7  8  8  9  9 10 12 12 12 13 14 15 16 17 18 19 19 20 21 22 24 25]
		M	[ 1  1  1  2  2  4  4  4  5  5  5  8  9  9 10 10 11 13 14 16 17 17 18 20 21 23 25 26 28 29 31 33 35 37 38 40 43 45 47 49]
		Q	[ 1  1  2  2  4  4  6  6  8  8  8 10 12 16 12 17 16 18 21 20 23 23 25 27 29 34 34 35 38 40 43 45 48 51 53 56 59 62 65 68]
		H	[ 1  1  2  4  4  4  5  6  8  8 11 11 16 16 18 16 19 21 25 25 25 34 30 32 35 37 40 42 45 48 51 54 57 60 63 66 70 74 77 81]
	]

	alphanumber: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

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

	get-data-modules-bits: function [ver [integer!]][
		res: (16 * ver + 128) * ver + 64
		if ver >= 2 [
			align: ver / 7 + 2
			res: res - ((25 * align - 10) * align - 55)
			if ver >= 7 [
				res: res - 36
			]
		]
		res
	]

	get-data-code-words-bytes: function [ver [integer!] ecc-level [word!]][
		ecc-code-words: pick ECC_CODEWORDS_PER_BLOCK/(ecc-level) ver
		num-ecc: pick NUM_ERROR_CORRECTION_BLOCKS/(ecc-level) ver
		res: get-data-modules-bits ver
		res: res / 8 - (ecc-code-words * num-ecc)
		res
	]

	get-segment-bits: function [mode [word!] num-chars [integer!]][
		if num-chars > 32767 [return -1]
		res: num-chars
		case [
			mode = 'number [
				res: res * 10 + 2 / 3
			]
			mode = 'alphanumber [
				res: res * 11 + 1 / 2
			]
			mode = 'byte [
				res: res * 8
			]
			mode = 'kanji [
				res: res * 13
			]
			all [
				mode = 'eci
				num-chars = 0
			][
				res: 3 * 8
			]
			true [
				return -1
			]
		]
		if res > 32767 [return -1]
		res
	]

	encode-number: function [str [string!]][
		str-len: length? str
		item: str
		bits: make string! 64
		while [0 < len: length? item][
			either len > 3 [
				part: copy/part item 3
				part-bin: to binary! to integer! part
				part-str: enbase/base part-bin 2
				if 10 > part-len: length? part-str [return none]
				begin: skip part-str part-len - 10
				append bits copy/part begin 10
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
		reduce [
			'mode 'number
			'num-chars str-len
			'data bits
		]
	]

	encode-alphanumber: function [str [string!]][
		str-len: length? str
		table: make block! str-len
		forall str [
			index: index? find alphanumber str/1
			append table index - 1
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
		reduce [
			'mode 'alphanumber
			'num-chars str-len
			'data bits
		]
	]

	encode-data: function [
		str [string!]
		ecl [word!]
		min-version [integer!]
		max-version [integer!]
		mask [word!]
		boost-ecl? [logic!]
	][
		bin: to binary! str
		bin-len: length? bin
		;-- TODO: len 0

		;-- buffer len
		buf-len: buffer-len? max-version
		case [
			number-mode? str [
				if -1 = bytes: get-segment-bits 'number bin-len [return none]
				if ((bytes + 7) / 8) > buf-len [return none]
				seg: encode-number str
			]
			alphanumber-mode? str [
				if -1 = bytes: get-segment-bits 'alphanumber bin-len [return none]
				if ((bytes + 7) / 8) > buf-len [return none]
				seg: encode-alphanumber str
			]
			true [
				if bin-len > buf-len [return none]
				seg: reduce [
					'mode 'byte
					'num-chars get-segment-bits 'byte bin-len
					'data copy bin
				]
			]
		]
	]
]

r: qrcode/encode-number "01234567" 1 'H
print r = "000100000010000000001100010101100110000110000000111011000001000111101100"
r: qrcode/encode-alphanumber "AC-42" 1 'H
print r = "001000000010100111001110111001110010000100000000111011000001000111101100"
r: qrcode/encode-alphanumber "HELLO WORLD" 1 'Q
print r = "00100000010110110000101101111000110100010111001011011100010011010100001101000000111011000001000111101100"
