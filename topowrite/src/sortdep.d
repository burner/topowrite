module sortdep;

import item;

enum Mark {
	Unmarked,
	TempMark,
	Marked
}

Item[] sortDependencies(Item[string] items) {
	Item[] ret;
	Mark[string] marks;

	foreach(key, value; items) {
		marks[key] = Mark.Unmarked;
	}

	foreach(key, item; items) {
		if(marks[key] == Mark.Unmarked) {
			visit(ret, marks, items, key);
		}
	}

	return ret;
}

void visit(ref Item[] ret, ref Mark[string] marks, Item[string] items, 
		string n) {
	Mark nMark;
	if(n in marks) {
		nMark = marks[n];
	}

	if(nMark == Mark.TempMark) {
		throw new Exception("Given input is not sortable.");
	} else if(nMark != Mark.Marked) {
		marks[n] = Mark.TempMark;

		foreach(follow; items[n].depends) {
			visit(ret, marks, items, follow);
		}

		marks[n] = Mark.Marked;

		ret = [items[n]] ~ ret;
	}
}
