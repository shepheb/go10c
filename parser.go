package main

import (
	"fmt"
	"io/ioutil"
	"log"

	"github.com/alecthomas/participle"
)

type GoFile struct {
	Package string                 `"package" @Ident`
	Imports []string               `{ "import" @String }`
	Decls   []*TopLevelDeclaration `{ @@ }`
}

// Declarations allowed inside a body.
type Declaration struct {
	Var   *VarDecl      `  @@`
	Type  *TypeDecl     `| @@`
	Const *ConstDecl    `| @@`
	Short *ShortVarDecl `| @@`
}

type TopLevelDeclaration struct {
	Func   *FuncDecl    `  @@`
	Simple *Declaration `| @@`
}

type VarDecl struct {
	Names []string      `"var" @Ident {"," @Ident}`
	Type  *Type         `@@`
	Exprs []*Expression `["=" @@ {"," @@}]`
}

type ConstDecl struct {
	Name  string `"const" @Ident`
	Value int    `"=" @Int`
}

type ShortVarDecl struct {
	Names []string      `@Ident { "," @Ident }`
	Exprs []*Expression `":=" @@ { "," @@ }`
}

type TypeDecl struct {
	Name string `"type" @Ident`
	Type *Type  `@@`
}

type Type struct {
	Function *FunctionType   `  @@`
	Struct   *StructType     `| @@`
	Array    *ArrayType      `| @@`
	Pointer  *PointerType    `| @@`
	Name     *QualifiedIdent `| @@`
	Builtin  string
}

type QualifiedIdent struct {
	Name string `@Ident ["." @Ident]`
}

type PointerType struct {
	Inner *Type `"*" @@`
}

type ArrayType struct {
	Inner *Type `"[" "]" @@`
}

type StructType struct {
	Fields []*FieldDecl `"struct" "{" { @@ } "}"`
}

type FieldDecl struct {
	Names []string `@Ident { "," @Ident }`
	Type  *Type    `@@`
}

// TODO: Handle functions with receivers.
type FunctionType struct {
	ParamTypes []*Type `("(" ")" | "(" @@ { "," @@ } ")")`
	ReturnType *Type   `[@@]`
}

type FuncDecl struct {
	Name       string          `"func" @Ident`
	Args       []*NamesAndType `"(" (")" | @@ { "," @@ } ")")`
	ReturnType *Type           `[@@]`
	Body       []*Statement    `"{" {@@} "}"`
}

// Represents, eg.    x, y, z Type
type NamesAndType struct {
	Args []string `@Ident { "," @Ident }`
	Type *Type    `@@`
}

// Statements
type Statement struct {
	Decl     *Declaration  `  @@`
	Labeled  *LabeledStmt  `| @@`
	Return   *ReturnStmt   `| @@`
	Continue *ContinueStmt `| @@`
	Goto     *GotoStmt     `| @@`
	//Fallthrough *string       `| "fallthrough"`
	Block []*Statement `| ("{" { @@ } "}")`
	If    *IfStmt      `| @@`
	//Switch      *SwitchStmt   `| @@`
	For    *ForStmt    `| @@`
	Simple *SimpleStmt `| @@`
}

type LabeledStmt struct {
	Name string     `@Ident ":"`
	Stmt *Statement `@@`
}

type SimpleStmt struct {
	IncDec    *IncDecStmt   `  @@`
	Assign    *Assignment   `| @@`
	ShortDecl *ShortVarDecl `| @@`
	Expr      *Expression   `| @@`
}

type IncDecStmt struct {
	Expr *Expression `@@`
	Op   string      `("++" | "--")`
}

type Assignment struct {
	Lhs []*Expression `@@ { "," @@ }`
	Op  string        `@("=" | "+=" | "-=" | "|=" | "^=" | "*=" | "/=" | "%=" | "&=" | "&^=" | "<<=" | ">>=")`
	Rhs []*Expression `@@ { "," @@ }`
}

type ReturnStmt struct {
	Expr *Expression `"return" [@@]`
}

type ContinueStmt struct {
	Target *string `"continue" [@Ident]`
}

type GotoStmt struct {
	Target string `"goto" @Ident`
}

type IfStmt struct {
	Initializer *SimpleStmt  `"if" (( @@ ";"`
	Condition   *Expression  `@@ ) | @@ ) "{"`
	IfBody      []*Statement `{ @@ } "}"`
	Else        *ElseBlock   `[ "else" @@ ]`
}

type ElseBlock struct {
	If   *IfStmt      `  @@`
	Body []*Statement `| ("{" { @@ } "}")`
}

type ForStmt struct {
	ForClause *ForClause   `"for" (@@`
	Condition *Expression  `| @@) "{"`
	Body      []*Statement `{ @@ } "}"`
}

type ForClause struct {
	Initializer *SimpleStmt `[@@] ";"`
	Condition   *Expression `[@@] ";"`
	Increment   *SimpleStmt `[@@]`
}

// Expressions
type Expression DisjExpr

type DisjExpr struct {
	Parts []*ConjExpr `@@ { "||" @@ }`
}

type ConjExpr struct {
	Parts []*InequalityExpr `@@ { "&&" @@ }`
}

type InequalityExpr struct {
	Base *AdditiveExpr        `@@`
	Tail []*InequalityOperand `{ @@ }`
}

type InequalityOperand struct {
	Op   string `@("==" | "!=" | "<" | ">" | "<=" | ">=")`
	Expr *AdditiveExpr
}

type AdditiveExpr struct {
	Base *MultiplicativeExpr `@@`
	Tail []*AdditiveOperand  `{ @@ }`
}

type AdditiveOperand struct {
	Op   string              `@("+" | "-" | "|" | "^")`
	Expr *MultiplicativeExpr `@@`
}

type MultiplicativeExpr struct {
	Base *UnaryExpr               `@@`
	Tail []*MultiplicativeOperand `{ @@ }`
}

type MultiplicativeOperand struct {
	Op   string     `@("*" | "/" | "%" | "&" | "<<" | ">>" | "&^")`
	Expr *UnaryExpr `@@`
}

type UnaryExpr struct {
	Op   string `@["+" | "-" | "!" | "^" | "*" | "&" | "<-"]`
	Expr *Term  `@@`
}

type Term struct {
	Base *PrimaryExpr  `@@`
	Tail []*IndexLikes `{@@}`
}

// Calls, .field, and [index].
type IndexLikes struct {
	Selector string          `("." @Ident)`
	Index    *Expression     `| ("[" @@ "]")`
	Call     *ExpressionList `| ("(" @@ ")")`
}

type PrimaryExpr struct {
	Operand    *SimpleOperand `  @@`
	Conversion *Conversion    `| @@`
	Builtin    *BuiltinCall   `| @@`
}

type SimpleOperand struct {
	Lit     *Literal        `  @@`
	SubExpr *Expression     `| ("(" @@ ")")`
	Var     *QualifiedIdent `| @@`
}

type Conversion struct {
	Type *NonPointerType `@@ "("`
	Expr *Expression     `@@ ")"`
}

type NonPointerType struct {
	Array   *ArrayType      `  @@`
	Struct  *StructType     `| @@`
	Func    *FunctionType   `| @@`
	Wrapped *Type           `| ("(" @@ ")")`
	Name    *QualifiedIdent `| @@`
}

type Literal struct {
	Basic   *BasicLit    `  @@`
	LitType *LiteralType `| (@@`
	LitVal  []*Element   `( ("{" "}") | "{" @@ { "," @@ } "}"))`
}

type BasicLit struct {
	Int    *int    `  @Int`
	Bool   *bool   `| ("false" | "true")`
	Char   *byte   `| @Char`
	String *string `| @String`
}

type LiteralType struct {
	Struct *StructType `  @@`
	Array  *ArrayType  `| @@`
	Name   *string     `| @Ident`
}

type Element struct {
	KeyName *string     `[( @Ident`
	KeyExpr *Expression `| @@) ":"]`
	Value   *Expression `@@`
}

type BuiltinCall struct {
	Name  string        `("new" | "delete" | "panic") "("`
	Type  *Type         `[@@ [","]]`
	Exprs []*Expression `[ @@ { "," @@ } ] ")"`
}

// This is wrapped up as a struct so it can be a nil pointer in an optional.
type ExpressionList struct {
	Exprs []*Expression `@@ { "," @@ }`
}

var parser *participle.Parser

func buildParser() *participle.Parser {
	if parser == nil {
		var err error
		parser, err = participle.Build(&GoFile{}, nil)
		fmt.Println(parser.String())
		if err != nil {
			log.Fatal("Error building parser: %v\n", err)
		}
	}
	return parser
}

func Parse(filename string) (*GoFile, error) {
	file := &GoFile{}
	text, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	parser := buildParser()
	err = parser.ParseString(string(text), file)
	if err != nil {
		return nil, err
	}
	return file, nil
}