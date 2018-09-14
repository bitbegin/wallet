Red [
	Title:	"Batch payment utils"
	Author: "Xie Qingtian"
	File: 	%eth-batch.red
	Tabs: 	4
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

eth-batch: context [
	payment-stop?: no
	batch-results: make block! 4

	payment-list: none
	batch-result-btn: none
	batch-send-btn: none
	payment-name: none
	payment-addr: none
	payment-amount: none
	add-payment-btn: none

	gas-limit: none
	signed-data: none

	total-balance: none
	from-path: none

	sanitize-payments: func [data [block! none!] /local entry c][
		if block? data [
			foreach entry data [
				if find "√×" last entry [
					clear skip tail entry -3
				]
			]
		]
		data
	]

	check-payment: func [return: [word!]
		/local idx sum entry addr to-addr amount amount-wei price-wei limit
	][
		if error? price-wei: try [string-to-i256 batch-gas-price/text 9] [
			return 'invalid-price
		]

		limit: to-integer gas-limit

		batch-send-btn/text: "Stop"
		idx: 1
		sum: to-i256 0
		foreach entry payment-list/data [
			payment-list/selected: idx
			process-events
			addr: find entry "0x"
			to-addr: copy/part addr 42
			amount: trim copy skip addr 42
			if error? amount-wei: try [string-to-i256 amount 18] [
				return 'invalid-amount
			]
			sum: add256 sum amount-wei
			if 'ok <> res: eth-ui/check-data total-balance to-addr price-wei limit sum [
				return res
			]
		]
		batch-send-btn/text: "Send"
		return 'ok
	]

	do-add-payment: func [face event /local entry res][
		entry: rejoin [
			pad copy payment-name/text 12
			payment-addr/text "        "
			payment-amount/text
		]
		either add-payment-btn/text = "Add" [
			append payment-list/data entry
		][
			poke payment-list/data payment-list/selected entry
		]
		if 'ok <> res: check-payment [
			either add-payment-btn/text = "Add" [
				remove back tail payment-list/data
			][
				remove at payment-list/data payment-list/selected
			]
			eth-ui/show-error-dlg res
		]
		unview
	]

	do-import-payments: function [face event][
		if f: request-file [
			payment-list/data: sanitize-payments load f
		]
	]

	do-export-payments: func [face event][
		if f: request-file/save [
			save f sanitize-payments payment-list/data
		]
	]

	do-check-result: function [face event][
		foreach result batch-results [
			either string? result [
				browse rejoin [explorer result]
			][							;-- error
				eth-ui/show-error-dlg result
			]
		]
	]

	do-batch-payment: func [
		face	[object!]
		event	[event!]
		/local from-addr nonce price-wei limit amount-wei entry addr to-addr amount result idx
	][
		if batch-send-btn/text = "Stop" [
			payment-stop?: yes
			exit
		]
		clear batch-results
		payment-stop?: no
		batch-result-btn/visible?: no
		from-addr: batch-addr-from/text

		if error? price-wei: try [string-to-i256 batch-gas-price/text 9] [
			unview
			eth-ui/show-error-dlg price-wei
			exit
		]

		limit: to-integer gas-limit

		if error? nonce: try [eth-api/get-nonce net-type network from-addr] [
			unview
			view/flags nonce-error-dlg 'modal
			exit
		]

		batch-send-btn/text: "Stop"
		idx: 1
		foreach entry payment-list/data [
			payment-list/selected: idx
			process-events
			addr: find entry "0x"
			to-addr: copy/part addr 42
			amount: trim copy skip addr 42
			if error? amount-wei: try [string-to-i256 amount 18] [
				unview
				eth-ui/show-error-dlg amount-wei
				exit
			]

			signed-data: eth-ui/sign-transaction
				from-addr
				to-addr
				price-wei
				limit
				amount-wei
				nonce
				from-path

			if payment-stop? [break]

			append entry either all [
				signed-data
				binary? signed-data
			][
				result: try [eth-api/publish-tx net-type network signed-data]
				append batch-results result
				either string? result [nonce: nonce + 1 "  √"]["  ×"]
			][
				if signed-data = 'token-error [
					view/flags contract-data-dlg 'modal
					break
				]
				"  ×"
			]
			idx: idx + 1
		]
		unless empty? batch-results [batch-result-btn/visible?: yes]
		batch-send-btn/text: "Send"
	]

	batch-send-dialog: layout [
		title "Batch Payment"
		style lbl:   text  360 middle font [name: font-fixed size: 11]
		text "Account:" batch-addr-from: lbl
		text "Gas Price:"  batch-gas-price: field 48 "21" return

		payment-list: text-list font eth-ui/list-font data [] 600x400 below
		button "Add"	[
			add-payment-dialog/text: "Add payment"
			add-payment-btn/text: "Add"
			view/flags add-payment-dialog 'modal
		]
		button "Edit"	[
			add-payment-dialog/text: "Edit payment"
			entry: pick payment-list/data payment-list/selected
			payment-name/text: copy/part entry find entry #" "
			payment-addr/text: copy/part addr: find entry "0x" 42
			payment-amount/text: trim copy skip addr 42
			add-payment-btn/text: "OK"
			view/flags add-payment-dialog 'modal
		]
		button "Remove" [remove at payment-list/data payment-list/selected]
		button "Import" :do-import-payments
		button "Export" :do-export-payments
		pad 0x165
		batch-result-btn: button "Results" :do-check-result
		batch-send-btn: button "Send"	:do-batch-payment
		do [batch-result-btn/visible?: no]
	]

	add-payment-dialog: layout [
		style field: field 360 font [name: font-fixed size: 10]
		group-box [
			text "Name:" payment-name: field return
			text "Address:" payment-addr: field return
			text "Amount:" payment-amount: field
		] return
		pad 160x0 add-payment-btn: button "Add" :do-add-payment
		pad 20x0 button "Cancel" [unview]
	]

	actors-init: does [
		batch-send-dialog/actors: make object! [
			on-close: func [face event][
				sanitize-payments payment-list/data
				batch-result-btn/visible?: no
			]
		]
	]

	open-batch-ui: func [addr [string!] balance [vector!] path [block!] /local price-wei][
		batch-addr-from/text: copy addr
		total-balance: balance
		from-path: path
		gas-limit: either token-contract ["79510"]["21000"]
		if all [not error? price-wei: try [eth-api/get-gas-price 'standard] price-wei][
			batch-gas-price/text: form-i256/nopad price-wei 9 2
		]
		view batch-send-dialog
	]

]
