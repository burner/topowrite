all: src/*.d
	dmd src/*.d -oftopowrite -unittest -debug -gc

release: src/*.d
	dmd src/*.d -oftopowrite -release -O -inline 
