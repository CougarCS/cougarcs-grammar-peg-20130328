include Makefile.config

all: peg.pdf lang/calc

peg.pdf: peg.tex \
	example.c example.html \
	java.ebnf java-explain.ebnf java-explain-more.ebnf
	latexmk -g -pdf peg.tex

run: lang/calc.c.run lang/calc.py.run lang/calc.pl.run

%.peg.c: %.peg
	$(PEG) -o $@ $<

%.c: %.leg
	$(LEG) -o $@ $<

lang/calc:	lang/calc.c

lang/calc.c.run:	lang/calc
	./lang/calc < ./lang/calculator.in

lang/calc.py.run:	lang/calc.py
	python ./lang/calc.py < ./lang/calculator.in

lang/calc.pl.run:	lang/calc.pl
	perl ./lang/calc.pl < ./lang/calculator.in

cleanlang:
	-rm lang/calc lang/calc.c

clean: cleanlang
	make -f ~/make/texclean.mk $@
	-rm peg.fdb_latexmk
	-rm *.in
cleanall:
	make -f ~/make/texclean.mk $@
