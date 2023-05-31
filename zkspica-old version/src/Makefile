SOURCE = utilities.ml datatype.ml parser.mli parser.ml lexer.ml stype.ml einf.ml poly.ml solve.ml reduce.ml pprint.ml main.ml

parser.mli parser.ml:
	ocamlyacc parser.mly
lexer.ml:
	ocamllex lexer.mll

spicabyte: $(SOURCE)
	(ocamlc -o spica glpk.cma $(SOURCE); rm *.cmi *.cmx *.o; cd ..)

spica: $(SOURCE)
	(ocamlopt -o spica glpk.cmxa $(SOURCE); rm *.cmi *.cmx *.o; cd ..)

.SUFFIXES:
	.ml .cmo .mli .cmi

.ml.cmo:
	ocamlc $(SOURCE)

top: $(SOURCE)
	(ocamlmktop glpk.cma $(SOURCE); cd ..)

clean: 
	rm *.cmi *.cmx *.o *.cmo *.exe parser.ml lexer.ml parser.mli lexer.mli



