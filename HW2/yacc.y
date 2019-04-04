%{
#include <stdio.h>
#include <stdlib.h>

extern int linenum;             /* declared in lex */
extern FILE *yyin;
extern int yylex(void);
extern char *yytext;
extern char buf[256];

int yyerror(char* msg);
%}

%token SEMICOLON    /* ; */
%token COMMA        /* , */
%token LEFT_PAR RIGHT_PAR        /* () */
%token LEFT_SQUARE RIGHT_SQUARE        /* [] */
%token LEFT_BRACE RIGHT_BRACE        /* {} */

%token ID           /* identifier */

/* keyword */
%token INT WHILE DO IF TRUE FALSE FOR PRINT CONST READ BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN

%token STRING_ INT_ FLOAT_ SCIENTIFIC

%nonassoc ELSE

%right '='
%left OR
%left AND
%right '!'
%left EQ NE GT GE LT LE
%left '+' '-'
%left '*' '/' '%'

%%

program : declaration_list func_def decl_and_def_list
	      ;

decl_and_def_list : decl_and_def_list func_decl
                  | decl_and_def_list var_decl
                  | decl_and_def_list const_decl
                  | decl_and_def_list func_def
                  |
                  ;

declaration_list : declaration_list const_decl
                 | declaration_list var_decl
                 | declaration_list func_decl
                 |
				         ;

func_def : type ID LEFT_PAR argument_list RIGHT_PAR compound
         | procedure_def
         ;

procedure_def : VOID ID LEFT_PAR argument_list RIGHT_PAR compound
              ;

statement : compound
          | simple
          | conditional
          | while
          | for
          | jump
          ;

compound : LEFT_BRACE compound_content RIGHT_BRACE
         ;

compound_content : compound_content const_decl
                 | compound_content var_decl
                 | compound_content statement
                 |
                 ;

simple : simple_content SEMICOLON
       ;

simple_content : variable_ref '=' expression
               | PRINT expression
               | READ variable_ref
               | expression
               ;

expression : expression OR expression
           | expression AND expression
           | '!' expression
           | expression LE expression
           | expression LT expression
           | expression GT expression
           | expression GE expression
           | expression EQ expression
           | expression NE expression
           | expression '+' expression
           | expression '-' expression
           | expression '%' expression
           | expression '*' expression
           | expression '/' expression
           | '-' expression %prec '*'
           | LEFT_PAR expression RIGHT_PAR %prec '*'
           | literal_const
           | variable_ref
           | function_invocation
           ;

function_invocation : ID LEFT_PAR expression_list RIGHT_PAR
                    ;

expression_list : non_empty_expression_list
                |
                ;

non_empty_expression_list : non_empty_expression_list COMMA expression
                          | expression
                          ;

variable_ref : ID
             | array_ref
             ;

array_ref : ID arr_ref_square
          ;

arr_ref_square : arr_ref_square square_e
               | square_e
               ;

square_e : LEFT_SQUARE expression RIGHT_SQUARE
         ;

conditional : IF LEFT_PAR boolean_e RIGHT_PAR compound ELSE compound
            | IF LEFT_PAR boolean_e RIGHT_PAR compound
            ;

boolean_e : expression
          ;

while : WHILE LEFT_PAR boolean_e RIGHT_PAR compound
      | DO compound WHILE LEFT_PAR boolean_e RIGHT_PAR SEMICOLON
      ;

for : FOR LEFT_PAR initial_e SEMICOLON control_e SEMICOLON increment_e RIGHT_PAR compound
    ;

jump : RETURN expression SEMICOLON
     | BREAK SEMICOLON
     | CONTINUE SEMICOLON
     ;

initial_e : ID '=' expression
          | expression
          |
          ;

control_e : ID '=' expression 
          | expression
          |
          ;

increment_e : ID '=' expression
            | expression
            |
            ;

const_decl : CONST type const_list SEMICOLON
           ;

const_list : const_list COMMA const
           | const
           ;

const : ID '=' literal_const
      ;

literal_const : INT_
              | STRING_
              | FLOAT_
              | SCIENTIFIC
              | TRUE
              | FALSE
              ;

var_decl : type var_list SEMICOLON
         ;

type : INT
     | DOUBLE
     | FLOAT
     | STRING
     | BOOL
     ;

var_list : var_list COMMA var
         | var
         ;

var : var_no_initial
    | var_initial
    ;

var_no_initial : ID
               | ID array
               ;

var_initial : ID '=' expression
            | ID array '=' initial_array
            ;

initial_array : LEFT_BRACE expression_list RIGHT_BRACE
              ;

array : array LEFT_SQUARE INT_ RIGHT_SQUARE
      | LEFT_SQUARE INT_ RIGHT_SQUARE
      ;

func_decl : type ID LEFT_PAR argument_list RIGHT_PAR SEMICOLON
          | procedure_decl
          ;

procedure_decl : VOID ID LEFT_PAR argument_list RIGHT_PAR SEMICOLON
               ;


argument_list : non_empty_argument_list
              |
              ;

non_empty_argument_list : non_empty_argument_list COMMA argument
                        | argument
                        ;

argument : type var_no_initial
         ;

%%

int yyerror( char *msg )
{
  fprintf( stderr, "\n|--------------------------------------------------------------------------\n" );
	fprintf( stderr, "| Error found in Line #%d: %s\n", linenum, buf );
	fprintf( stderr, "|\n" );
	fprintf( stderr, "| Unmatched token: %s\n", yytext );
  fprintf( stderr, "|--------------------------------------------------------------------------\n" );
  exit(-1);
}

int main( int argc, char **argv )
{
	if( argc != 2 ) {
		fprintf(  stdout,  "Usage:  ./parser  [filename]\n"  );
		exit(0);
	}

	FILE *fp = fopen( argv[1], "r" );
	
	if( fp == NULL )  {
		fprintf( stdout, "Open  file  error\n" );
		exit(-1);
	}
	
	yyin = fp;
	yyparse();

	fprintf( stdout, "\n" );
	fprintf( stdout, "|--------------------------------|\n" );
	fprintf( stdout, "|  There is no syntactic error!  |\n" );
	fprintf( stdout, "|--------------------------------|\n" );
	exit(0);
}

