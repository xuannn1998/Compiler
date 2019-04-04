#include "0516022.h"

int top;
extern int error_num;
extern int Opt_Symbol;
extern int linenum;
struct NODE *symboltable[1024];

char *choose_kind(KIND kind)
{
	switch (kind)
	{
	case identifier_list_k:
		return "variable";
	case const_list_k:
		return "constant";
	case array_decl_k:
		return "variable";
	case funct_def_k:
		return "function";
	case parameter_list_k:
		return "parameter";
	default:
		return "not def";
	}
}

char *choose_type(TYPE type)
{
	switch (type)
	{
	case int_t:
		return "int";
	case double_t:
		return "double";
	case string_t:
		return "string";
	case bool_t:
		return "bool";
	case float_t:
		return "float";
	case void_t:
		return "void";
	default:
		return "not def";
	}
}

struct NODE* create_node(char* name, KIND kind, int level, TYPE type, char *attribute, struct NODE* in_list, int child_num) {
	struct NODE *node = (struct NODE*)malloc(sizeof(struct NODE));
	node->name = strdup(name);
	node->kind = kind;
	node->level = level;
	node->type = type;
	node->attribute = strdup(attribute);
	node->in_list = in_list;
	node->child_num = child_num;
	return node;
}

void insert_table(struct NODE* node) {
	struct NODE *tmp = find_name(node->name);
	char tmp_buf[128];
	if (tmp != NULL && tmp->level == node->level) {
		sprintf(tmp_buf, "redeclaration of '%s'.", node->name);
		error_msg(linenum, tmp_buf);
	}
	else symboltable[top++] = node;
}

struct NODE* find_name(char *name) {
	for (int i = top - 1; i >= 0; i--) {
		if (strcmp(symboltable[i]->name, name) == 0) return symboltable[i];
	}
	return NULL;
}

void print_table(int n) {
	if (Opt_Symbol) {
		fflush(stdout);
		printf("======================================================================================\n");
		printf("Name                             Kind       Level       Type               Attribute  \n");
		printf("--------------------------------------------------------------------------------------\n");
		int tmp = -1;
		for (int i = 0; i < top; i++) {
			if (symboltable[i]->level > n) {
				printf("%-33s", symboltable[i]->name);
				printf("%-11s", choose_kind(symboltable[i]->kind));
				printf("%-2d%-10s", symboltable[i]->level, symboltable[i]->level ? "(local)" : "(global)");
				if (symboltable[i]->type != array_t)
					printf("%-19s", choose_type(symboltable[i]->type));
				printf("%-24s", symboltable[i]->attribute);
				printf("\n");
			}
			else tmp = i;

		}
		printf("======================================================================================\n");
		top = tmp + 1;

	}
	else {
		int tmp = -1;
		for (int i = 0; i < top; i++) {
			if (symboltable[i]->level <= n) tmp = i;
			else break;
		}
		top = tmp + 1;
	}
}

void add_in_list(struct NODE *a, struct NODE *b) {
	while (a->in_list != NULL) a = a->in_list;
	a->in_list = b;
}

void funct_def_check(struct NODE* n) {
	struct NODE *node;
	char tmp_buf[128];
	int count = 0;
	for (int i = top - 1; i >= 0; i--) {
		if (symboltable[i]->level != 0) count++;
		else break;
	}
	top -= count;
	if ((node = find_name(n->name)) == NULL)
		insert_table(n);
	else {
		if (node->kind == funct_def_k) {
			sprintf(tmp_buf, "redefinition of function '%s'.", n->name);
			error_msg(linenum, tmp_buf);
		}
		else if (node->kind == funct_decl_k) {
			if (node->type != n->type) {
				sprintf(tmp_buf, "different return type between function '%s' def and decl.", n->name);
				error_msg(linenum, tmp_buf);
			}
			if (strcmp(node->attribute, n->attribute) != 0) {
				sprintf(tmp_buf, "parameters' types are wrong for function '%s'.", n->name);
				error_msg(linenum, tmp_buf);
			}
		}
		else {
			sprintf(tmp_buf, "'%s' is redeclared as different kind of symbol.", n->name);
			error_msg(linenum, tmp_buf);
		}
	}
}

void return_check(struct NODE* n) {
	struct NODE *node;
	char tmp_buf[128];
	node = n->children[1]->children[0];
	while (node->in_list != NULL) {
		if (node->kind == return_k && node->type != n->type) {
			sprintf(tmp_buf, "type of return value of function '%s' mismatch.", n->name);
			error_msg(linenum, tmp_buf);
		}
		node = node->in_list;
	}
	if (node->kind != return_k) {
		sprintf(tmp_buf, "function '%s' has no return at last line.", n->name);
		error_msg(linenum, tmp_buf);
	}
	else if (node->type != n->type) {
		sprintf(tmp_buf, "type of return value of function '%s' mismatch.", n->name);
		error_msg(linenum, tmp_buf);
	}
}

void no_return_check(struct NODE* n) {
	struct NODE *node;
	char tmp_buf[128];
	node = n->children[1]->children[0]->in_list;
	while (node != NULL) {
		if (node->kind == return_k) {
			error_msg(linenum, "this is void function, no return value");
		}
		node = node->in_list;
	}
}

void arithmetic_check(struct NODE *a, struct NODE *b) {
	char tmp_buf[128];
	if (a->type != int_t && a->type != float_t && a->type != double_t) {
		sprintf(tmp_buf, "'%s' type error in arithmetic calculation.", a->name);
		error_msg(linenum, tmp_buf);
	}
	if (b->type != int_t && b->type != float_t && b->type != double_t) {
		sprintf(tmp_buf, "'%s' type error in arithmetic calculation.", b->name);
		error_msg(linenum, tmp_buf);
	}
	if (a->type != b->type) {
		error_msg(linenum, "arithmetic type error.");
	}
}

void mod_check(struct NODE *a, struct NODE *b) {
	char tmp_buf[128];
	if (a->type != int_t) {
		sprintf(tmp_buf, "'%s' type error in mod calculation.", a->name);
		error_msg(linenum, tmp_buf);
	}
	if (b->type != int_t) {
		sprintf(tmp_buf, "'%s' type error in mod calculation.", b->name);
		error_msg(linenum, tmp_buf);
	}
}

void logical_check(struct NODE *a, struct NODE *b) {
	char tmp_buf[128];
	if (a->type != bool_t) {
		sprintf(tmp_buf, "'%s' type error in logical operation.", a->name);
		error_msg(linenum, tmp_buf);
	}
	if (b->type != bool_t) {
		sprintf(tmp_buf, "'%s' type error in logical operation.", b->name);
		error_msg(linenum, tmp_buf);
	}
}

void relation_check(struct NODE *a, struct NODE *o, struct NODE *b) {
	char tmp_buf[128];
	if (a->type != int_t && a->type != float_t && a->type != double_t) {
		if (o->kind != equality_operator_k || a->type != bool_t) {
			sprintf(tmp_buf, "'%s' type error in relation operation.", a->name);
			error_msg(linenum, tmp_buf);
		}
	}
	if (b->type != int_t && b->type != float_t && b->type != double_t) {
		if (o->kind != equality_operator_k || a->type != bool_t) {
			sprintf(tmp_buf, "'%s' type error in relation operation.", b->name);
			error_msg(linenum, tmp_buf);
		}
	}
}

int type_check(struct NODE *a, struct NODE *b) {
	if (a->type == b->type) return 1;
	if ((a->type == double_t || a->type == float_t) && (b->type == float_t || b->type == int_t)) return 1;
	return 0;
}

void error_msg(int line, char *msg)
{
	printf("########## Error at Line %d: %s ##########\n", line, msg);
	error_num++;
}