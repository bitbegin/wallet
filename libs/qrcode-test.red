Red []
#include %qrcode.red
system/catalog/errors/user: make system/catalog/errors/user [qrcode-test: ["qrcode-test [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

new-error: func [name [word!] arg2 arg3][
	cause-error 'user 'qrcode-test [name arg2 arg3]
]

testFiniteFieldMultiply: function [][
	cases: [
		00h 00h 00h
		01h 01h 01h
		02h 02h 04h
		00h 6Eh 00h
		B2h DDh E6h
		41h 11h 25h
		B0h 1Fh 11h
		05h 75h BCh
		52h B5h AEh
		A8h 20h A4h
		0Eh 44h 9Fh
		D4h 13h A0h
		31h 10h 37h
		6Ch 58h CBh
		B6h 75h 3Eh
		FFh FFh E2h
	]
	while [not tail? cases][
		if cases/3 <> qrcode/finite-field-multiply cases/1 cases/2 [
			new-error 'testFiniteFieldMultiply cases/3 reduce [cases/1 cases/2]
		]
		cases: skip cases 3
	]
]

either error? try [testFiniteFieldMultiply][
	print "testFiniteFieldMultiply failed!"
][
	print "testFiniteFieldMultiply ok"
]

testEncodeData: function [][
	set 'test-mode pick [none encode ecc] 2
	r: qrcode/encode-data data: "01234567" 'H 1 40 1 no
	unless r = c: "000100000010000000001100010101100110000110000000111011000001000111101100" [
		new-error 'testEncodeData data reduce [r c]
	]
	r: qrcode/encode-data data: "AC-42" 'H 1 40 1 no
	unless r = c: "001000000010100111001110111001110010000100000000111011000001000111101100" [
		new-error 'testEncodeData data reduce [r c]
	]
	r: qrcode/encode-data data: "HELLO WORLD" 'Q 1 40 1 no
	unless r = c: "00100000010110110000101101111000110100010111001011011100010011010100001101000000111011000001000111101100" [
		new-error 'testEncodeData data reduce [r c]
	]
]

either error? try [testEncodeData][
	print "testEncodeData failed!"
][
	print "testEncodeData ok"
]
