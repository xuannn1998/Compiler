%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "0516022.h"

extern int error_num;
extern int Opt_Symbol;
extern int linenum;
extern int top;
extern FILE	*yyin;
extern char	*yytext;
extern char buf[256];
int yyerror( char *msg );
int yylex();
int level = 0;
int loop = 0;
struct NODE *node;
char str[128];
%}

%union {
	char *text;
	struct NODE *node;
};

%token	<text> ID
%token	<text> INT_CONST
%token	<text> FLOAT_CONST
%token	<text> SCIENTIFIC
%token	<text> STR_CONST

%token	LE_OP NE_OP GE_OP EQ_OP AND_OP OR_OP

%token	READ BOOLEAN WHILE DO IF ELSE TRUE FALSE FOR INT PRINT BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN CONST

%token	L_PAREN	R_PAREN COMMA SEMICOLON ML_BRACE MR_BRACE L_BRACE R_BRACE ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP ASSIGN_OP LT_OP GT_OP NOT_OP

%type <node> inc_level dec_level
%type <node> in_loop out_loop
%type <node> program
%type <node> decl_list funct_def decl_and_def_list
%type <node> var_decl const_decl funct_decl
%type <node> scalar_type identifier_list
%type <node> const_list literal_const
%type <node> array_decl dim
%type <node> parameter_list
%type <node> variable_reference
%type <node> dimension array_list
%type <node> factor
%type <node> compound_statement
%type <node> statement
%type <node> simple_statement
%type <node> var_const_stmt_list
%type <node> while_statement for_statement conditional_statement
%type <node> initial_expression_list initial_expression
%type <node> control_expression_list control_expression
%type <node> increment_expression_list increment_expression
%type <node> logical_expression_list logical_expression
%type <node> logical_term logical_factor relation_expression
%type <node> arithmetic_expression term
%type <node> relation_operator
%type <node> jump_statement
%type <node> function_invoke_statement
%type <node> initial_array literal_list

%start program
%%

inc_level
	:
	{
		level++;
	}
	;

dec_level
	:
	{
		level--;
		print_table(level);
	}
	;

in_loop
	:
	{
		loop++;
	}
	;

out_loop
	:
	{
		loop--;
	}
	;

program
	: decl_list funct_def decl_and_def_list
	{
		$$ = create_node("", program_k, 0, null_t, "", NULL, 3);
		$$->children[0] = $1;
		$$->children[1] = $2;
		$$->children[2] = $3;
		print_table(-1);
	}
	;

decl_list
	: decl_list var_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	| decl_list const_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	| decl_list funct_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	|
	{
		$$ = create_node("", decl_list_k, level, null_t, "", NULL, 0);
	}
	;


decl_and_def_list
	: decl_and_def_list var_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	| decl_and_def_list const_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	| decl_and_def_list funct_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	| decl_and_def_list funct_def
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	|
	{
		$$ = create_node("", decl_and_def_list_k, level, null_t, "", NULL, 0);
	}
;

funct_def
	: scalar_type ID L_PAREN R_PAREN inc_level compound_statement dec_level
	{
		$$ = create_node($2, funct_def_k, level, $1->type, "", NULL, 2);
		$$->children[0] = NULL;
		$$->children[1] = $6;
		$$->value.i = 0;
		funct_def_check($$);
		return_check($$);
	}
	| scalar_type ID L_PAREN parameter_list R_PAREN inc_level compound_statement dec_level
	{
		$$ = create_node($2, funct_def_k, level, $1->type, $4->attribute, NULL, 2);
		$$->children[0] = $4;
		$$->children[1] = $7;
		$$->value = $4->value;
		funct_def_check($$);
		return_check($$);
	}
	| VOID ID L_PAREN R_PAREN inc_level compound_statement dec_level
	{
		$$ = create_node($2, funct_def_k, level, void_t, "", NULL, 2);
		$$->children[0] = NULL;
		$$->children[1] = $6;
		$$->value.i = 0;
		funct_def_check($$);
		no_return_check($$);
	}
	| VOID ID L_PAREN parameter_list R_PAREN inc_level compound_statement dec_level
	{
		$$ = create_node($2, funct_def_k, level, void_t, $4->attribute, NULL, 2);
		$$->children[0] = $4;
		$$->children[1] = $7;
		$$->value = $4->value;
		funct_def_check($$);
		no_return_check($$);
	}
	;

funct_decl :
	scalar_type ID L_PAREN R_PAREN SEMICOLON
	{
		$$ = create_node($2, funct_decl_k, level, $1->type, "", NULL, 0);
		$$->value.i = 0;
		insert_table($$);
 	}
	| scalar_type ID L_PAREN parameter_list R_PAREN SEMICOLON
	{
		$$ = create_node($2, funct_decl_k, level, $1->type, $4->attribute, NULL, 1);
		$$->children[0] = $4;
		$$->value = $4->value;
		top -= $$->value.i;
		insert_table($$);
	}
	| VOID ID L_PAREN R_PAREN SEMICOLON
	{
		$$ = create_node($2, funct_decl_k, level, void_t, "", NULL, 0);
		$$->value.i = 0;
		insert_table($$);
	}
	| VOID ID L_PAREN parameter_list R_PAREN SEMICOLON
 	{
		$$ = create_node($2, funct_decl_k, level, void_t, $4->attribute, NULL, 1);
		$$->children[0] = $4;
		$$->value = $4->value;
		top -= $$->value.i;
		insert_table($$);
	}
	;

parameter_list
	: parameter_list COMMA scalar_type ID
	{
		node = create_node($4, parameter_list_k, level + 1, $3->type, "", NULL, 0);
		insert_table(node);
		add_in_list($1, node);
		sprintf(str, "%s,%s", $1->attribute, choose_type($3->type));
		$1->attribute = strdup(str);
		$$ = $1;
		$$->value.i++;
	}
	| parameter_list COMMA scalar_type array_decl
	{
		$4->type = $3->type;
		sprintf(str, "%s%s", choose_type($3->type), $4->attribute);
		node = create_node($4->name, parameter_list_k, level + 1, array_t, str, NULL, 1);
		node->children[0] = $4;
		insert_table(node);
		add_in_list($1, node);
		sprintf(str, "%s,%s", $1->attribute, node->attribute);
		$1->attribute = strdup(str);
		$$ = $1;
		$$->value.i++;
	}
	| scalar_type array_decl
	{
		$2->type = $1->type;
		sprintf(str, "%s%s", choose_type($1->type), $2->attribute);
		node = create_node($2->name, parameter_list_k, level + 1, array_t, str, NULL, 1);
		node->children[0] = $2;
		insert_table(node);
		$$ = create_node("", parameter_list_k, level + 1, null_t, str, node, 0);
		$$->value.i = 1;
	}
	| scalar_type ID
	{
		node = create_node($2, parameter_list_k, level + 1, $1->type, choose_type($1->type), NULL, 0);
		insert_table(node);
		$$ = create_node("", parameter_list_k, level + 1, null_t, choose_type($1->type), node, 0);
		$$->value.i = 1;
	}
	;

var_decl
	: scalar_type identifier_list SEMICOLON
	{
		$$ = create_node("", var_decl_k, level, $1->type, "", NULL, 1);
		$$->children[0] = $2;
		node = $2;
		while (node != NULL) {
			if (node->type == array_t) {
				node->children[0]->type = $1->type;
				sprintf(str, "%s%s", choose_type($1->type), node->attribute);
				node->attribute = strdup(str);
			}
			else {
				if (node->type != null_t && node->type != $1->type)
					error_msg(linenum, "initial value error");
				node->type = $1->type;
			}
			insert_table(node);
			node = node->in_list;
		}
	}
	;

identifier_list
	: identifier_list COMMA ID
	{
		node = create_node($3, identifier_list_k, level, null_t, "", NULL, 0);
		add_in_list($1, node);
		$$ = $1;
	}
	| identifier_list COMMA ID ASSIGN_OP logical_expression
	{
		node = create_node($3, identifier_list_k, level, $5->type, "", NULL, 0);
		add_in_list($1, node);
		$$ = $1;
	}
	| identifier_list COMMA array_decl ASSIGN_OP initial_array
	{
		if ($3->array_num < $5->value.i) {
			error_msg(linenum, "element number of initial array mismatch.");
		}
		add_in_list($1, $3);
		$$ = $1;
	}
	| identifier_list COMMA array_decl
	{
		add_in_list($1, $3);
		$$ = $1;
	}
	| array_decl ASSIGN_OP initial_array
	{
		if ($1->array_num < $3->value.i) {
			error_msg(linenum, "element number of initial array mismatch.");
		}
		$$ = $1;
	}
	| array_decl
	{
		$$ = $1;
	}
	| ID ASSIGN_OP logical_expression
	{
		$$ = create_node($1, identifier_list_k, level, $3->type, "", NULL, 0);
	}
	| ID
	{
		$$ = create_node($1, identifier_list_k, level, null_t, "", NULL, 0);
	}
	;

initial_array
	: L_BRACE literal_list R_BRACE
	{
		$$ = $2;
	}
	;

literal_list
	: literal_list COMMA logical_expression
	{
		if ($1->type != $3->type)
		{
			error_msg(linenum, "different types in initial array.");
		}
		node = create_node("", literal_list_k, level, $3->type, "", NULL, 0);
		add_in_list($1, node);
		$$ = $1;
		$$->value.i++;
	}
	| logical_expression
	{
		$$ = create_node("", literal_list_k, level, $1->type, "", NULL, 0);
		$$->value.i = 1;
	}
	|
	{
		$$ = create_node("", literal_list_k, level, null_t, "", NULL, 0);
		$$->value.i = 0;
	}
	;

const_decl
	: CONST scalar_type const_list SEMICOLON
	{
		node = $3;
		while (node != NULL) {
			if (node->type != $2->type) error_msg(linenum, "const type different.");
			else insert_table(node);
			node = node->in_list;
		}
		$$ = create_node("", const_decl_k, level, $2->type, "", NULL, 1);
		$$->children[0] = $3;
	}
	;

const_list
	: const_list COMMA ID ASSIGN_OP literal_const
	{
		$5->name = strdup($3);
		$5->kind = const_list_k;
		add_in_list($1, $5);
		$$ = $1;
	}
	| ID ASSIGN_OP literal_const
	{
		$3->name = strdup($1);
		$3->kind = const_list_k;
		$$ = $3;
	}
	;

array_decl
	: ID dim
	{
		int count = 1;
		bzero(str, 64);
		node = $2;
		while (node) {
			strcat(str, node->attribute);
			count *= node->array_num;
			node = node->in_list;
		}
		$$ = create_node($1, array_decl_k, level, array_t, str, NULL, 1);
		$$->children[0] = $2;
		$$->value.i = $2->value.i;
		$$->array_num = count;
	}
	;

dim
	: dim ML_BRACE INT_CONST MR_BRACE
	{
		sprintf(str, "[%s]", $3);
		node = create_node("", dim_k, level, null_t, str, NULL, 0);
		node->array_num = atoi($3);
		add_in_list($1, node);
		$$ = $1;
		$$->value.i++;
	}
	| ML_BRACE INT_CONST MR_BRACE
	{
		sprintf(str, "[%s]", $2);
		$$ = create_node("", dim_k, level, null_t, str, NULL, 0);
		$$->array_num = atoi($2);
		$$->value.i = 1;
	}
	;

compound_statement
	: L_BRACE var_const_stmt_list R_BRACE
	{
		$$ = create_node("", compound_statement_k, level, null_t, "", NULL, 1);
		$$->children[0] = $2;
	}
	;

var_const_stmt_list
	: var_const_stmt_list statement
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	| var_const_stmt_list var_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	| var_const_stmt_list const_decl
	{
		add_in_list($1, $2);
		$$ = $1;
	}
	|
	{
		$$ = create_node("", var_const_stmt_list_k, level, null_t, "", NULL, 0);
	}
	;

statement
	: inc_level compound_statement dec_level
	{
		$$ = $2;
	}
	| simple_statement
	{
		$$ = $1;
	}
	| conditional_statement
	{
		$$ = $1;
	}
	| while_statement
	{
		$$ = $1;
	}
	| for_statement
	{
		$$ = $1;
	}
	| function_invoke_statement
	{
		$$ = $1;
	}
	| jump_statement
	{
		$$ = $1;
	}
	;

simple_statement
	: variable_reference ASSIGN_OP logical_expression SEMICOLON
	{
		if ($1->kind == const_list_k) {
			sprintf(str, "assignment of read-only variable '%s'.", $1->name);
			error_msg(linenum, str);
		}
		else if ($1->type == array_t) {
			error_msg(linenum, "can not assign value to array.");
		}
		else if (type_check($1, node) == 0) {
			sprintf(str, "type mismatch between variable '%s' and value.", $1->name);
			error_msg(linenum, str);
		}
		$$ = $1;
	}
	| PRINT logical_expression SEMICOLON
	{
		if ($2->type == array_t) {
			error_msg(linenum, "can only print scalar type.");
		}
		$$ = create_node("", simple_statement_k, level, null_t, "READ", NULL, 1);
		$$->children[0] = $2;
	}
	| READ variable_reference SEMICOLON
	{
		if ($2->type == array_t) {
			error_msg(linenum, "can only read scalar type.");
		}
		$$ = create_node("", simple_statement_k, level, null_t, "READ", NULL, 1);
		$$->children[0] = $2;
	}
	;

conditional_statement
	: IF L_PAREN logical_expression R_PAREN L_BRACE inc_level var_const_stmt_list dec_level R_BRACE
	{
		if ($3->type != bool_t) {
			error_msg(linenum, "condition expression in 'if' must be boolean type");
		}
		$$ = create_node("", conditional_statement_k, level, null_t, "IF", NULL, 1);
		$$->children[0] = $7;
	}
	| IF L_PAREN logical_expression R_PAREN L_BRACE inc_level var_const_stmt_list dec_level R_BRACE
	  ELSE L_BRACE inc_level var_const_stmt_list dec_level R_BRACE
	{
		if ($3->type != bool_t) {
			error_msg(linenum, "condition expression in 'if' must be boolean type");
		}
		$$ = create_node("", conditional_statement_k, level, null_t, "IFELSE", NULL, 1);
		$$->children[0] = $7;
		$$->children[1] = $13;
	}
	;

while_statement
	: WHILE L_PAREN logical_expression R_PAREN L_BRACE inc_level in_loop var_const_stmt_list out_loop dec_level R_BRACE
	{
		if ($3->type != bool_t) {
			error_msg(linenum, "condition expression in 'while' must be boolean type");
		}
		$$ = create_node("", while_statement_k, level, null_t, "WHILE", NULL, 1);
		$$->children[0] = $8;
	}
	| DO L_BRACE inc_level in_loop var_const_stmt_list out_loop dec_level R_BRACE WHILE L_PAREN logical_expression R_PAREN SEMICOLON
	{
		if ($11->type != bool_t) {
			error_msg(linenum, "condition expression in 'while' must be boolean type");
		}
		$$ = create_node("", while_statement_k, level, null_t, "DOWHILE", NULL, 1);
		$$->children[0] = $5;
	}
	;

for_statement
	: FOR L_PAREN initial_expression_list SEMICOLON control_expression_list SEMICOLON increment_expression_list R_PAREN L_BRACE inc_level in_loop var_const_stmt_list out_loop dec_level R_BRACE
	{
		if ($5->type != bool_t) {
			error_msg(linenum, "control expression in 'for' must be boolean type");
		}
		$$ = create_node("", for_statement_k, level, null_t, "FOR", NULL, 1);
		$$->children[0] = $12;
	}
	;

initial_expression_list
	: initial_expression
	{
		$$ = $1;
	}
	|
	{
		$$ = create_node("", initial_expression_list_k, level, null_t, "", NULL, 0);
	}
	;

initial_expression
	: initial_expression COMMA variable_reference ASSIGN_OP logical_expression
	{
		if ($3->kind == const_list_k) {
			sprintf(str, "assignment of read-only variable %s.", $3->name);
			error_msg(linenum, str);
		}
		else if ($3->type == array_t) {
			error_msg(linenum, "can not assign value to array.");
		}
		else if (type_check($3, $5) == 0) {
			sprintf(str, "type mismatch between variable %s and value.", $3->name);
			error_msg(linenum, str);
		}
		add_in_list($1, $3);
		$$ = $1;
	}
	| initial_expression COMMA logical_expression
	{
		add_in_list($1, $3);
		$$ = $1;
	}
	| logical_expression
	{
		$$ = $1;
	}
	| variable_reference ASSIGN_OP logical_expression
	{
		if ($1->kind == const_list_k) {
			sprintf(str, "assignment of read-only variable %s.", $1->name);
			error_msg(linenum, str);
		}
		else if ($1->type == array_t) {
			error_msg(linenum, "can not assign value to array.");
		}
		else if (type_check($1, $3) == 0) {
			sprintf(str, "type mismatch between variable %s and value.", $1->name);
			error_msg(linenum, str);
		}
		$$ = $1;
	}
	;

control_expression_list
	: control_expression
	{
		$$ = $1;
	}
	|
	{
		$$ = create_node("", control_expression_list_k, level, bool_t, "", NULL, 0);
	}
												;

control_expression
	: control_expression COMMA variable_reference ASSIGN_OP logical_expression
	{
		if ($3->kind == const_list_k) {
			sprintf(str, "assignment of read-only variable %s.", $3->name);
			error_msg(linenum, str);
		}
		else if ($3->type == array_t) {
			error_msg(linenum, "can not assign value to array.");
		}
		else if (type_check($3, $5) == 0) {
			sprintf(str, "type mismatch between variable %s and value.", $3->name);
			error_msg(linenum, str);
		}
		add_in_list($1, $3);
		$$ = $1;
	}
	| control_expression COMMA logical_expression
	{
		add_in_list($1, $3);
		$$ = $1;
	}
	| logical_expression
	{
		$$ = $1;
	}
	| variable_reference ASSIGN_OP logical_expression
	{
		if ($1->kind == const_list_k) {
			sprintf(str, "assignment of read-only variable %s.", $1->name);
			error_msg(linenum, str);
		}
			else if ($1->type == array_t) {
				error_msg(linenum, "can not assign value to array.");
			}
		else if (type_check($1, $3) == 0) {
			sprintf(str, "type mismatch between variable %s and value.", $1->name);
			error_msg(linenum, str);
		}
		$$ = $1;
	}
	;

increment_expression_list
	: increment_expression
	{
		$$ = $1;
	}
	|
	{
		$$ = create_node("", control_expression_list_k, level, bool_t, "", NULL, 0);
	}
	;

increment_expression
	: increment_expression COMMA variable_reference ASSIGN_OP logical_expression
	{
		if ($3->kind == const_list_k) {
			sprintf(str, "assignment of read-only variable %s.", $3->name);
			error_msg(linenum, str);
		}
		else if ($3->type == array_t) {
			error_msg(linenum, "can not assign value to array.");
		}
		else if (type_check($3, $5) == 0) {
			sprintf(str, "type mismatch between variable %s and value.", $3->name);
			error_msg(linenum, str);
		}
		add_in_list($1, $3);
		$$ = $1;
	}
	| increment_expression COMMA logical_expression
	{
		add_in_list($1, $3);
		$$ = $1;
	}
	| logical_expression
	{
		$$ = $1;
	}
	| variable_reference ASSIGN_OP logical_expression
	{
		if ($1->kind == const_list_k) {
			sprintf(str, "assignment of read-only variable %s.", $1->name);
			error_msg(linenum, str);
		}
		else if ($1->type == array_t) {
			error_msg(linenum, "can not assign value to array.");
		}
		else if (type_check($1, $3) == 0) {
			sprintf(str, "type mismatch between variable %s and value.", $1->name);
			error_msg(linenum, str);
		}
		$$ = $1;
	}
	;

function_invoke_statement
	: ID L_PAREN logical_expression_list R_PAREN SEMICOLON
	{
		node = find_name($1);
		if (node->kind != funct_decl_k && node->kind != funct_def_k) {
			sprintf(str, "'%s' is not a function.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else if (node->value.i != $3->value.i) {
			sprintf(str, "arguments number of function '%s' mismatch.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else {
			struct NODE *node1 = node->children[0]->in_list, *node2 = $3->in_list;
			while (node1 != NULL && node2 != NULL) {
				if (type_check(node1, node2) == 0) {
					error_msg(linenum, "invoke function parameters type mismatch.");
					break;
				}
				node1 = node1->in_list;
				node2 = node2->in_list;
			}
			$$ = node;
		}
	}
	| ID L_PAREN R_PAREN SEMICOLON
	{
		node = find_name($1);
		if (node->kind != funct_decl_k && node->kind != funct_def_k) {
			sprintf(str, "'%s' is not a function.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else if (node->value.i != 0) {
			sprintf(str, "too few arguments to function '%s'.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else $$ = node;
	}
	;

jump_statement
	: CONTINUE SEMICOLON
	{
		if (loop == 0) {
			error_msg(linenum, "not in a loop statemet.");
		}
		$$ = create_node("", jump_statement_k, level, null_t, "", NULL, 0);
	}
	| BREAK SEMICOLON
	{
		if (loop == 0) {
			error_msg(linenum, "not in a loop statement.");
		}
		$$ = create_node("", jump_statement_k, level, null_t, "", NULL, 0);
	}
	| RETURN logical_expression SEMICOLON
	{
		$$ = create_node("", return_k, level, $2->type, "", NULL, 0);
	}
	;

variable_reference
	: array_list
	{
		if ((node = find_name($1->name)) != NULL) {
			if (node->type == array_t) {
				if (node->children[0]->value.i == $1->value.i) {
					$1->type = node->children[0]->type;
				}
				else if (node->children[0]->value.i > $1->value.i) {
					$1->value.i = node->children[0]->value.i - $1->value.i;
					$1->type = array_t;
				}
				else {
					error_msg(linenum, "too many dimension");
				}
				$$ = $1;
			}
			else error_msg(linenum, "the variable is not an array.");
		}
		else {
			error_msg(linenum, "variable must declare before used.");
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
	}
	| ID
	{
		if ((node = find_name($1)) != NULL) $$ = node;
		else {
			error_msg(linenum, "variable must declare before used.");
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
	}
	;


logical_expression
	: logical_expression OR_OP logical_term
	{
		logical_check($1, $3);
		$$ = create_node("", logical_term_k, level, bool_t, "", NULL, 0);
	}
	| logical_term
	{
		$$ = $1;
	}
	;

logical_term : logical_term AND_OP logical_factor {
						 	   logical_check($1, $3);
								 $$ = create_node("", logical_term_k, level, bool_t, "", NULL, 0);
						 	 }
						 | logical_factor {
						 		 $$ = $1;
						 	 }
						 ;

logical_factor
	: NOT_OP logical_factor
	{
		if ($2->type != bool_t)
		{
		sprintf(str, "'%s' type error in logical operation.", $2->name);
		error_msg(linenum, str);
		}
		$$ = create_node("", logical_term_k, level, bool_t, "", NULL, 0);
	}
	| relation_expression
	{
		$$ = $1;
	}
	;

relation_expression
	: arithmetic_expression relation_operator arithmetic_expression
	{
		relation_check($1, $2, $3);
		$$ = create_node("", relation_expression_k, level, bool_t, "", NULL, 0);
	}
	| arithmetic_expression
	{
		$$ = $1;
	}
	;

relation_operator
	: LT_OP
	{
		$$ = create_node("", relation_operator_k, level, null_t, "", NULL, 0);
	}
	| LE_OP
	{
		$$ = create_node("", relation_operator_k, level, null_t, "", NULL, 0);
	}
	| EQ_OP
	{
		$$ = create_node("", equality_operator_k, level, null_t, "", NULL, 0);
	}
	| GE_OP
	{
		$$ = create_node("", relation_operator_k, level, null_t, "", NULL, 0);
	}
	| GT_OP
	{
		$$ = create_node("", relation_operator_k, level, null_t, "", NULL, 0);
	}
	| NE_OP
	{
		$$ = create_node("", equality_operator_k, level, null_t, "", NULL, 0);
	}
	;

arithmetic_expression
	: arithmetic_expression ADD_OP term
	{
		arithmetic_check($1, $3);
		$$ = $1;
	}
	| arithmetic_expression SUB_OP term
	{
		arithmetic_check($1, $3);
		$$ = $1;
	}
	| relation_expression
	| term
	{
		$$ = $1;
	}
	;

term
	: term MUL_OP factor
	{
		arithmetic_check($1, $3);
		$$ = $1;
	}
    | term DIV_OP factor
	{
		arithmetic_check($1, $3);
		$$ = $1;
	}
	| term MOD_OP factor
	{
		mod_check($1, $3);
		$$ = $1;
	}
	| factor
	{
		$$ = $1;
	}
	;

factor
	: variable_reference
	{
		$$ = $1;
	}
	| SUB_OP factor
	{
		$$ = $2;
	}
	| L_PAREN logical_expression R_PAREN
	{
		$$ = $2;
	}
	| SUB_OP L_PAREN logical_expression R_PAREN
	{
		$$ = $3;
	}
	| ID L_PAREN logical_expression_list R_PAREN
	{
		node = find_name($1);
		if (node->kind != funct_decl_k && node->kind != funct_def_k) {
			sprintf(str, "'%s' is not a function.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else if (node->value.i != $3->value.i) {
			sprintf(str, "arguments number of function '%s' mismatch.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else {
		struct NODE *node1 = node->children[0]->in_list, *node2 = $3->in_list;
		while (node1 != NULL && node2 != NULL) {
				if (type_check(node1, node2) == 0) {
					error_msg(linenum, "invoke function parameters type mismatch.");
					break;
				}
				node1 = node1->in_list;
				node2 = node2->in_list;
			}
			$$ = node;
		}
	}
	| ID L_PAREN R_PAREN
	{
		node = find_name($1);
		if (node->kind != funct_decl_k && node->kind != funct_def_k) {
			sprintf(str, "'%s' is not a function.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else if (node->value.i != 0) {
			sprintf(str, "arguments number of function '%s' mismatch.", $1);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else $$ = node;
	}
	| literal_const
	{
		$$ = $1;
	}
	| SUB_OP ID L_PAREN logical_expression R_PAREN
	{
		node = find_name($2);
		if (node->kind != funct_decl_k && node->kind != funct_def_k) {
			sprintf(str, "'%s' is not a function.", $2);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else if (node->value.i != $4->value.i) {
			sprintf(str, "arguments number of function '%s' mismatch.", $2);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else {
			struct NODE *node1 = node->children[0]->in_list, *node2 = $4->in_list;
			while (node1 != NULL && node2 != NULL) {
				if (type_check(node1, node2) == 0) {
					error_msg(linenum, "invoke function parameters type mismatch.");
					break;
				}
				node1 = node1->in_list;
				node2 = node2->in_list;
			}
		$$ = node;
		}
	}
	| SUB_OP ID L_PAREN R_PAREN
	{
		node = find_name($2);
		if (node->kind != funct_decl_k && node->kind != funct_def_k) {
			sprintf(str, "'%s' is not a function.", $2);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else if (node->value.i != 0) {
			sprintf(str, "arguments number of function '%s' mismatch.", $2);
			error_msg(linenum, str);
			$$ = create_node("", error_k, level, null_t, "ERROR", NULL, 0);
		}
		else $$ = node;
	}
	;

logical_expression_list
	: logical_expression_list COMMA logical_expression
	{
		add_in_list($1, $3);
		$$ = $1;
		$$->value.i++;
	}
	| logical_expression
	{
		$$ = create_node("", logical_expression_list_k, level, null_t, "", $1, 1);
		$$->value.i = 1;
	}
	;

array_list
	: ID dimension
	{
		$$ = create_node($1, array_list_k, level, array_t, "", NULL, 1);
		$$->children[0] = $2;
		$$->value.i = $2->value.i;
	}
	;

dimension
	: dimension ML_BRACE logical_expression MR_BRACE
	{
		node = create_node("", dimension_k, level, null_t, "", NULL, 0);
		add_in_list($1, node);
		$$ = $1;
		$$->value.i++;
	}
	| ML_BRACE logical_expression MR_BRACE
	{
		if ($2->kind == literal_const_k) {
			if ($2->type != int_t) {
				error_msg(linenum, "array varable can not access by a negative value.");
			}
			if ($2->type == int_t && $2->value.i < 0) {
				error_msg(linenum, "array varable can not access by a negative value.");
			}
		}
		$$ = create_node("", dimension_k, level, null_t, "", NULL, 0);
		$$->value.i = 1;
	}
	;

scalar_type
	: INT
	{
		$$ = create_node("", scalar_type_k, level, int_t, "", NULL, 0);
	}
	| DOUBLE
	{
		$$ = create_node("", scalar_type_k, level, double_t, "", NULL, 0);
	}
	| STRING
	{
		$$ = create_node("", scalar_type_k, level, string_t, "", NULL, 0);
	}
	| BOOL
	{
		$$ = create_node("", scalar_type_k, level, bool_t, "", NULL, 0);
	}
	| FLOAT
	{
		$$ = create_node("", scalar_type_k, level, float_t, "", NULL, 0);
	}
	;

literal_const
	: INT_CONST
	{
		$$ = create_node("", literal_const_k, level, int_t, $1, NULL, 0);
		$$->value.i = atoi($1);
	}
	| SUB_OP INT_CONST
	{
		sprintf(str, "-%s", $2);
		$$ = create_node("", literal_const_k, level, int_t, str, NULL, 0);
		$$->value.i = -atoi($2);
	}
	| FLOAT_CONST
	{
		$$ = create_node("", literal_const_k, level, float_t, $1, NULL, 0);
		$$->value.d = atof($1);
	}
	| SUB_OP FLOAT_CONST
	{
		sprintf(str, "-%s", $2);
		$$ = create_node("", literal_const_k, level, float_t, str, NULL, 0);
		$$->value.d = -atof($2);
	}
	| SCIENTIFIC
	{
		$$ = create_node("", literal_const_k, level, double_t, $1, NULL, 0);
		$$->value.d = atof($1);
	}
	| SUB_OP SCIENTIFIC
	{
		sprintf(str, "-%s", $2);
		$$ = create_node("", literal_const_k, level, double_t, str, NULL, 0);
		$$->value.d = -atof($2);
	}
	| STR_CONST
	{
		$$ = create_node("", literal_const_k, level, string_t, $1, NULL, 0);
		$$->value.s = strdup($1);
	}
	| TRUE
	{
		$$ = create_node("", literal_const_k, level, bool_t, "true", NULL, 0);
		$$->value.i = 1;
	}
	| FALSE
	{
		$$ = create_node("", literal_const_k, level, bool_t, "false", NULL, 0);
		$$->value.i = 0;
	}
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

