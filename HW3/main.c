#include <stdio.h>
#include <stdlib.h>

extern int yyparse();
extern FILE* yyin;
extern void print_statistic();
extern int Opt_Statistic;

int main( int argc, char **argv )
{
	if( argc == 1 )
	{
		yyin = stdin;
	}
	else if( argc == 2 )
	{
		FILE *fp = fopen( argv[1], "r" );
		if( fp == NULL ) {
				fprintf( stderr, "Open file error\n" );
				exit(-1);
		}
		yyin = fp;
	}
	else
	{
	  	fprintf( stderr, "Usage: ./parser [filename]\n" );
   		exit(0);
 	} 

	yyparse();	/* primary procedure of parser */

	
	fprintf( stdout, "\n|--------------------------------|\n" );
	fprintf( stdout, "|  There is no syntactic error!  |\n" );
	fprintf( stdout, "|--------------------------------|\n" );

	if(Opt_Statistic == 1) print_statistic();
	exit(0);
}

