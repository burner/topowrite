module simpleoutlogger;

import std.stdio;
import std.string;
import logger;

class SimpleLogger : Logger {
	this() { super(); }

    override void writeLogMsg(LoggerPayload payload) @trusted {
		size_t fnIdx = payload.file.lastIndexOf('/');
		fnIdx = fnIdx == -1 ? 0 : fnIdx+1;
		writefln("%s:%d | %s", payload.file[fnIdx .. $], payload.line,
			payload.msg
		);
    }
}
