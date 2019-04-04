#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef enum {
	error_k,
	program_k,
	decl_and_def_list_k,
	decl_list_k, funct_def_k, funct_decl_k,
	var_decl_k, const_decl_k,
	scalar_type_k, identifier_list_k,
	const_list_k, literal_const_k,
	array_decl_k, dim_k,
	parameter_list_k,
	variable_reference_k,
	dimension_k, array_list_k,
	compound_statement_k,
	statement_k,
	simple_statement_k,
	var_const_stmt_list_k,
	while_statement_k, for_statement_k, conditional_statement_k,
	initial_expression_list_k, initial_expression_k,
	control_expression_list_k, control_expression_k,
	increment_expression_list_k, increment_expression_k,
	logical_term_k,
	relation_expression_k, relation_operator_k, equality_operator_k,
	jump_statement_k,
	logical_expression_list_k,
	literal_list_k,
	return_k
}KIND;

typedef enum {
	null_t, int_t, double_t, string_t, bool_t, float_t, void_t, array_t
}TYPE;

typedef union {
	int i;
	double d;
	char* s;
}VALUE;

struct NODE;
struct NODE {
	char *name;
	KIND kind;
	int level;
	TYPE type;
	char *attribute;
	struct NODE *in_list;
	struct NODE *children[16];
	int child_num;
	int array_num;
	VALUE value;
};

char* choose_kind(KIND kind);
char* choose_type(TYPE type);
//symbol table
struct NODE* create_node(char *name, KIND kind, int level, TYPE type, char *attribute, struct NODE* in_list, int child_num);
void insert_table(struct NODE* node);
struct NODE* find_name(char *name);
void print_table(int n);
void add_in_list(struct NODE *a, struct NODE *b);
//check!!!!
void funct_def_check(struct NODE* n);
void return_check(struct NODE* n);
void no_return_check(struct NODE* n);
void arithmetic_check(struct NODE *a, struct NODE *b);
void mod_check(struct NODE *a, struct NODE *b);
void logical_check(struct NODE *a, struct NODE *b);
void relation_check(struct NODE *a, struct NODE *o, struct NODE *b);
int type_check(struct NODE *a, struct NODE *b);
//error message
void error_msg(int line, char *msg);