%{
#define LIST                { strncat(buf, yytext, sizeof(buf) - strlen(buf) - 1); }
#define token(t)            { LIST; if (Opt_Token) printf("<%s>\n", #t); }
#define tokenString(t, s)   { LIST; if (Opt_Token) printf("<%s:%s>\n", t, s); }
#define MAX_LINE_LENGTH 257
#define MAX_ID_LENGTH 257
#define ID_TABLE_SIZE 1000

int Opt_Source = 1;
int Opt_Token = 1;
int Opt_Statistic = 1;
int linenum = 1;
char buf[MAX_LINE_LENGTH];
char str_buf[MAX_LINE_LENGTH];
int id_count = 1;

struct id_node{
    char name[MAX_ID_LENGTH];
    int counter;
} id_table[ID_TABLE_SIZE];

int check_idtable(char *idname);
void insert_idtable(char *idname, int id_offset);
void print_idtable();
%}

digit         [0-9]
letter        [_a-zA-Z]
delimiter     (,|;|\(|\)|\[|\]|\{|\})
keyword       ("while"|"do"|"if"|"else"|"true"|"false"|"for"|"int"|"print"|"const"|"read"|"boolean"|"bool"|"void"|"float"|"double"|"string"|"continue"|"break"|"return")
id            {letter}({letter}|{digit})*
integer       0|[1-9]{digit}*
float         {digit}+\.{digit}+  
scientific    ({integer}|{float})[eE][\+\-]?{digit}+
whitespace    [ \t]+

%x PRAGMA
%x PRAGMA_COMMENT
%x STRING
%x COMMENT
%x SOURCE 
%x TOKEN 
%x STATISTIC

%%

^"#pragma" {
  LIST;
  BEGIN PRAGMA;
}

"/*" {
  LIST; 
  BEGIN COMMENT;
}

"+" { token("+"); }
"-" { token("-"); }
"*" { token("*"); }
"/" { token("/"); }
"%" { token("%"); }
"=" { token("="); }
"<" { token("<"); }
"<="  { token("<="); }
"!=" {  token("!="); }
">=" {  token(">="); }
">" {  token(">"); }
"==" { token("=="); }
"&&" { token("&&"); }
"||" { token("||"); }
"!" { token("!"); }

<INITIAL>{delimiter} {
    tokenString("delim", yytext);
}

<INITIAL>{keyword} {
    tokenString("KW", yytext);
}

<INITIAL>{id} {
    tokenString("id", yytext);
    int id_offset = check_idtable(yytext);
    if(id_offset){
        strcpy(id_table[id_offset].name, yytext);
        id_table[id_offset].counter += 1;
    }
    else{
        insert_idtable(yytext, id_count);
        id_count += 1;
    }
}

<INITIAL>{integer} {
    tokenString("integer", yytext);
}

<INITIAL>{float} {
    tokenString("float", yytext);
}

<INITIAL>{scientific} {
    tokenString("scientific", yytext);
}

\" { 
    str_buf[0] = '\0';
    LIST;
    BEGIN STRING;
}

"//"(.)*(\n) { 
    LIST;  
    if (Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
}

<STRING>\\\" {
    LIST;
    strncat(str_buf, "\"", sizeof(buf) - strlen(buf) - 1);
}

<STRING>\\\\ {
    LIST;
    strncat(str_buf, "\\", sizeof(buf) - strlen(buf) - 1);
}

<STRING>\\ {
    LIST;
    strncat(str_buf, "\\", sizeof(buf) - strlen(buf) - 1);
}

<STRING>\" {
    tokenString("string", str_buf); BEGIN 0;
}

<STRING>. { 
    LIST;
    strncat(str_buf, yytext, sizeof(buf) - strlen(buf) - 1);
}

<COMMENT>. {
    LIST;
}

<COMMENT>"*/" {
    LIST;
    BEGIN 0;
}

<COMMENT>"\n" {
    LIST;
    if (Opt_Source) printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
}

<PRAGMA>{whitespace}"source" {
    LIST;
    BEGIN SOURCE;
}

<PRAGMA>{whitespace}"token" {
    LIST;
    BEGIN TOKEN;
}

<PRAGMA>{whitespace}"statistic" {
    LIST;
    BEGIN STATISTIC;
}

<PRAGMA_COMMENT>"\n" {
    LIST;
    if (Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
}

<PRAGMA_COMMENT>"*/" {
    LIST;
    BEGIN 0;
}

<PRAGMA_COMMENT>. {
    LIST;
}

<SOURCE>{whitespace}"on"({whitespace})*("/*") {
    LIST;
    Opt_Source = 1;
    BEGIN PRAGMA_COMMENT;
}

<SOURCE>{whitespace}"off"({whitespace})*("/*") {
    LIST;
    Opt_Source = 0;
    BEGIN PRAGMA_COMMENT;
}

<SOURCE>{whitespace}"on"({whitespace})*("//")(.)*"\n" {
    LIST;
    Opt_Source = 1;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<SOURCE>{whitespace}"off"({whitespace})*("//")(.)*"\n" {
    LIST;
    Opt_Source = 0;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<SOURCE>{whitespace}"on"({whitespace})*"\n" {
    LIST;
    Opt_Source = 1;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<SOURCE>{whitespace}"off"({whitespace})*"\n" {
    LIST;
    Opt_Source = 0;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<SOURCE>. {
    fprintf(stderr, "Error at line %d: %s\n", linenum, yytext);
    exit(1); 
}

<TOKEN>{whitespace}"on"({whitespace})*("/*") {
    LIST;
    Opt_Token = 1;
    BEGIN PRAGMA_COMMENT;
}

<TOKEN>{whitespace}"off"({whitespace})*("/*") {
    LIST;
    Opt_Token = 0;
    BEGIN PRAGMA_COMMENT;
}

<TOKEN>{whitespace}"on"({whitespace})*("//")(.)*"\n" {
    LIST;
    Opt_Token = 1;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<TOKEN>{whitespace}"off"({whitespace})*("//")(.)*"\n" {
    LIST;
    Opt_Token = 0;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<TOKEN>{whitespace}"on"({whitespace})*"\n" {
    LIST;
    Opt_Token = 1;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<TOKEN>{whitespace}"off"({whitespace})*"\n" {
    LIST;
    Opt_Token = 0;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<TOKEN>. {
    fprintf(stderr, "Error at line %d: %s\n", linenum, yytext);
    exit(1); 
}

<STATISTIC>{whitespace}"on"({whitespace})*("/*") {
    LIST;
    Opt_Statistic = 1;
    BEGIN PRAGMA_COMMENT;
}

<STATISTIC>{whitespace}"off"({whitespace})*("/*") {
    LIST;
    Opt_Statistic = 0;
    BEGIN PRAGMA_COMMENT;
}

<STATISTIC>{whitespace}"on"({whitespace})*("//")(.)*"\n" {
    LIST;
    Opt_Statistic = 1;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<STATISTIC>{whitespace}"off"({whitespace})*("//")(.)*"\n" {
    LIST;
    Opt_Statistic = 0;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<STATISTIC>{whitespace}"on"({whitespace})*"\n" {
    LIST;
    Opt_Statistic = 1;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<STATISTIC>{whitespace}"off"({whitespace})*"\n" {
    LIST;
    Opt_Statistic = 0;
    if(Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
    BEGIN 0;
}

<STATISTIC>. {
    fprintf(stderr, "Error at line %d: %s\n", linenum, yytext);
    exit(1); 
}

\n {
  LIST;
  if (Opt_Source)
      printf("%d:%s\n", linenum, buf);
  ++linenum;
  buf[0] = '\0';
}

[ \t] {
  LIST;
} 

. { // Unrecognized character
  fprintf(stderr, "Error at line %d: %s\n", linenum, yytext);
  exit(1);
}

%%

int main( int argc, char **argv )
{
    if (argc >= 2)
    {
        yyin = fopen( argv[1], "r" );
        if ( NULL == yyin ) {
            fprintf( stderr, "Cannot open: %s\n", argv[1] );
            exit(-1);
        }
    }
    else
    {
        yyin = stdin;
    }

    yylex();

    if (Opt_Statistic)
    {
        print_idtable();
    }

    exit(0);
}

int check_idtable(char *idname){
    int i;
    for(i=0; i<ID_TABLE_SIZE; i++)
    {
        if(strcmp(id_table[i].name, idname) == 0) return i;
    }
    return 0;
}

void insert_idtable(char *idname, int id_offset){
    strcpy(id_table[id_offset].name, idname);
    id_table[id_offset].counter = 1;
}

void print_idtable(){
    printf("frequencies of identifiers:\n");
    int i;
    for(i=1; i<ID_TABLE_SIZE; i++)
    {
        if(id_table[i].counter == 0) break;
        printf("%s\t%d\n", id_table[i].name, id_table[i].counter);
    }
}