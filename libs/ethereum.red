Red [
	Title:	"Ethereum utility functions"
	Author: "Xie Qingtian"
	File: 	%ethereum.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

eth: context [

	eth-to-wei: func [eth][
		if string? eth [eth: to float! eth]
		to-i256 eth * 1e18
	]

	gwei-to-wei: func [gwei][
		if string? gwei [gwei: to float! gwei]
		to-i256 gwei * 1e9
	]

	pad64: function [data [string! binary!]][
		n: length? data
		either binary? data [c: #{00} len: 32][c: #"0" len: 64]
		if n < len [
			insert/dup data c len - n
		]
		data
	]

	headers: compose [
		Content-Type: "application/json"
		Accept: "application/json"
		Cookie: (make string! 16)
		User-Agent: (
			form reduce [
				"Red Wallet version"
				"0.2.0"
				"for" system/platform
			]
		)
	]

	body: #(
		jsonrpc: "2.0"
		id: 1
		method: none
		params: none
	)

	cookie: func [str [string!]][
		lowercase take/part enbase/base checksum str 'sha256 16 16
	]

	call-rpc: func [network [url!] method [word!] params [none! block!] /local data][
		body/method: method
		body/params: params
		data: json/encode body
		headers/cookie: cookie data
		select json/decode write network compose/only [
			POST
			(headers)
			(to-binary data)
		] 'result
	]

	parse-balance: function [amount][
		either (length? amount) % 2 <> 0 [
			poke amount 2 #"0"
			n: 1
		][n: 2]
		n: to-i256 debase/base skip amount n 16
		n: i256-to-float n
		n / 1e18
	]

	get-balance-token: func [network [url!] contract [string!] address [string!] /local token-url params][
		token-url: rejoin ["0x" contract]
		params: make map! 4
		params/to: token-url
		params/data: rejoin ["0x70a08231" pad64 copy skip address 2]
		parse-balance call-rpc network 'eth_call reduce [params 'latest]
	]

	get-balance: func [network [url!] address [string!]][
		parse-balance call-rpc network 'eth_getBalance reduce [address 'latest]
	]

	get-nonce: func [network [url!] address [string!] /local n result][
		result: call-rpc network 'eth_getTransactionCount reduce [address 'pending]
		either (length? result) % 2 <> 0 [
			poke result 2 #"0"
			n: 1
		][n: 2]
		to integer! debase/base skip result n 16
	]
]