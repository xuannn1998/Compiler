%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int linenum;
extern FILE *yyin;
extern char *yytext;
extern char buf[256];

extern int Opt_Symbol;
extern int level;

int yylex();
int yyerror( char *msg );

char *kind_parameter = "parameter";
char *kind_function = "function";
char *kind_variable = "variable";
char *kind_constant = "constant";

struct symboltable{
    char* name;
    char* kind;
    int level;
    char* type;
    struct parameter_list *parameter_node; //parameter
    char* value; //const
    struct dim_list *dim_node; //dimension
    int line;
    struct symboltable *next;
};

struct symboltable *table_head = NULL;

struct id_list{
    char* id_name;
    struct dim_list *dim_node;
    struct id_list *next;
};

struct id_list *head = NULL;

struct const_list{
    char* const_name;
    char* const_value;
    struct const_list *next;
};

struct const_list *const_head = NULL;

struct dim_list{
    char* dim_num;
    struct dim_list *next;
};

struct dim_list *dim_head = NULL;

struct parameter_list{
    char* parameter_type;
    char* parameter_name;
    struct dim_list *dim_node;
    struct parameter_list *next;
};

struct parameter_list *parameter_head = NULL;

void insert_id(char* id_name, struct dim_list *dim);
void insert_table(char* name, char* kind, int level, char* type, int line, char* value, struct dim_list *dim_node, struct parameter_list *parameter_node);
void pop_table(int level);
void print_table(int level);
void insert_const(char* const_name, char* const_value);
void insert_dim(char* dim_num);
void insert_parameter(char* parameter_type, char* parameter_name, struct dim_list *dim_node);

%}

%token ID
%token INT_CONST
%token FLOAT_CONST
%token SCIENTIFIC
%token STR_CONST

%token LE_OP NE_OP GE_OP EQ_OP AND_OP OR_OP

%token READ BOOLEAN WHILE DO IF ELSE TRUE FALSE FOR INT PRINT BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN CONST

%token L_PAREN R_PAREN COMMA SEMICOLON ML_BRACE MR_BRACE L_BRACE R_BRACE ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP ASSIGN_OP LT_OP GT_OP NOT_OP

%union {
    char* text_t;
}

%type <text_t> array_decl
%type <text_t> ID
%type <text_t> scalar_type
%type <text_t> INT
%type <text_t> FLOAT
%type <text_t> BOOL
%type <text_t> STRING
%type <text_t> DOUBLE
%type <text_t> VOID
%type <text_t> CONST
%type <text_t> literal_const
%type <text_t> INT_CONST
%type <text_t> FLOAT_CONST
%type <text_t> SCIENTIFIC
%type <text_t> STR_CONST
%type <text_t> TRUE
%type <text_t> FALSE
%type <text_t> dim

%start program
%%

program
    : decl_list funct_def decl_and_def_list 
    {
        if(Opt_Symbol) print_table(-1);
        pop_table(-1);
    }
    ;

decl_list 
    : decl_list var_decl
    | decl_list const_decl
    | decl_list funct_decl
    |
    ;

decl_and_def_list 
    : decl_and_def_list var_decl
    | decl_and_def_list const_decl
    | decl_and_def_list funct_decl
    | decl_and_def_list funct_def
    | 
    ;

funct_def 
    : scalar_type ID L_PAREN R_PAREN compound_statement
    {
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, NULL);
    }
    | scalar_type ID L_PAREN parameter_list R_PAREN  compound_statement
    {
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, parameter_head);
        parameter_head = NULL;
    }
    | VOID ID L_PAREN R_PAREN compound_statement
    {
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, NULL);
    }
    | VOID ID L_PAREN parameter_list R_PAREN compound_statement
    {
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, parameter_head);
        parameter_head = NULL;
    }
    ;

funct_decl 
    : scalar_type ID L_PAREN R_PAREN SEMICOLON
    { 
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, NULL);
    }
    | scalar_type ID L_PAREN parameter_list R_PAREN SEMICOLON
    {
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, parameter_head); 
        parameter_head = NULL;
        pop_table(level);
    }
    | VOID ID L_PAREN R_PAREN SEMICOLON
    {
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, NULL);
    }
    | VOID ID L_PAREN parameter_list R_PAREN SEMICOLON
    {
        insert_table($2, kind_function, level, $1, linenum, NULL, NULL, parameter_head);
        parameter_head = NULL;
        pop_table(level);
    }
    ;

parameter_list 
    : parameter_list COMMA scalar_type ID 
    {
        insert_parameter($3, $4, NULL); 
        insert_table($4, kind_parameter, level+1, $3, linenum, NULL, NULL, NULL);
    }
    | parameter_list COMMA scalar_type array_decl 
    {
        insert_parameter($3, $4, dim_head);
        insert_table($4, kind_parameter, level+1, $3, linenum, NULL, dim_head, NULL);
        dim_head = NULL;
    }
    | scalar_type array_decl
    {
        insert_parameter($1, $2, dim_head);
        insert_table($2, kind_parameter, level+1, $1, linenum, NULL, dim_head, NULL);
        dim_head = NULL;
    }
    | scalar_type ID
    {
        insert_parameter($1, $2, NULL);
        insert_table($2, kind_parameter, level+1, $1, linenum, NULL, NULL, NULL);
    } 
    ;

var_decl 
    : scalar_type identifier_list SEMICOLON 
    {
        struct id_list *node = head;
        while(node != NULL)
        {
            insert_table(node->id_name, kind_variable, level, $1, linenum, NULL, node->dim_node, NULL);
            node = node->next;
        }
        head = NULL;
    }
    ;

identifier_list 
    : identifier_list COMMA ID {insert_id($3, NULL);}
    | identifier_list COMMA ID ASSIGN_OP logical_expression {insert_id($3, NULL);}
    | identifier_list COMMA array_decl ASSIGN_OP initial_array {insert_id($3, dim_head); dim_head = NULL;}
    | identifier_list COMMA array_decl {insert_id($3, dim_head); dim_head = NULL;}
    | array_decl ASSIGN_OP initial_array {insert_id($1, dim_head); dim_head = NULL;}
    | array_decl {insert_id($1, dim_head); dim_head = NULL;}
    | ID ASSIGN_OP logical_expression {insert_id($1, NULL);}
    | ID {insert_id($1, NULL);}
    ;

initial_array 
    : L_BRACE literal_list R_BRACE
    ;

literal_list 
    : literal_list COMMA logical_expression
    | logical_expression
    | 
    ;

const_decl 
    : CONST scalar_type const_list SEMICOLON
    {
        struct const_list *node = const_head;
        while(node != NULL)
        {
            insert_table(node->const_name, kind_constant, level, $2, linenum, node->const_value, NULL, NULL);
            node = node->next;
        }
        const_head = NULL;
    }
    ;

const_list 
    : const_list COMMA ID ASSIGN_OP literal_const {insert_const($3, $5);}
    | ID ASSIGN_OP literal_const {insert_const($1, $3);}
    ;

array_decl 
    : ID dim {$$ = $1;}
    ;

dim 
    : dim ML_BRACE INT_CONST MR_BRACE {insert_dim($3);}
    | ML_BRACE INT_CONST MR_BRACE {insert_dim($2);}
    ;

compound_statement 
    : L_BRACE var_const_stmt_list R_BRACE
    { 
        if(Opt_Symbol) print_table(level);
        pop_table(level);
    }
    ;

var_const_stmt_list 
    : var_const_stmt_list statement 
    | var_const_stmt_list var_decl
    | var_const_stmt_list const_decl
    |
    ;

statement 
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
    | PRINT logical_expression SEMICOLON
    | READ variable_reference SEMICOLON
    ;

conditional_statement 
    : IF L_PAREN logical_expression R_PAREN compound_statement
    | IF L_PAREN logical_expression R_PAREN compound_statement ELSE compound_statement
    ;

while_statement 
    : WHILE L_PAREN logical_expression R_PAREN compound_statement
    | DO compound_statement WHILE L_PAREN logical_expression R_PAREN SEMICOLON
    ;

for_statement 
    : FOR L_PAREN initial_expression_list SEMICOLON control_expression_list SEMICOLON increment_expression_list R_PAREN compound_statement
    ; 

initial_expression_list 
    : initial_expression
    |
    ;

initial_expression 
    : initial_expression COMMA variable_reference ASSIGN_OP logical_expression
    | initial_expression COMMA logical_expression
    | logical_expression
    | variable_reference ASSIGN_OP logical_expression

control_expression_list 
    : control_expression
    |
    ;

control_expression 
    : control_expression COMMA variable_reference ASSIGN_OP logical_expression
    | control_expression COMMA logical_expression
    | logical_expression
    | variable_reference ASSIGN_OP logical_expression
    ;

increment_expression_list 
    : increment_expression 
    |
    ;

increment_expression 
    : increment_expression COMMA variable_reference ASSIGN_OP logical_expression
    | increment_expression COMMA logical_expression
    | logical_expression
    | variable_reference ASSIGN_OP logical_expression
    ;

function_invoke_statement 
    : ID L_PAREN logical_expression_list R_PAREN SEMICOLON
    | ID L_PAREN R_PAREN SEMICOLON
    ;

jump_statement 
    : CONTINUE SEMICOLON
    | BREAK SEMICOLON
    | RETURN logical_expression SEMICOLON
    ;

variable_reference 
    : array_list
    | ID
    ;


logical_expression 
    : logical_expression OR_OP logical_term
    | logical_term
    ;

logical_term 
    : logical_term AND_OP logical_factor
    | logical_factor
    ;

logical_factor 
    : NOT_OP logical_factor
    | relation_expression
    ;

relation_expression 
    : relation_expression relation_operator arithmetic_expression
    | arithmetic_expression
    ;

relation_operator 
    : LT_OP
    | LE_OP
    | EQ_OP
    | GE_OP
    | GT_OP
    | NE_OP
    ;

arithmetic_expression 
    : arithmetic_expression ADD_OP term
    | arithmetic_expression SUB_OP term
    | term
    ;

term 
    : term MUL_OP factor
    | term DIV_OP factor
    | term MOD_OP factor
    | factor
    ;

factor 
    : SUB_OP factor
    | literal_const
    | variable_reference
    | L_PAREN logical_expression R_PAREN
    | ID L_PAREN logical_expression_list R_PAREN
    | ID L_PAREN R_PAREN
    ;

logical_expression_list 
    : logical_expression_list COMMA logical_expression
    | logical_expression
    ;

array_list 
    : ID dimension
    ;

dimension 
    : dimension ML_BRACE logical_expression MR_BRACE         
    | ML_BRACE logical_expression MR_BRACE
    ;

scalar_type 
    : INT 
    | DOUBLE
    | STRING
    | BOOL
    | FLOAT
    ;
 
literal_const 
    : INT_CONST
    | FLOAT_CONST
    | SCIENTIFIC
    | STR_CONST
    | TRUE
    | FALSE
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
    //  fprintf( stderr, "%s\t%d\t%s\t%s\n", "Error found in Line ", linenum, "next token: ", yytext );
}

void insert_id(char* id_name, struct dim_list *dim)
{
    struct id_list *node = malloc(sizeof(struct id_list));
    node->id_name = id_name;
    node->dim_node = dim;
    node->next = NULL;
    if(head == NULL) head = node;
    else
    {
        struct id_list *tmp = head;
        while(tmp->next != NULL)
        {
            tmp = tmp->next;
        }
        tmp->next = node;
    }
}

void insert_const(char* const_name, char* const_value)
{
    struct const_list *node = malloc(sizeof(struct const_list));
    node->const_name = const_name;
    node->const_value = const_value;
    node->next = NULL;
    if(const_head == NULL) const_head = node;
    else
    {
        struct const_list *tmp = const_head;
        while(tmp->next != NULL)
        {
            tmp = tmp->next;
        }
        tmp->next = node;
    }
}

void insert_dim(char* dim_num)
{
    struct dim_list *node = malloc(sizeof(struct dim_list));
    node->dim_num = dim_num;
    node->next = NULL;
    if(dim_head == NULL) dim_head = node;
    else
    {
        struct dim_list *tmp = dim_head;
        while(tmp->next != NULL)
        {
            tmp = tmp->next;
        }
        tmp->next = node;
    }
}

void insert_parameter(char* parameter_type, char* parameter_name, struct dim_list *dim_node)
{
    struct parameter_list *node = malloc(sizeof(struct parameter_list));
    node->parameter_name = parameter_name;
    node->parameter_type = parameter_type;
    node->dim_node = dim_node;
    node->next = NULL;
    if(parameter_head == NULL) parameter_head = node;
    else
    {
        struct parameter_list *tmp = parameter_head;
        while(tmp->next != NULL)
        {
            tmp = tmp->next;
        }
        tmp->next = node;
    }
}

void insert_table(char* name, char* kind, int level, char* type, int line, char* value, struct dim_list *dim_node, struct parameter_list *parameter_node)
{
    struct symboltable *node = malloc(sizeof(struct symboltable));
    node->name = strndup(name, 32);
    node->kind = kind;
    node->level = level;
    node->type = type;
    node->line = line;
    node->value = value;
    node->dim_node = dim_node;
    node->parameter_node = parameter_node;
    node->next = NULL;
    struct symboltable *node_ = table_head;
    while(node_ != NULL)
    {
        if(node_->level == node->level && strncmp(node_->name, node->name, 32) == 0)
        {
            if(kind != kind_function)
                printf("##########Error at Line #%d: %s redeclared.##########\n", linenum, name);
            return;
        }
        node_ = node_->next;
    }
    if(table_head==NULL) table_head = node;
    else
    {
        struct symboltable *tmp = table_head;
        while(tmp->next != NULL)
        {
            tmp = tmp->next;
        }
        tmp->next = node;
    }
}

void print_table(int level)
{                             
    printf("======================================================================================\n");
    printf("Name                             Kind       Level       Type               Attribute  \n");
    printf("--------------------------------------------------------------------------------------\n");
    struct symboltable *node_ = table_head;
    struct symboltable *pre_node = NULL;

    while(node_ != NULL)
    {
        if(node_->level == level+1)
        {
            char* s = malloc(16);
            sprintf(s, "%d", node_->level);
            if(node_->level == 0) strcat(s, "(global)");
            else strcat(s, "(local)");
            printf("%-33s%-11s%-12s", node_->name, node_->kind, s);
            if(node_->value != NULL)
            {
                printf("%-19s%s", node_->type, node_->value);
                //printf("%s", node_->value);
            }
            else if(node_->dim_node != NULL)
            {
                struct dim_list *node = node_->dim_node;
                char* type = strdup(node_->type);
                while(node != NULL)
                {
                    type = realloc(type, strlen(type)+strlen(node->dim_num)+2);
                    strcat(type, "[");
                    strcat(type, node->dim_num);
                    strcat(type, "]");
                    node = node->next;
                }
                printf("%-19s", type);
            }
            else if(node_->parameter_node != NULL)
            {
                printf("%-19s", node_->type);
                struct parameter_list *node2 = node_->parameter_node;
                while(node2 != NULL)
                {
                    printf("%s", node2->parameter_type);
                    if(node2->dim_node != NULL)
                    {
                        struct dim_list *dim_node2 = node2->dim_node;
                        while(dim_node2 != NULL)
                        {
                            printf("[%s]", dim_node2->dim_num);
                            dim_node2 = dim_node2->next;
                        }
                    }
                    node2 = node2->next;
                    if(node2 != NULL) printf(",");
                }
            }
            else printf("%-19s", node_->type);
            printf("\n");
        }
        node_ = node_->next;
    }
    printf("======================================================================================\n");
}

void pop_table(int level)
{
    struct symboltable *node_ = table_head;
    struct symboltable *pre_node = NULL;

    while(node_ != NULL)
    {
        if(node_->level == level+1)
        {
            if(node_ == table_head) table_head = node_->next;
            else pre_node->next = node_->next;
        }
        else pre_node = node_;
        node_ = node_->next;
    }
}
