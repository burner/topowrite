module itembuilder;

import std.stdio;
import std.json;
import item;
import logger;

struct BuildResult {
	string header;
	Item[string] items;
}

BuildResult buildItems(JSONValue v) {
	BuildResult ret;
	//Item[string] ret;

	auto t = v.type();
	assert(t == JSON_TYPE.OBJECT);

	auto root = v.object();

	foreach(key, item; root) {
		if(key == "header") {
			t = item.type();
			assert(t == JSON_TYPE.STRING, 
				"The header key must have a string as a value.");
			ret.header = item.str();
		} else {
			ret.items[key] = buildItem(key, item);
		}
	}

	return ret;
}

Item buildItem(string name,  JSONValue v) {
	Item ret;
	ret.name = name;

	foreach(key, value; v.object()) {
		traceF("%s %s", key, value);
		if(key == "depends") {
			auto depType = value.type();
			assert(depType == JSON_TYPE.ARRAY,
				"The depends key must have an array as a value.");

			foreach(dep; value.array()) {
				assert(dep.type() == JSON_TYPE.STRING,
					"The depends elem must have a string as a value.");
				ret.depends ~= dep.str();
			}
		} else if(key == "input") {
			auto inType = value.type();
			assert(inType == JSON_TYPE.STRING,
				"The input key must have a string as a value.");

			ret.input = value.str();
		} else {
			assert(false, "Invalid key " ~ key);
		}
	}

	return ret;
}
