Red []

qrcode: context [
	buffer-len?: function [ver [integer!]][
		temp: ver * 4 + 17
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
	VERSION_MIN: 1
	VERSION_MAX: 40
	REED_SOLOMON_DEGREE_MAX: 30
	max-buffer: function [][
		len: buffer-len? VERSION_MAX
		res: make binary! len
		append/dup res 0 len
	]
	temp-buffer: max-buffer
	qrcode-buffer: copy temp-buffer

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
		if num-chars > 32767 [return none]
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
				return none
			]
		]
		if res > 32767 [return none]
		res
	]

	encode-number: function [str [string!]][
		str-len: length? str
		item: str
		bits: make string! 64
		while [0 < len: length? item][
			either len >= 3 [
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
			either len >= 2 [
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
		str				[string! binary!]
		ecl				[word!]
		min-version		[integer!]
		max-version		[integer!]
		mask			[integer!]
		boost-ecl?		[logic!]
	][
		either string? str [
			bin: to binary! str
		][
			bin: copy str
		]
		bin-len: length? bin
		;-- TODO: len 0

		;-- buffer len
		buf-len: buffer-len? max-version
		case [
			number-mode? str [
				unless blen: get-segment-bits 'number bin-len [return none]
				if ((blen + 7) / 8) > buf-len [return none]
				seg: encode-number str
			]
			alphanumber-mode? str [
				unless blen: get-segment-bits 'alphanumber bin-len [return none]
				if ((blen + 7) / 8) > buf-len [return none]
				seg: encode-alphanumber str
			]
			true [
				if bin-len > buf-len [return none]
				unless blen: get-segment-bits 'byte bin-len [return none]
				seg: reduce [
					'mode 'byte
					'num-chars get-segment-bits 'byte bin-len
					'data enbase/base bin 2
				]
			]
		]
		encode-segments reduce [seg] ecl min-version max-version mask boost-ecl?
	]

	encode-segments: function [
		segs			[block!]
		ecl				[word!]
		min-version		[integer!]
		max-version		[integer!]
		mask			[integer!]
		boost-ecl?		[logic!]
	][
		unless all [
			VERSION_MIN <= min-version
			min-version <= max-version
			max-version <= VERSION_MAX
		][return none]
		unless find error-group ecl [return none]
		unless all [
			mask >= -1
			mask <= 7
		][return none]

		version: min-version
		forever [
			cap-bits: 8 * get-data-code-words-bytes version ecl
			unless used-bits: total-bits segs version [
				return none
			]
			if all [
				used-bits
				used-bits <= cap-bits
			][break]
			if version >= max-version [return none]
			version: version + 1
		]

		if boost-ecl? [
			ecls: [M Q H]
			forall ecls [
				if used-bits <= 8 * get-data-code-words-bytes version ecls/1 [
					ecl: ecls/1
				]
			]
		]
		unless qrcode: encode-padding segs used-bits version ecl [
			return none
		]
		;probe qrcode
		if test-mode = 'encode [return qrcode]
		qrcode: debase/base qrcode 2
		probe qrcode
		len: length? qrcode
		i: 1
		while [i <= len][
			poke qrcode-buffer i qrcode/(i)
			i: i + 1
		]
		qrcode: qrcode-buffer
		encode-ecc qrcode version ecl
		probe temp-buffer
	]

	encode-padding: function [
		segs			[block!]
		used-bits		[integer!]
		version			[integer!]
		ecl				[word!]
	][
		res: make string! 200
		forall segs [
			mode: segs/1/mode
			data: segs/1/data
			num-chars: segs/1/num-chars
			num-bits: num-char-bits mode version
			part-bin: to binary! num-chars
			part-str: enbase/base part-bin 2
			if num-bits > part-len: length? part-str [return none]
			begin: skip part-str part-len - num-bits
			append res rejoin [
				select mode-indicators mode
				copy/part begin num-bits
				segs/1/data
			]
		]
		if used-bits <> (bit-len: length? res) [return none]
		cap-bytes: get-data-code-words-bytes version ecl
		cap-bits: 8 * cap-bytes
		if bit-len > cap-bits [return none]
		if 4 < terminator-bits: cap-bits - bit-len [
			terminator-bits: 4
		]
		append/dup res "0" terminator-bits
		res-len: length? res
		m: res-len % 8
		if m <> 0 [
			append/dup res "0" 8 - m
		]
		bit-len: length? res
		if 0 <> (bit-len % 8) [return none]
		res-len: (length? res) / 8
		if res-len > cap-bytes [return none]
		if res-len = cap-bytes [return res]
		pad-index: 1
		loop cap-bytes - res-len [
			append res padding-bin/(pad-index)
			either pad-index = 1 [
				pad-index: 2
			][
				pad-index: 1
			]
		]
		res
	]

	encode-ecc: function [
		data			[binary!]
		version			[integer!]
		ecl				[word!]
	][
		num-blocks: pick NUM_ERROR_CORRECTION_BLOCKS/(ecl) version
		block-ecc-len: pick ECC_CODEWORDS_PER_BLOCK/(ecl) version
		raw-code-words: (get-data-modules-bits version) / 8
		data-len: get-data-code-words-bytes version ecl
		num-short-blocks: num-blocks - (raw-code-words % num-blocks)
		short-block-data-len: raw-code-words / num-blocks - block-ecc-len

		generator: calc-reed-solomon-generator block-ecc-len
		dat: data
		i: 1
		while [i <= num-blocks][
			dlen: short-block-data-len + either (i - 1) < num-short-blocks [0][1]
			ecc: skip data data-len
			calc-reed-solomon-remainder dat dlen generator ecc
			j: 1 k: i
			while [j <= dlen][
				if j = (short-block-data-len + 1) [
					k: k - num-short-blocks
				]
				poke temp-buffer k dat/(j)
				j: j + 1
				k: k + num-blocks
			]
			j: 1 k: data-len + 1
			while [j <= block-ecc-len][
				poke temp-buffer k ecc/(j)
				j: j + 1
				k: k + num-blocks
			]
			dat: skip dat data-len
			i: i + 1
		]
	]

	calc-reed-solomon-generator: function [degree [integer!]][
		unless all [
			degree >= 1
			degree <= REED_SOLOMON_DEGREE_MAX
		][return none]
		res: make binary! degree
		append/dup res 0 degree
		res/(degree): 1

		root: 1
		i: 1 j: 1
		while [i <= degree][
			while [j <= degree][
				res/(j): finite-field-multiply res/(j) root
				if j < degree [
					res/(j): res/(j) xor res/(j + 1)
				]
				j: j + 1
			]
			root: finite-field-multiply root 2
			i: i + 1
		]
		res
	]

	calc-reed-solomon-remainder: function [data [binary!] data-len [integer!] generator [binary!] res [binary!]][
		degree: length? generator
		unless all [
			degree >= 1
			degree <= REED_SOLOMON_DEGREE_MAX
		][return none]
		i: 1
		while [i <= degree][
			res/(i): 0
			i: i + 1
		]
		probe data-len
		i: 1 j: 1
		while [i <= data-len][
			factor: data/(i) xor res/1
			res: skip res 1
			res/(degree): 0
			while [j <= degree][
				res/(j): res/(j) xor finite-field-multiply generator/(j) factor
				j: j + 1
			]
			i: i + 1
		]
	]

	finite-field-multiply: function [x [integer!] y [integer!]][
		z: 0
		i: 7
		while [i >= 0][
			z: (z << 1 and FFh) xor ((z >> 7) * 11Dh and FFh)
			z: z xor ((y >> i and 1) * x)
			i: i - 1
		]
		z and FFh
	]

	total-bits: function [
		segs			[block!]
		version			[integer!]
	][
		len: length? segs
		res: 0
		forall segs [
			num-chars: segs/1/num-chars
			bit-len: length? segs/1/data
			unless cc-bits: num-char-bits segs/1/mode version [
				return none
			]
			if num-chars >= (1 << cc-bits) [
				return none
			]
			res: res + 4 + cc-bits + bit-len
			if res > 32767 [return none]
		]
		res
	]
	num-char-bits: function [
		mode			[word!]
		ver				[integer!]
	][
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
]

;test-mode: pick [none encode ecc] 2
;r: qrcode/encode-data "01234567" 'H 1 40 1 no
;print r = "000100000010000000001100010101100110000110000000111011000001000111101100"
;r: qrcode/encode-data "AC-42" 'H 1 40 1 no
;print r = "001000000010100111001110111001110010000100000000111011000001000111101100"
;r: qrcode/encode-data "HELLO WORLD" 'Q 1 40 1 no
;print r = "00100000010110110000101101111000110100010111001011011100010011010100001101000000111011000001000111101100"
;test-mode: pick [none encode ecc] 3
;r: qrcode/encode-data "HELLO WORLD" 'Q 1 40 1 no
