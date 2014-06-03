import stdx.getopt;

import std.algorithm;
import std.json;
import std.stdio;
import std.file;

import logger;
import simpleoutlogger;

import item;
import itembuilder;
import sortdep;

string templateS =
`
{
	"header" : "your latex settings to place before begin{document}",
	"introduction" : "the input file to place as introduction",
	"conclusion" : "the input file to place as conclusion",

	"a" : {
		"depends" : ["b", "c"],
		"input" : "what input file describes a"
	}
`;

string usage = "topowrite -i INPUTFILE -o OUTPUTFILE";

void main(string[] args) {
	LogManager.defaultLogger = new SimpleLogger;
	LogManager.defaultLogger.setFatalHandler = delegate() {
		throw new Error("Default Logger logged a fatal message");
	};
	string inputFile;
	string outputFile;
	string templateFile;
	LogLevel ll = LogLevel.fatal;

	auto opt = getoptEx(args, 
		"i|input", "The input file to process.", &inputFile,
		"o|output", "The output file to write the result to.", &outputFile,
		"t|template", "If you want a template input file.", &templateFile,
		"l|loglevel", "The LogLevel to use.", &ll
	);

	LogManager.globalLogLevel = ll;

	if(opt.help) {
        defaultGetoptXPrinter("Some information about the program.",
			opt.options
		);
		return;
	}

	if(!templateFile.empty) {
		auto f = File(templateFile, "w");
		f.write(templateS);
		return;
	}

	if(inputFile.empty) {
		writeln("You need to specify a input file.");
		writeln(usage);
		return;
	} else if(outputFile.empty) {
		writeln("You need to specify a output file.");
		writeln(usage);
		return;
	}

	if(!exists(inputFile)){
		writeln("The input file does not exists.");
		return;
	}

	auto iFile = File(inputFile);

	auto pRslt = parseJSON(iFile.byLine().joiner());
	auto parseResult = buildItems(pRslt);

	auto sorted = sortDependencies(parseResult.items);
	traceF("%s", sorted.reverse);
	trace(parseResult.header);

	auto output = File(outputFile, "w");
	assert(!parseResult.header.empty, "You must specify a header.");
	auto header = File(parseResult.header, "r");
	copy(header.byLine().map!(a => a[0 .. ($ > 0) ? $-1 : $] ~ "\n"), output.lockingTextWriter());
	//output.writefln("\\input{%s}", parseResult.header);
	output.writeln("\n\\begin{document}");
	if(!parseResult.introduction.empty) {
		output.writefln("\\input{%s}", parseResult.introduction);
	}

	foreach(key; sorted) {
		output.writefln("\\input{%s}", key.input);
	}

	if(!parseResult.conclusion.empty) {
		output.writefln("\\input{%s}", parseResult.conclusion);
	}

	output.writeln("\\end{document}");
}
