all: parser

parser: lex.yy.c y.tab.c
	gcc -o parser lex.yy.c y.tab.c -ly -ll

y.tab.c: yacc.y
	yacc -d -v yacc.y

lex.yy.c: lex.l
	lex lex.l