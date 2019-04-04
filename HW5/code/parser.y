%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "header.h"
#include "symtab.h"
#include "semcheck.h"

extern int linenum;
extern FILE	*yyin;
extern char	*yytext;
extern char buf[256];
extern int Opt_Symbol;		/* declared in lex.l */
int yylex();

int ismain = 0;
int id = 0;
int tid = 0;
int label = 0;
int true_false_label = 1;
int scope = 0;
char fileName[256];
struct SymTable *symbolTable;
__BOOLEAN paramError;
struct PType *funcReturn;
__BOOLEAN semError = __FALSE;
int inloop = 0;
int loop = 0;
__BOOLEAN isreturn = __FALSE;
FILE *output;

char to_lowercase(char c);
char typeCode(SEMTYPE type);
SEMTYPE typeTrans(struct PType *lhs, struct PType *rhs);
SEMTYPE singleTypeTrans(struct PType *lhs, struct PType *rhs);

%}

%union {
	int intVal;
	float floatVal;
	char *lexeme;
	struct idNode_sem *id;
	struct ConstAttr *constVal;
	struct PType *ptype;
	struct param_sem *par;
	struct expr_sem *exprs;
	struct expr_sem_node *exprNode;
	struct constParam *constNode;
	struct varDeclParam* varDeclNode;
};

%token	LE_OP NE_OP GE_OP EQ_OP AND_OP OR_OP
%token	READ BOOLEAN WHILE DO IF ELSE TRUE FALSE FOR INT PRINT BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN CONST
%token	L_PAREN R_PAREN COMMA SEMICOLON ML_BRACE MR_BRACE L_BRACE R_BRACE ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP ASSIGN_OP LT_OP GT_OP NOT_OP

%token <lexeme>ID
%token <intVal>INT_CONST
%token <floatVal>FLOAT_CONST
%token <floatVal>SCIENTIFIC
%token <lexeme>STR_CONST

%type<ptype> scalar_type dim
%type<par> array_decl parameter_list
%type<constVal> literal_const
%type<constNode> const_list
%type<exprs> variable_reference logical_expression logical_term logical_factor relation_expression arithmetic_expression term factor logical_expression_list literal_list initial_array
%type<intVal> relation_operator add_op mul_op dimension
%type<varDeclNode> identifier_list

%start program
%%

program
	:
	{
		output = fopen("output.j", "w");
		fprintf(output, ".class public output\n");
		fprintf(output, ".super java/lang/Object\n");
		fprintf(output, ".field public static _sc Ljava/util/Scanner;\n");
	}
	decl_list funct_def decl_and_def_list
	{
		if(Opt_Symbol == 1) printSymTable( symbolTable, scope );
	}
	;

decl_list //nothing
	: decl_list var_decl
	| decl_list const_decl
	| decl_list funct_decl
	|
	;

decl_and_def_list //nothing
	: decl_and_def_list var_decl
	| decl_and_def_list const_decl
	| decl_and_def_list funct_decl
	| decl_and_def_list funct_def
	|
	;

funct_def
	: scalar_type ID L_PAREN R_PAREN
	{
		funcReturn = $1;
		struct SymNode *node;
		node = findFuncDeclaration( symbolTable, $2 );

		if ( node != 0 ) verifyFuncDeclaration( symbolTable, 0, $1, node );
		else insertFuncIntoSymTable( symbolTable, $2, 0, $1, scope, __TRUE );

		if (strcmp($2, "main") == 0)
		{
			ismain = 1;
			id = tid = 1;
		}
		fprintf(output, ".method public static %s(%s)%c\n", $2, (ismain ? "[Ljava/lang/String;" : ""), ismain ? 'V' : typeCode($1->type));
		fprintf(output, ".limit stack %d\n", 100);
		fprintf(output, ".limit locals %d\n", 100);
		if (ismain)
		{
			fprintf(output, "new java/util/Scanner\n");
			fprintf(output, "dup\n");
			fprintf(output, "getstatic java/lang/System/in Ljava/io/InputStream;\n");
			fprintf(output, "invokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
			fprintf(output, "putstatic output/_sc Ljava/util/Scanner;\n");
		}
	}
	compound_statement
	{
		if (ismain && isreturn == __FALSE) fprintf(output, "return\n");
		funcReturn = 0;
		fprintf(output, ".end method\n");
		ismain = id = tid = 0;
	}
	| scalar_type ID L_PAREN parameter_list R_PAREN
	{
		funcReturn = $1;

		paramError = checkFuncParam( $4 );
		if( paramError == __TRUE )
		{
			fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
			semError = __TRUE;
		}
		// check and insert function into symbol table
		else
		{
			struct SymNode *node;
			node = findFuncDeclaration( symbolTable, $2 );

			if( node != 0 )
			{
				if(verifyFuncDeclaration( symbolTable, $4, $1, node ) == __TRUE)
				{
					insertParamIntoSymTable( symbolTable, $4, scope+1 );
				}
			}
			else
			{
				insertParamIntoSymTable( symbolTable, $4, scope+1 );
				insertFuncIntoSymTable( symbolTable, $2, $4, $1, scope, __TRUE );
			}
		}
		fprintf(output, ".method public static %s(", $2);
		struct param_sem *ptr = $4;
		while (ptr != NULL)
		{
			fprintf(output, "%c", typeCode($4->pType->type));
			ptr = ptr->next;
			tid++;
		}
		id = tid;
		fprintf(output, ")%c\n", typeCode($1->type));
		fprintf(output, ".limit stack %d\n", 100);
		fprintf(output, ".limit locals %d\n", 100);
		if (ismain)
		{
			fprintf(output, "new java/util/Scanner\n");
			fprintf(output, "dup\n");
			fprintf(output, "getstatic java/lang/System/in Ljava/io/InputStream;\n");
			fprintf(output, "invokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
			fprintf(output, "putstatic output/_sc Ljava/util/Scanner;\n");
		}
	}
	compound_statement
	{
		funcReturn = 0;
		fprintf(output, ".end method\n");
		ismain = id = tid = 0;
	}
	| VOID ID L_PAREN R_PAREN
	{
		funcReturn = createPType(VOID_t);
		struct SymNode *node;
		node = findFuncDeclaration( symbolTable, $2 );

		if( node != 0 )
		{
			verifyFuncDeclaration( symbolTable, 0, createPType( VOID_t ), node );
		}
		else
		{
			insertFuncIntoSymTable( symbolTable, $2, 0, createPType( VOID_t ), scope, __TRUE );
		}

		if (strcmp($2, "main") == 0)
		{
			ismain = 1;
			id = 1;
		}
		fprintf(output, ".method public static %s(%s)V\n", $2, (ismain ? "[Ljava/lang/String;" : ""));
		fprintf(output, ".limit stack %d\n", 100);
		fprintf(output, ".limit locals %d\n", 100);
		if (ismain)
		{
			fprintf(output, "new java/util/Scanner\n");
			fprintf(output, "dup\n");
			fprintf(output, "getstatic java/lang/System/in Ljava/io/InputStream;\n");
			fprintf(output, "invokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
			fprintf(output, "putstatic output/_sc Ljava/util/Scanner;\n");
		}
	}
	compound_statement
	{
		funcReturn = 0;
		fprintf(output, "return\n");
		fprintf(output, ".end method\n");
		ismain = id = tid = 0;
	}
	| VOID ID L_PAREN parameter_list R_PAREN
	{
		funcReturn = createPType(VOID_t);

		paramError = checkFuncParam( $4 );
		if( paramError == __TRUE ){
			fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
			semError = __TRUE;
		}
		// check and insert function into symbol table
		else{
			struct SymNode *node;
			node = findFuncDeclaration( symbolTable, $2 );

			if( node != 0 ){
				if(verifyFuncDeclaration( symbolTable, $4, createPType( VOID_t ), node ) == __TRUE){
					insertParamIntoSymTable( symbolTable, $4, scope+1 );
				}
			}
			else{
				insertParamIntoSymTable( symbolTable, $4, scope+1 );
				insertFuncIntoSymTable( symbolTable, $2, $4, createPType( VOID_t ), scope, __TRUE );
			}
		}
		fprintf(output, ".method public static %s(", $2);
		struct param_sem *ptr = $4;
		while (ptr != NULL) {
			fprintf(output, "%c", typeCode($4->pType->type));
			ptr = ptr->next;
			tid++;
		}
		id = tid;
		fprintf(output, ")V\n");
		fprintf(output, ".limit stack %d\n", 100);
		fprintf(output, ".limit locals %d\n", 100);
		if (ismain)
		{
			fprintf(output, "new java/util/Scanner\n");
			fprintf(output, "dup\n");
			fprintf(output, "getstatic java/lang/System/in Ljava/io/InputStream;\n");
			fprintf(output, "invokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
			fprintf(output, "putstatic output/_sc Ljava/util/Scanner;\n");
		}
	}
	compound_statement
	{
		funcReturn = 0;
		fprintf(output, "return\n");
		fprintf(output, ".end method\n");
		ismain = id = tid = 0;
	}
	;

funct_decl //nothing
	: scalar_type ID L_PAREN R_PAREN SEMICOLON
	{
		insertFuncIntoSymTable( symbolTable, $2, 0, $1, scope, __FALSE );
	}
	| scalar_type ID L_PAREN parameter_list R_PAREN SEMICOLON
	{
		paramError = checkFuncParam( $4 );
		if( paramError == __TRUE )
		{
			fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
			semError = __TRUE;
		}
		else
		{
			insertFuncIntoSymTable( symbolTable, $2, $4, $1, scope, __FALSE );
		}
	}
	| VOID ID L_PAREN R_PAREN SEMICOLON
	{
		insertFuncIntoSymTable( symbolTable, $2, 0, createPType( VOID_t ), scope, __FALSE );
	}
	| VOID ID L_PAREN parameter_list R_PAREN SEMICOLON
	{
		paramError = checkFuncParam( $4 );
		if( paramError == __TRUE ){
			fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
			semError = __TRUE;
		}
		else {
			insertFuncIntoSymTable( symbolTable, $2, $4, createPType( VOID_t ), scope, __FALSE );
		}
	}
	;

parameter_list //nothing
	: parameter_list COMMA scalar_type ID
	{
		struct param_sem *ptr;
		ptr = createParam( createIdList( $4 ), $3 );
		param_sem_addParam( $1, ptr );
		$$ = $1;
	}
	| parameter_list COMMA scalar_type array_decl
	{
		$4->pType->type= $3->type;
		param_sem_addParam( $1, $4 );
		$$ = $1;
	}
	| scalar_type array_decl
	{
		$2->pType->type = $1->type;
		$$ = $2;
	}
	| scalar_type ID
	{
		$$ = createParam( createIdList( $2 ), $1 );
	}
	;

var_decl
	: scalar_type identifier_list SEMICOLON
	{
		struct varDeclParam *ptr;
		struct SymNode *newNode;
		for( ptr=$2 ; ptr!=0 ; ptr=(ptr->next) )
		{
			if( verifyRedeclaration( symbolTable, ptr->para->idlist->value, scope ) == __FALSE ) { }
			else
			{
				if( verifyVarInitValue( $1, ptr, symbolTable, scope ) ==  __TRUE )
				{
					int tmp = id;
					if (scope == 0 && !ptr->isInit)
					{
						fprintf(output, ".field public static %s %c\n", ptr->para->idlist->value, typeCode($1->type));
						tmp = -1;
					}
					else
					{
						if (ptr->para->pType->type == DOUBLE_t) id++;
						id++;
					}
					newNode = createVarNode( ptr->para->idlist->value, scope, ptr->para->pType, tmp );
					insertTab( symbolTable, newNode );
				}
			}
		}
	}
	;

identifier_list
	: identifier_list COMMA ID
	{
		struct param_sem *ptr;
		struct varDeclParam *vptr;
		ptr = createParam( createIdList( $3 ), createPType( VOID_t ) );
		vptr = createVarDeclParam( ptr, 0 );
		addVarDeclParam( $1, vptr );
		$$ = $1;
		if (scope == 0) { }
		else if (scope != 0) tid++;
	}
	| identifier_list COMMA ID ASSIGN_OP logical_expression
	{
		struct param_sem *ptr;
		struct varDeclParam *vptr;
		ptr = createParam( createIdList( $3 ), createPType( VOID_t ) );
		vptr = createVarDeclParam( ptr, $5 );
		vptr->isArray = __TRUE;
		vptr->isInit = __TRUE;
		addVarDeclParam( $1, vptr );
		$$ = $1;

		if (scope == 0)
		{
			fprintf(output, ".field public static %s %c\n", $3, typeCode($5->pType->type));
		}
		else
		{
			fprintf(output, "%cstore %d\n", to_lowercase(typeCode($5->pType->type)), tid);
			if ($5->pType->type == DOUBLE_t) tid++;
			tid++;
		}
	}
	| identifier_list COMMA array_decl ASSIGN_OP initial_array
		{
			struct varDeclParam *ptr;
			ptr = createVarDeclParam( $3, $5 );
			ptr->isArray = __TRUE;
			ptr->isInit = __TRUE;
			addVarDeclParam( $1, ptr );
			$$ = $1;
		}
	| identifier_list COMMA array_decl
		{
			struct varDeclParam *ptr;
			ptr = createVarDeclParam( $3, 0 );
			ptr->isArray = __TRUE;
			addVarDeclParam( $1, ptr );
			$$ = $1;
		}
	| array_decl ASSIGN_OP initial_array
		{
			$$ = createVarDeclParam( $1 , $3 );
			$$->isArray = __TRUE;
			$$->isInit = __TRUE;
		}
	| array_decl
		{
			$$ = createVarDeclParam( $1 , 0 );
			$$->isArray = __TRUE;
		}
	| ID ASSIGN_OP logical_expression
	{
		struct param_sem *ptr;
		ptr = createParam( createIdList( $1 ), createPType( VOID_t ) );
		$$ = createVarDeclParam( ptr, $3 );
		$$->isInit = __TRUE;

		if (scope == 0)
		{
			fprintf(output, ".field public static %s %c\n", $1, typeCode($3->pType->type));
		}
		else
		{
			fprintf(output, "%cstore %d\n", to_lowercase(typeCode($3->pType->type)), tid);
			if ($3->pType->type == DOUBLE_t) tid++;
			tid++;
		}
	}
	| ID
	{
		struct param_sem *ptr;
		ptr = createParam( createIdList( $1 ), createPType( VOID_t ) );
		$$ = createVarDeclParam( ptr, 0 );

		if (scope == 0) { }
		else if (scope != 0) tid++;
	}
	;

initial_array //nothing
	: L_BRACE literal_list R_BRACE
	{
		$$ = $2;
	}
	;

literal_list //nothing
	: literal_list COMMA logical_expression
	{
		struct expr_sem *ptr;
		for( ptr=$1; (ptr->next)!=0; ptr=(ptr->next) );
		ptr->next = $3;
		$$ = $1;
	}
	| logical_expression
	{
		$$ = $1;
	}
	|
	;

const_decl //nothing
	: CONST scalar_type const_list SEMICOLON
	{
		struct SymNode *newNode;
		struct constParam *ptr;
		for( ptr=$3; ptr!=0; ptr=(ptr->next) )
		{
			if( verifyRedeclaration( symbolTable, ptr->name, scope ) == __TRUE )
			{//no redeclare
				if( ptr->value->category != $2->type )
				{//type different
					if( !(($2->type==FLOAT_t || $2->type == DOUBLE_t ) && ptr->value->category==INTEGER_t) )
					{
						if(!($2->type==DOUBLE_t && ptr->value->category==FLOAT_t))
						{
							fprintf( stdout, "########## Error at Line#%d: const type different!! ##########\n", linenum );
							semError = __TRUE;
						}
						else
						{
							newNode = createConstNode( ptr->name, scope, $2, ptr->value );
							insertTab( symbolTable, newNode );
						}
					}
					else
					{
						newNode = createConstNode( ptr->name, scope, $2, ptr->value );
						insertTab( symbolTable, newNode );
					}
				}
				else
				{
					newNode = createConstNode( ptr->name, scope, $2, ptr->value );
					insertTab( symbolTable, newNode );
				}
			}
		}
	}
	;

const_list //nothing
	: const_list COMMA ID ASSIGN_OP literal_const
	{
		addConstParam( $1, createConstParam( $5, $3 ) );
		$$ = $1;
	}
	| ID ASSIGN_OP literal_const
	{
		$$ = createConstParam( $3, $1 );
	}
	;

array_decl //nothing
	: ID dim
	{
		$$ = createParam( createIdList( $1 ), $2 );
	}
	;

dim //nothing
	: dim ML_BRACE INT_CONST MR_BRACE
	{
		if( $3 == 0 )
		{
			fprintf( stdout, "########## Error at Line#%d: array size error!! ##########\n", linenum );
			semError = __TRUE;
		}
		else increaseArrayDim( $1, 0, $3 );
	}
	| ML_BRACE INT_CONST MR_BRACE
	{
		if( $2 == 0 )
		{
			fprintf( stdout, "########## Error at Line#%d: array size error!! ##########\n", linenum );
			semError = __TRUE;
		}
		else
		{
			$$ = createPType( VOID_t );
			increaseArrayDim( $$, 0, $2 );
		}
	}
	;

compound_statement //nothing
	:
	{
		scope++;
	}
	L_BRACE var_const_stmt_list R_BRACE
	{
		// print contents of current scope
		if( Opt_Symbol == 1 )
			printSymTable( symbolTable, scope );

		deleteScope( symbolTable, scope );	// leave this scope, delete...
		scope--;
	}
	;

var_const_stmt_list //nothing
	: var_const_stmt_list statement
	| var_const_stmt_list var_decl
	| var_const_stmt_list const_decl
	|
	;

statement //nothing
	: compound_statement
	| simple_statement
	| conditional_statement
	| while_statement
	| for_statement
	| function_invoke_statement
	| jump_statement
	;

simple_statement
	: variable_reference ASSIGN_OP logical_expression SEMICOLON
	{
		// check if LHS exists
		__BOOLEAN flagLHS = verifyExistence( symbolTable, $1, scope, __TRUE );
		// id RHS is not dereferenced, check and deference
		__BOOLEAN flagRHS = __TRUE;
		if( $3->isDeref == __FALSE )
		{
			flagRHS = verifyExistence( symbolTable, $3, scope, __FALSE );
		}
		struct SymNode *ptr = lookupSymbol(symbolTable, $1->varRef->id, scope, __FALSE);
		if (ptr->scope == 0)
		{
			fprintf(output, "putstatic output/%s %c\n", ptr->name, typeCode(singleTypeTrans(ptr->type, $3->pType)));
		}
		else
		{
			fprintf(output, "%cstore %d\n", to_lowercase(typeCode(singleTypeTrans(ptr->type, $3->pType))), ptr->id);
		}
		// if both LHS and RHS are exists, verify their type
		if( flagLHS==__TRUE && flagRHS==__TRUE )
			verifyAssignmentTypeMatch( $1, $3 );
	}
	| PRINT
	{
		fprintf(output, "getstatic java/lang/System/out Ljava/io/PrintStream;\n");
	}
	logical_expression SEMICOLON
	{
		verifyScalarExpr( $3, "print" );
		char code = typeCode($3->pType->type);
		if (code == 'S')
			fprintf(output, "invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
		else
			fprintf(output, "invokevirtual java/io/PrintStream/print(%c)V\n", code);
	}
	| READ variable_reference SEMICOLON
	{
		if( verifyExistence( symbolTable, $2, scope, __TRUE ) == __TRUE )
			verifyScalarExpr( $2, "read" );
		fprintf(output, "getstatic output/_sc Ljava/util/Scanner;\n");
		switch ($2->pType->type) {
			case INTEGER_t:
				fprintf(output, "invokevirtual java/util/Scanner/nextInt()I\n");
				break;
			case BOOLEAN_t:
				fprintf(output, "invokevirtual java/util/Scanner/nextBoolean()Z\n");
				break;
			case DOUBLE_t:
				fprintf(output, "invokevirtual java/util/Scanner/nextDouble()D\n");
				break;
			case FLOAT_t:
				fprintf(output, "invokevirtual java/util/Scanner/nextFloat()F\n");
				break;
		}
		struct SymNode *ptr = lookupSymbol(symbolTable, $2->varRef->id, scope, __FALSE);
		if (ptr->scope == 0) {
			fprintf(output, "putstatic output/%s %c\n", ptr->name, typeCode(ptr->type->type));
		}
		else {
			fprintf(output, "%cstore %d\n", to_lowercase(typeCode($2->pType->type)), ptr->id);
		}
	}
	;

conditional_statement
	: IF L_PAREN conditional_if R_PAREN compound_statement
	{
		fprintf(output, "Lelse_%d:\n", label);
		fprintf(output, "Lexit_%d:\n", label);
		label = 0;
	}
	| IF L_PAREN conditional_if R_PAREN compound_statement
	{
		fprintf(output, "goto Lexit_%d\n", label);
		fprintf(output, "Lelse_%d:\n", label);
	}
	ELSE compound_statement
	{
	fprintf(output, "Lexit_%d:\n", label);
	label = 0;
	}
	;

conditional_if
	: logical_expression
	{
		label += true_false_label;
		verifyBooleanExpr( $1, "if" );
		fprintf(output, "ifeq Lelse_%d\n", label);
	}
	;

while_statement
	: WHILE L_PAREN
	{
		fprintf(output, "Lbegin_%d:\n", loop);
	}
	logical_expression
	{
		verifyBooleanExpr( $4, "while" );
		fprintf(output, "ifeq Lexit_%d\n", loop);
	}
	R_PAREN
	{
		inloop++;
	}
	compound_statement
	{
		inloop--;
		fprintf(output, "goto Lbegin_%d\n", loop);
		fprintf(output, "Lexit_%d:\n", loop);
		if (inloop == 0) loop++;
	}
	|
	{
		inloop++;
	}
	DO compound_statement WHILE L_PAREN logical_expression R_PAREN SEMICOLON
	{
		verifyBooleanExpr( $6, "while" );
		inloop--;
	}
	;

for_statement
	: FOR L_PAREN initial_expression SEMICOLON
	{
		fprintf(output, "Lctrl%d:\n", loop);
	}
	control_expression SEMICOLON
	{
		fprintf(output, "ifne Lstmt%d\n", loop);
		fprintf(output, "goto Lexit%d\n", loop);
		fprintf(output, "Linc%d:\n", loop);
	}
	increment_expression
	{
		fprintf(output, "goto Lctrl%d\n", loop);
	}
	R_PAREN {
		fprintf(output, "Lstmt%d:\n", loop);
		inloop++;
	}
	compound_statement
	{
		inloop--;
		fprintf(output, "goto Linc%d\n", loop);
		fprintf(output, "Lexit%d:\n", loop);
		if (inloop == 0) loop++;
	}
	;

initial_expression //nothing
	: initial_expression COMMA statement_for
	| initial_expression COMMA logical_expression
	| logical_expression
	| statement_for
	|
	;

control_expression //nothing
	: control_expression COMMA statement_for
	{
		fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
		semError = __TRUE;
	}
	| control_expression COMMA logical_expression
	{
		if( $3->pType->type != BOOLEAN_t ){
			fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
			semError = __TRUE;
		}
	}
	| logical_expression
	{
		if( $1->pType->type != BOOLEAN_t ){
			fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
			semError = __TRUE;
		}
	}
	| statement_for
		{
		fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
		semError = __TRUE;
		}
	|
	;

increment_expression //nothing
	: increment_expression COMMA statement_for
	| increment_expression COMMA logical_expression
	| logical_expression
	| statement_for
	|
	;

statement_for
	: variable_reference ASSIGN_OP logical_expression
	{
		// check if LHS exists
		__BOOLEAN flagLHS = verifyExistence( symbolTable, $1, scope, __TRUE );
		// id RHS is not dereferenced, check and deference
		__BOOLEAN flagRHS = __TRUE;
		if( $3->isDeref == __FALSE ) {
			flagRHS = verifyExistence( symbolTable, $3, scope, __FALSE );
		}
		struct SymNode *ptr = lookupSymbol(symbolTable, $1->varRef->id, scope, __FALSE);
		if (ptr->scope == 0) {
			fprintf(output, "putstatic output/%s %c\n", ptr->name, typeCode(singleTypeTrans(ptr->type, $3->pType)));
		}
		else {
			fprintf(output, "%cstore %d\n", to_lowercase(typeCode(singleTypeTrans(ptr->type, $3->pType))), ptr->id);
		}
		// if both LHS and RHS are exists, verify their type
		if( flagLHS==__TRUE && flagRHS==__TRUE )
			verifyAssignmentTypeMatch( $1, $3 );
	}
	;


function_invoke_statement
	: ID L_PAREN logical_expression_list R_PAREN SEMICOLON
	{
		verifyFuncInvoke( $1, $3, symbolTable, scope );
		struct SymNode *ptr = lookupSymbol(symbolTable, $1, scope, __FALSE);
		fprintf(output, "invokestatic output/%s(", $1);
		struct PTypeList *params = ptr->attribute->formalParam->params;
		struct expr_sem *list = $3;
		while (list != NULL) {
			fprintf(output, "%c", typeCode(singleTypeTrans(params->value, list->pType)));
			params = params->next;
			list = list->next;
		}
		fprintf(output, ")%c\n", typeCode(ptr->type->type));
	}
	| ID L_PAREN R_PAREN SEMICOLON
	{
		verifyFuncInvoke( $1, 0, symbolTable, scope );
		struct SymNode *ptr = lookupSymbol(symbolTable, $1, scope, __FALSE);
		fprintf(output, "invokestatic output/%s()%c\n", $1, typeCode(ptr->type->type));
	}
	;

jump_statement
	: CONTINUE SEMICOLON
	{
		if( inloop <= 0){
			fprintf( stdout, "########## Error at Line#%d: continue can't appear outside of loop ##########\n", linenum ); semError = __TRUE;
		}
	}
	| BREAK SEMICOLON
	{
		if( inloop <= 0)
			fprintf( stdout, "########## Error at Line#%d: break can't appear outside of loop ##########\n", linenum ); semError = __TRUE;
	}
	| RETURN logical_expression SEMICOLON
	{
		verifyReturnStatement( $2, funcReturn );
		if (ismain)
		{
			fprintf(output, "return\n");
			isreturn = __TRUE;
		}
		else fprintf(output, "%creturn\n", to_lowercase(typeCode(singleTypeTrans(funcReturn, $2->pType))));
	}
	;

variable_reference //nothing
	: ID
	{
		$$ = createExprSem( $1 );
	}
	| variable_reference dimension
	{
		increaseDim( $1, $2 );
		$$ = $1;
	}
	;

dimension //nothing
	: ML_BRACE arithmetic_expression MR_BRACE
	{
		$$ = verifyArrayIndex( $2 );
	}
	;

logical_expression //nothing
	: logical_expression OR_OP logical_term
	{
		verifyAndOrOp( $1, OR_t, $3 );
		$$ = $1;
		fprintf(output, "ior\n");
	}
	| logical_term
	{
		$$ = $1;
	}
	;

logical_term
	: logical_term AND_OP logical_factor
	{
		verifyAndOrOp( $1, AND_t, $3 );
		$$ = $1;
		fprintf(output, "iand\n");
	}
	| logical_factor
	{
		$$ = $1;
	}
	;

logical_factor
	: NOT_OP logical_factor
	{
		verifyUnaryNot( $2 );
		$$ = $2;
		fprintf(output, "ixor\n");
	}
	| relation_expression
	{
		$$ = $1;
	}
	;

relation_expression
	: arithmetic_expression relation_operator arithmetic_expression
	{
		SEMTYPE type = typeTrans($1->pType, $3->pType);
		if (type == INTEGER_t)
			fprintf(output, "isub\n");
		else
			fprintf(output, "%ccmpl\n", to_lowercase(typeCode(type)));
		switch ($2)
		{
			case LT_t:
				fprintf(output, "iflt Ltrue_%d\n", true_false_label);
				break;
			case LE_t:
				fprintf(output, "ifle Ltrue_%d\n", true_false_label);
				break;
			case EQ_t:
				fprintf(output, "ifeq Ltrue_%d\n", true_false_label);
				break;
			case GE_t:
				fprintf(output, "ifge Ltrue_%d\n", true_false_label);
				break;
			case GT_t:
				fprintf(output, "ifgt Ltrue_%d\n", true_false_label);
				break;
			case NE_t:
				fprintf(output, "ifne Ltrue_%d\n", true_false_label);
				break;
		}
		fprintf(output, "iconst_0\n");
		fprintf(output, "goto Lfalse_%d\n", true_false_label);
		fprintf(output, "Ltrue_%d:\n", true_false_label);
		fprintf(output, "iconst_1\n");
		fprintf(output, "Lfalse_%d:\n", true_false_label);
		true_false_label += 1;
		verifyRelOp( $1, $2, $3 );
		$$ = $1;
	}
	| arithmetic_expression
	{
		$$ = $1;
	}
	;

relation_operator //nothing
	: LT_OP { $$ = LT_t; }
	| LE_OP { $$ = LE_t; }
	| EQ_OP { $$ = EQ_t; }
	| GE_OP { $$ = GE_t; }
	| GT_OP { $$ = GT_t; }
	| NE_OP { $$ = NE_t; }
	;

arithmetic_expression
	: arithmetic_expression add_op term
	{
		typeTrans($1->pType, $3->pType);
		verifyArithmeticOp( $1, $2, $3 );
		$$ = $1;
		fprintf(output, "%c%s\n", to_lowercase(typeCode($1->pType->type)), ($2==ADD_t ? "add" : "sub"));
	}
	| relation_expression { $$ = $1; }
	| term { $$ = $1; }
	;

add_op //nothing
	: ADD_OP { $$ = ADD_t; }
	| SUB_OP { $$ = SUB_t; }
	;

term
	: term mul_op factor
	{
		if( $2 == MOD_t ) {
			verifyModOp( $1, $3 );
			fprintf(output, "irem\n");
		}
		else {
			typeTrans($1->pType, $3->pType);
			verifyArithmeticOp( $1, $2, $3 );
			fprintf(output, "%c%s\n", to_lowercase(typeCode($1->pType->type)), ($2==MUL_t ? "mul" : "div"));
		}
		$$ = $1;
	}
	| factor { $$ = $1; }
	;

mul_op //nothing
	: MUL_OP { $$ = MUL_t; }
	| DIV_OP { $$ = DIV_t; }
	| MOD_OP { $$ = MOD_t; }
	;

factor
	: variable_reference
	{
		verifyExistence( symbolTable, $1, scope, __FALSE );
		$$ = $1;
		$$->beginningOp = NONE_t;
		struct SymNode *ptr = lookupSymbol(symbolTable, $1->varRef->id, scope, __FALSE);
		if (ptr->category == CONSTANT_t)
		{
			switch(ptr->type->type)
			{
				case INTEGER_t:
					fprintf(output, "ldc %d\n", ptr->attribute->constVal->value.integerVal);
					break;
				case FLOAT_t:
					fprintf(output, "ldc %f\n", ptr->attribute->constVal->value.floatVal);
					break;
				case DOUBLE_t:
					fprintf(output, "ldc %lf\n", ptr->attribute->constVal->value.doubleVal);
					break;
				case BOOLEAN_t:
					fprintf(output, "ldc %d\n", ptr->attribute->constVal->value.booleanVal);
					break;
				case STRING_t:
					fprintf(output, "ldc %s\n", ptr->attribute->constVal->value.stringVal);
					break;
			}
		}
		else if (ptr->scope == 0)
		{
			fprintf(output, "getstatic output/%s %c\n", ptr->name, typeCode(ptr->type->type));
		}
		else
		{
			fprintf(output, "%cload %d\n", to_lowercase(typeCode(ptr->type->type)), ptr->id);
		}
	}
	| SUB_OP variable_reference
	{
		if( verifyExistence( symbolTable, $2, scope, __FALSE ) == __TRUE )
		verifyUnaryMinus( $2 );
		$$ = $2;
		$$->beginningOp = SUB_t;
		struct SymNode *ptr = lookupSymbol(symbolTable, $2->varRef->id, scope, __FALSE);
		if (ptr->scope == 0)
		{
			fprintf(output, "getstatic output/%s %c\n", ptr->name, typeCode(ptr->type->type));
		}
		else
		{
			fprintf(output, "%cload %d\n", to_lowercase(typeCode(ptr->type->type)), ptr->id);
		}
		fprintf(output, "%cneg\n", to_lowercase(typeCode(ptr->type->type)));
	}
	| L_PAREN logical_expression R_PAREN
	{
		$2->beginningOp = NONE_t;
		$$ = $2;
	}
	| SUB_OP L_PAREN logical_expression R_PAREN
	{
		verifyUnaryMinus( $3 );
		$$ = $3;
		$$->beginningOp = SUB_t;
		fprintf(output, "%cneg\n", typeCode($3->pType->type));
	}
	| ID L_PAREN logical_expression_list R_PAREN
	{
		$$ = verifyFuncInvoke( $1, $3, symbolTable, scope );
		$$->beginningOp = NONE_t;
		struct SymNode *ptr = lookupSymbol(symbolTable, $1, scope, __FALSE);
		fprintf(output, "invokestatic output/%s(", $1);
		struct PTypeList *params = ptr->attribute->formalParam->params;
		struct expr_sem *list = $3;
		while (list != NULL) {
			fprintf(output, "%c", typeCode(singleTypeTrans(params->value, list->pType)));
			params = params->next;
			list = list->next;
		}
		fprintf(output, ")%c\n", typeCode(ptr->type->type));
	}
	| SUB_OP ID L_PAREN logical_expression_list R_PAREN
	{
		$$ = verifyFuncInvoke( $2, $4, symbolTable, scope );
		$$->beginningOp = SUB_t;
		struct SymNode *ptr = lookupSymbol(symbolTable, $2, scope, __FALSE);
		fprintf(output, "invokestatic output/%s(", $2);
		struct PTypeList *params = ptr->attribute->formalParam->params;
		struct expr_sem *list = $4;
		while (list != NULL) {
			fprintf(output, "%c", typeCode(singleTypeTrans(params->value, list->pType)));
			params = params->next;
			list = list->next;
		}
		fprintf(output, ")%c\n", typeCode(ptr->type->type));
		fprintf(output, "%cneg\n", typeCode(ptr->type->type));
	}
	| ID L_PAREN R_PAREN
	{
		$$ = verifyFuncInvoke( $1, 0, symbolTable, scope );
		$$->beginningOp = NONE_t;
		struct SymNode *ptr = lookupSymbol(symbolTable, $1, scope, __FALSE);
		fprintf(output, "invokestatic output/%s()%c\n", $1, typeCode(ptr->type->type));
	}
	| SUB_OP ID L_PAREN R_PAREN
	{
		$$ = verifyFuncInvoke( $2, 0, symbolTable, scope );
		$$->beginningOp = SUB_OP;
		struct SymNode *ptr = lookupSymbol(symbolTable, $2, scope, __FALSE);
		fprintf(output, "invokestatic output/%s()%c\n", $2, typeCode(ptr->type->type));
		fprintf(output, "%cneg\n", typeCode(ptr->type->type));
	}
	| literal_const
	{
		switch ($1->category)
		{
			case INTEGER_t:
				fprintf(output, "ldc %d\n", $1->value.integerVal);
				break;
			case FLOAT_t:
				fprintf(output, "ldc %f\n", $1->value.floatVal);
				break;
			case DOUBLE_t:
				fprintf(output, "ldc %lf\n", $1->value.doubleVal);
				break;
			case STRING_t:
				fprintf(output, "ldc \"%s\"\n", $1->value.stringVal);
				break;
			case BOOLEAN_t:
				fprintf(output, "%s\n", $1->value.booleanVal == __TRUE ? "iconst_1" : "iconst_0");
				break;
		}
		$$ = (struct expr_sem *)malloc(sizeof(struct expr_sem));
		$$->isDeref = __TRUE;
		$$->varRef = 0;
		$$->pType = createPType( $1->category );
		$$->next = 0;
		if( $1->hasMinus == __TRUE ) {
			$$->beginningOp = SUB_t;
		}
		else {
		$$->beginningOp = NONE_t;
		}
	}
	;

logical_expression_list //nothing
	: logical_expression_list COMMA logical_expression
	{
		struct expr_sem *exprPtr;
		for( exprPtr=$1 ; (exprPtr->next)!=0 ; exprPtr=(exprPtr->next) );
		exprPtr->next = $3;
		$$ = $1;
	}
	| logical_expression { $$ = $1; }
	;

scalar_type //nothing
	: INT { $$ = createPType( INTEGER_t ); }
	| DOUBLE { $$ = createPType( DOUBLE_t ); }
	| STRING { $$ = createPType( STRING_t ); }
	| BOOL { $$ = createPType( BOOLEAN_t ); }
	| FLOAT { $$ = createPType( FLOAT_t ); }
	;

literal_const //nothing
	: INT_CONST
	{
		int tmp = $1;
		$$ = createConstAttr( INTEGER_t, &tmp );
	}
	| SUB_OP INT_CONST
	{
		int tmp = -$2;
		$$ = createConstAttr( INTEGER_t, &tmp );
	}
	| FLOAT_CONST
	{
		float tmp = $1;
		$$ = createConstAttr( FLOAT_t, &tmp );
	}
	| SUB_OP FLOAT_CONST
	{
		float tmp = -$2;
		$$ = createConstAttr( FLOAT_t, &tmp );
	}
	| SCIENTIFIC
	{
		double tmp = $1;
		$$ = createConstAttr( DOUBLE_t, &tmp );
	}
	| SUB_OP SCIENTIFIC
	{
		double tmp = -$2;
		$$ = createConstAttr( DOUBLE_t, &tmp );
	}
	| STR_CONST
	{
		$$ = createConstAttr( STRING_t, $1 );
	}
	| TRUE
	{
		SEMTYPE tmp = __TRUE;
		$$ = createConstAttr( BOOLEAN_t, &tmp );
	}
	| FALSE
	{
		SEMTYPE tmp = __FALSE;
		$$ = createConstAttr( BOOLEAN_t, &tmp );
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


char to_lowercase(char c)
{
	switch (c)
	{
		case 'I': return 'i';
		case 'Z': return 'i';
		case 'D': return 'd';
		case 'F': return 'f';
	}
}

char typeCode(SEMTYPE type)
{
	switch (type)
	{
		case INTEGER_t: return 'I';
		case BOOLEAN_t: return 'Z';
		case DOUBLE_t: return 'D';
		case FLOAT_t: return 'F';
		case STRING_t: return 'S';
		case VOID_t: return 'V';
	}
}

SEMTYPE typeTrans(struct PType *lhs, struct PType *rhs)
{
	if (lhs->type == rhs->type) return lhs->type;
	if (lhs->type == INTEGER_t)
	{
		if (rhs->type == FLOAT_t)
		{
			fprintf(output, "swap\ni2f\nswap\n");
			return FLOAT_t;
		}
		else if (rhs->type == DOUBLE_t)
		{
			fprintf(output, "swap\ni2d\nswap\n");
			return DOUBLE_t;
		}
	}
	else if (lhs->type == FLOAT_t)
	{
		if (rhs->type == INTEGER_t)
		{
			fprintf(output, "i2f\n");
			return FLOAT_t;
		}
		else if (rhs->type == DOUBLE_t)
		{
			fprintf(output, "swap\nf2d\nswap\n");
			return DOUBLE_t;
		}
	}
	else if (lhs->type == DOUBLE_t)
	{
		if (rhs->type == INTEGER_t)
		{
			fprintf(output, "i2d\n");
			return DOUBLE_t;
		}
		else if (rhs->type == FLOAT_t)
		{
			fprintf(output, "f2d\n");
			return DOUBLE_t;
		}
	}
}

SEMTYPE singleTypeTrans(struct PType *lhs, struct PType *rhs)
{
	if (lhs->type == rhs->type) return lhs->type;
	if (lhs->type == FLOAT_t)
	{
		if (rhs->type == INTEGER_t)
		{
			fprintf(output, "i2f\n");
			return FLOAT_t;
		}
	}
	else if (lhs->type == DOUBLE_t)
	{
		if (rhs->type == INTEGER_t)
		{
			fprintf(output, "i2d\n");
			return DOUBLE_t;
		}
		else if (rhs->type == FLOAT_t)
		{
			fprintf(output, "f2d\n");
			return DOUBLE_t;
		}
	}
}
