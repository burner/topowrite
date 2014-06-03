{ 
	"a" : {
		"depends" : [
			"b", "c"
		],
		"input" : "a.tex"
	},

	"b" : {
		"depends" : [
			"c", "e"
		],
		"input" : "b.tex"
	},

	"c" : {
		"input" : "c.tex"
	},

	"d" : {
		"depends" : [
			"c"
		],
		"input" : "d.tex"
	},

	"e" : {
		"input" : "e.tex"
	},

	"header" : "settings.tex"
}
