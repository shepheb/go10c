{
module Parser where

import GoLexer
}

%name parseGo
%tokentype { Token }
%error { parseError }

%token
    semi        { LSemi }
    newline     { LNewline }
    eof         { LEOF }
    ident       { LIdent $$ }
    intlit      { LInt $$ }
    stringlit   { LString $$ }
    charlit     { LChar $$ }
    boollit     { LBool $$ }
    break       { LBreak }
    case        { LCase }
    chan        { LChan }
    const       { LConst }
    continue    { LContinue }
    default     { LDefault }
    defer       { LDefer }
    else        { LElse }
    fallthrough { LFallthrough }
    for         { LFor }
    func        { LFunc }
    go          { LGo }
    goto        { LGoto }
    if          { LIf }
    import      { LImport }
    interface   { LInterface }
    map         { LMap }
    package     { LPackage }
    range       { LRange }
    return      { LReturn }
    select      { LSelect }
    struct      { LStruct }
    switch      { LSwitch }
    type        { LType }
    var         { LVar }
    OP          { LOpenP }
    CP          { LCloseP }
    OCB         { LOpenCB }
    CCB         { LCloseCB }
    OSB         { LOpenSB }
    CSB         { LCloseSB }
    colon       { LColon }
    dot         { LDot }
    comma       { LComma }
    '+'         { LOp "+" }
    '-'         { LOp "-" }
    '*'         { LOp "*" }
    '/'         { LOp "/" }
    '%'         { LOp "%" }
    '&'         { LOp "&" }
    '|'         { LOp "|" }
    '^'         { LOp "^" }
    '<<'        { LOp "<<" }
    '>>'        { LOp ">>" }
    '&^'        { LOp "&^" }
    '+='        { LOp "+=" }
    '-='        { LOp "-=" }
    '*='        { LOp "*=" }
    '/='        { LOp "/=" }
    '%='        { LOp "%=" }
    '&='        { LOp "&=" }
    '|='        { LOp "|=" }
    '^='        { LOp "^=" }
    '<<='       { LOp "<<=" }
    '>>='       { LOp ">>=" }
    '&^='       { LOp "&^=" }
    '&&'        { LOp "&&" }
    '||'        { LOp "||" }
    '<-'        { LOp "<-" }
    '++'        { LOp "++" }
    '--'        { LOp "--" }
    '=='        { LOp "==" }
    '<'         { LOp "<" }
    '>'         { LOp ">" }
    '='         { LOp "=" }
    '!'         { LOp "!" }
    '!='        { LOp "!=" }
    '<='        { LOp "<=" }
    '>='        { LOp ">=" }
    ':='        { LOp ":=" }
    '...'       { LOp "..." }

%%

SourceFile :: { SourceFile }
           : PackageClause eol Blanks ImportDecls Blanks TopLevelDecls        { SourceFile $1 (reverse $4) (reverse $6) }

PackageClause :: { String }
PackageClause : package ident       { $2 }

ImportDecls :: { [Import] }
ImportDecls : ImportDecls eol ImportDecl    { $3 ++ $1 }
            | ImportDecls eol               { $1 }
            | ImportDecl                    { $1 }

ImportDecl :: { [Import] }
ImportDecl : import OP ImportSpecs CP       { $3 }
           | import ImportSpec              { [$2] }

ImportSpecs :: { [Import] }
ImportSpecs : ImportSpecs eol ImportSpec    { $3 : $1 }
            | ImportSpec                    { [$1] }

ImportSpec :: { Import }
ImportSpec : dot stringlit                  { Import Nothing $2 }
           | ident stringlit                { Import (Just $1) $2 }


eol :: { Token }
eol : semi      { $1 }
    | newline   { $1 }

Blanks :: { () }
Blanks : Blanks eol     { () }
       | {- empty -}    { () }

QualifiedIdent :: { QualIdent }
QualifiedIdent : ident dot ident    { QualIdent (Just $1) $3 }
               | ident              { QualIdent Nothing $1 }

TypeName :: { Type }
TypeName : QualifiedIdent           { TypeName $1 }

TypeLit :: { Type }
TypeLit : ArrayType             { $1 }
        | StructType            { $1 }
        | PointerType           { $1 }
        | FunctionType          { $1 }


ArrayType :: { Type }
ArrayType : OSB CSB Type { TypeArray $3 }

PointerType :: { Type }
PointerType : '*' Type      { TypePointer $2 }


StructType :: { Type }
StructType : struct OCB FieldDecls CCB      { TypeStruct (reverse $3) }
FieldDecls :: { [(String, Type)] }
FieldDecls : FieldDecls eol FieldDecl       { $3 ++ $1 }
           | FieldDecls eol                 { $1 }
           | FieldDecl                      { $1 }
           | {- empty -}                    { [] }
FieldDecl :: { [(String, Type)] }
FieldDecl : IdentifierList Type             { map (\x -> (x, $2)) $1 }


FunctionType :: { Type }
FunctionType : func TypeParameters Type     { TypeFunction $2 $3 }
             | func TypeParameters          { TypeFunction $2 TypeVoid }
TypeParameters :: { [Type] }
TypeParameters : OP TypeParameterList CP            { reverse $2 }
               | OP CP                              { [] }
TypeParameterList :: { [Type] }
TypeParameterList : TypeParameterList comma Type    { $3 : $1 }
                  | Type                            { [$1] }


Type :: { Type }
Type : TypeName         { $1 }
     | TypeLit          { $1 }
     | OP Type CP       { $2 }



Declaration :: { [Statement] }
Declaration : TypeDecl { $1 }
            | VarDecl   { $1 }
            | ShortVarDecl { $1 }

TopLevelDecl :: { [Statement] }
TopLevelDecl : Declaration  { $1 }
             | FunctionDecl { $1 }

TopLevelDecls :: { [Statement] }
TopLevelDecls : TopLevelDecls eol TopLevelDecl      { $3 ++ $1 }
              | TopLevelDecls eol                   { $1 }
              | TopLevelDecl                        { $1 }
              | {- empty -}                         { [] }

TypeDecl :: { [Statement] }
TypeDecl : type TypeSpec            { $2 }
         | type OP TypeSpecs CP     { reverse $3 }
TypeSpecs :: { [Statement] }
TypeSpecs : TypeSpecs eol TypeSpec  { $3 ++ $1 }
          | TypeSpecs eol           { $1 }
          | TypeSpec                { $1 }
          {- no empty -}
TypeSpec :: { [Statement] }
TypeSpec : ident Type               { [StmtTypeDecl $1 $2] }


VarDecl :: { [Statement] }
VarDecl : var VarSpec               { reverse $2 }
        | var OP VarSpecs CP        { reverse $3 }
VarSpecs :: { [Statement] }
VarSpecs : VarSpecs eol VarSpec     { $3 ++ $1 }
         | VarSpecs eol             { $1 }
         | VarSpec                  { $1 }
         {- no empty -}
VarSpec :: { [Statement] }
VarSpec : IdentifierList Type '=' ExpressionList    { let xs = map Just $4 ++ repeat Nothing in zipWith (\i x -> StmtVarDecl i $2 x) $1 xs }
        | IdentifierList Type                       { map (\i -> StmtVarDecl i $2 Nothing) $1 }


ShortVarDecl :: { [Statement] }
ShortVarDecl : IdentifierList ':=' ExpressionList   { reverse (zipWith StmtShortVarDecl $1 $3) }


FunctionDecl :: { [Statement] }
FunctionDecl : func ident Parameters Type Block             { [StmtFunction $2 $3 $4 (Just $5)] }
             | func ident Parameters Block                  { [StmtFunction $2 $3 TypeVoid (Just $4)] }
             | func ident Parameters Type                   { [StmtFunction $2 $3 $4 Nothing] }
Parameters :: { [(String, Type)] }
Parameters : OP ParameterList CP                            { reverse $2 }
           | OP CP                                          { [] }
ParameterList :: { [(String, Type)] }
ParameterList : ParameterList comma Parameter               { $3 ++ $1 }
              | Parameter                                   { $1 }
Parameter :: { [(String, Type)] }
Parameter : IdentifierList Type                             { map (\i -> (i, $2)) $1 }



{- nonempty, backwards! -}
IdentifierList :: { [String] }
IdentifierList : IdentifierList comma ident     { $3 : $1 }
               | ident                          { [$1] }

{- nonempty, backwards! -}
ExpressionList :: { [Expr] }
ExpressionList : ExpressionList comma Expression    { $3 : $1 }
               | Expression                         { [$1] }

{- Block's return value is in order. -}
Block :: { [Statement] }
Block : OCB Statements CCB      { reverse $2 }

{- Statements return in reverse order. -}
Statements  :: { [Statement] }
Statements  : Statements eol Statement  { $3 ++ $1 }
            | Statement                 { $1 }
            | {- empty -}               { [] }

{- Each is a list of Statements, in reverse order. -}
Statement :: { [Statement] }
Statement : Declaration         { $1 }
          | LabeledStmt         { $1 }
          | SimpleStmt          { $1 }
          | ReturnStmt          { $1 }
          | BreakStmt           { $1 }
          | ContinueStmt        { $1 }
          | GotoStmt            { $1 }
          | FallthroughStmt     { $1 }
          | Block               { $1 }
          | IfStmt              { $1 }
          | SwitchStmt          { $1 }
          | ForStmt             { $1 }

SimpleStmt :: { [Statement] }
SimpleStmt : EmptyStmt          { $1 }
           | ExpressionStmt     { $1 }
           | IncDecStmt         { $1 }
           | Assignment         { $1 }

EmptyStmt :: { [Statement] }
EmptyStmt : { [] }
LabeledStmt :: { [Statement] }
LabeledStmt : ident colon Statement         { $3 ++ [StmtLabel $1] }
ExpressionStmt :: { [Statement] }
ExpressionStmt : Expression                 { [StmtExpr $1] }
IncDecStmt :: { [Statement] }
IncDecStmt : Expression '++'                { [StmtInc $1] }
           | Expression '--'                { [StmtDec $1] }


IfStmt :: { [Statement] }
IfStmt : if Initializer Expression Block else ElseBlock     { [StmtIf $2 $3 $4 $6] }
       | if Initializer Expression Block                    { [StmtIf $2 $3 $4 []] }
ElseBlock :: { [Statement] }
ElseBlock : IfStmt                                          { $1 }
          | Block                                           { $1 }


Initializer :: { Statement }
Initializer : SimpleStmt semi   { head $1 }
            | {- empty -}       { StmtEmpty }


SwitchStmt :: { [Statement] }
SwitchStmt : switch Initializer Expression OCB ExprCaseClauses CCB      { [StmtSwitch $2 $3 (reverse $5)] }
           | switch Initializer OCB ExprCaseClauses CCB                 { [StmtSwitch $2 (LitBool True) (reverse $4)] }

ExprCaseClauses :: { [([Expr], [Statement])] }
ExprCaseClauses : ExprCaseClauses ExprCaseClause        { $2 : $1 }
                | ExprCaseClause                        { [$1] }

ExprCaseClause :: { ([Expr], [Statement]) }
ExprCaseClause : ExprSwitchCase colon Statements        { ($1, reverse $3) }

ExprSwitchCase :: { [Expr] }
ExprSwitchCase : case ExpressionList                    { reverse $2 }
               | default                                { [] }


ForStmt :: { [Statement] }
ForStmt : for ForClause Block           { [$2 $3] }
        | for Expression Block          { [StmtFor StmtEmpty $2 StmtEmpty $3] }

ForClause :: { [Statement] -> Statement }
ForClause : SimpleStmt semi Expression semi SimpleStmt      { StmtFor (head $1) $3 (head $5) }
          | SimpleStmt semi Expression semi                 { StmtFor (head $1) $3 StmtEmpty }
          | SimpleStmt semi semi SimpleStmt                 { StmtFor (head $1) (LitBool True) (head $4) }
          | SimpleStmt semi semi                            { StmtFor (head $1) (LitBool True) StmtEmpty }
          | semi Expression semi SimpleStmt                 { StmtFor StmtEmpty $2 (head $4) }
          | semi Expression semi                            { StmtFor StmtEmpty $2 StmtEmpty }
          | semi semi SimpleStmt                            { StmtFor StmtEmpty (LitBool True) (head $3) }
          | semi semi                                       { StmtFor StmtEmpty (LitBool True) StmtEmpty }


ReturnStmt :: { [Statement] }
ReturnStmt : return Expression          { [StmtReturn (Just $2)] }
           | return                     { [StmtReturn Nothing] }

BreakStmt :: { [Statement] }
BreakStmt : break ident                 { [StmtBreak $2] }
          | break                       { [StmtBreak ""] }

ContinueStmt :: { [Statement] }
ContinueStmt : continue ident           { [StmtContinue $2] }
             | continue                 { [StmtContinue ""] }

GotoStmt :: { [Statement] }
GotoStmt : goto ident                   { [StmtGoto $2] }
         | goto                         { [StmtGoto ""] }

FallthroughStmt :: { [Statement] }
FallthroughStmt : fallthrough           { [StmtFallthrough] }


Assignment :: { [Statement] }
Assignment : ExpressionList AssignOp ExpressionList     { zipWith (StmtAssignment $2) $1 $3 }
AssignOp :: { Maybe String }
AssignOp : '='      { Nothing }
         | '+='     { Just "+" }
         | '-='     { Just "-" }
         | '|='     { Just "|" }
         | '^='     { Just "^" }
         | '*='     { Just "*" }
         | '/='     { Just "/" }
         | '%='     { Just "%" }
         | '&='     { Just "&" }
         | '&^='    { Just "&^" }
         | '<<='    { Just "<<" }
         | '>>='    { Just ">>" }



Operand :: { Expr }
Operand : Literal               { $1 }
        | QualifiedIdent        { Var $1 }
        | OP Expression CP      { $2 }

Literal :: { Expr }
Literal : BasicLit              { $1 }
        | CompositeLit          { $1 }
        {-| FunctionLit           { $1 }-}

BasicLit :: { Expr }
BasicLit : intlit               { LitInt $1 }
         | boollit              { LitBool $1 }
         | charlit              { LitChar $1 }
         | stringlit            { LitString $1 }

CompositeLit :: { Expr }
CompositeLit : LiteralType LiteralValue                 { LitComposite $1 $2 }

LiteralType :: { Type }
LiteralType : StructType                                { $1 }
            | ArrayType                                 { $1 }
            | TypeName                                  { $1 }

LiteralValue :: { [(Key, Expr)] }
LiteralValue : OCB ElementList CCB                      { reverse $2 }
             | OCB CCB                                  { [] }

ElementList :: { [(Key, Expr)] }
ElementList : ElementList comma Element                 { $3 : $1 }
            | Element                                   { [$1] }

Element :: { (Key, Expr) }
Element : Key colon Value                               { ($1, $3) }
        | Value                                         { (KeyNone, $1) }

Key :: { Key }
Key : ident                                             { KeyName $1 }
    | Expression                                        { KeyIndex $1 }

Value :: { Expr }
Value : Expression                                      { $1 }


PrimaryExpr :: { Expr }
PrimaryExpr : Operand               { $1 }
            | Conversion            { $1 }
            | BuiltinCall           { $1 }
            | PrimaryExpr Selector  { Selector $1 $2 }
            | PrimaryExpr Index     { Index $1 $2 }
            | PrimaryExpr Call      { Call $1 $2 }

Selector :: { String }
Selector : dot ident                { $2 }

Index :: { Expr }
Index : OSB Expression CSB          { $2 }

Call :: { [Expr] }
Call : OP ExpressionList CP         { reverse $2 }
     | OP CP                        { [] }

Conversion :: { Expr }
Conversion : Type OP Expression CP              { Conversion $1 $3 }

BuiltinCall :: { Expr }
BuiltinCall : ident OP CP                       { BuiltinCall $1 Nothing [] }
            | ident OP Type CP                  { BuiltinCall $1 (Just $3) [] }
            | ident OP Type ExpressionList CP   { BuiltinCall $1 (Just $3) (reverse $4) }
            | ident OP ExpressionList CP        { BuiltinCall $1 Nothing (reverse $3) }


Expression :: { Expr }
Expression : BinaryExpr                         { $1 }

UnaryExpr :: { Expr }
UnaryExpr : PrimaryExpr                         { $1 }
          | UnaryOp UnaryExpr                   { UnOp $1 $2 }

BinaryExpr :: { Expr }
BinaryExpr : BinaryExpr '||' BinaryExpr1        { BinOp (LOp "||") $1 $3 }
           | BinaryExpr1                        { $1 }

BinaryExpr1 :: { Expr }
BinaryExpr1 : BinaryExpr1 '&&' BinaryExpr2      { BinOp (LOp "&&") $1 $3 }
            | BinaryExpr2                       { $1 }

BinaryExpr2 :: { Expr }
BinaryExpr2 : BinaryExpr2 Prec3Op BinaryExpr3   { BinOp $2 $1 $3 }
            | BinaryExpr3                       { $1 }

BinaryExpr3 :: { Expr }
BinaryExpr3 : BinaryExpr3 Prec4Op BinaryExpr4   { BinOp $2 $1 $3 }
            | BinaryExpr4                       { $1 }

BinaryExpr4 :: { Expr }
BinaryExpr4 : BinaryExpr4 Prec5Op UnaryExpr     { BinOp $2 $1 $3 }
            | UnaryExpr                         { $1 }


Prec3Op :: { Token }
Prec3Op : '=='  { $1 }
        | '!='  { $1 }
        | '<'   { $1 }
        | '>'   { $1 }
        | '<='  { $1 }
        | '>='  { $1 }

Prec4Op :: { Token }
Prec4Op : '+'   { $1 }
        | '-'   { $1 }
        | '|'   { $1 }
        | '^'   { $1 }

Prec5Op :: { Token }
Prec5Op : '*'   { $1 }
        | '/'   { $1 }
        | '%'   { $1 }
        | '&'   { $1 }
        | '<<'  { $1 }
        | '>>'  { $1 }
        | '&^'  { $1 }


UnaryOp :: { Token }
UnaryOp : '+'   { $1 }
        | '-'   { $1 }
        | '!'   { $1 }
        | '^'   { $1 }
        | '*'   { $1 }
        | '&'   { $1 }
        | '<-'  { $1 }


{

data Type = TypeName QualIdent
          | TypeArray Type
          | TypeStruct [(String, Type)] -- a struct with its parameters and their types.
          | TypePointer Type
          | TypeFunction [Type] Type -- a function giving its argument types and (singular, in my Go) return type.
          | TypeVoid -- nonexistent type used for functions without return values
  deriving (Eq, Show)

data Statement = StmtTypeDecl String Type
               | StmtVarDecl String Type (Maybe Expr)
               | StmtShortVarDecl String Expr
               | StmtFunction String [(String, Type)] Type (Maybe [Statement])
               | StmtLabel String
               | StmtEmpty
               | StmtExpr Expr
               | StmtInc Expr
               | StmtDec Expr
               | StmtAssignment (Maybe String) Expr Expr -- the string is an operand, or Nothing for basic assignment
               | StmtIf Statement Expr [Statement] [Statement] -- the initializer, condition, block and else block. (the else block contains a single StmtIf, for an "else if")
               | StmtFor Statement Expr Statement [Statement] -- initializer, condition, increment, block
               | StmtSwitch Statement Expr [([Expr], [Statement])] -- initializer, switching variable (can be omitted, then equiv to "true". parser fills this in),
                                                                   -- list of cases (comma-separated list of expr values, and bodies), default is empty Expr list.
               | StmtReturn (Maybe Expr)
               | StmtBreak String -- label
               | StmtContinue String -- label
               | StmtGoto String -- label
               | StmtFallthrough
  deriving (Show)

data Expr = LitInt Int
          | LitBool Bool
          | LitChar Char
          | LitString String
          | LitComposite Type [(Key, Expr)]
          | Var QualIdent
          | Selector Expr String
          | Index Expr Expr -- array expression and index expression
          | Call Expr [Expr] -- function expression and argument expressions
          | BuiltinCall String (Maybe Type) [Expr] -- name of builtin, maybe a type as the first arg, and a list of parameter expressions
          | Conversion Type Expr
          | UnOp Token Expr -- unary operator and expression
          | BinOp Token Expr Expr -- binary operator and operands
  deriving (Show)

data QualIdent = QualIdent { package :: Maybe String, name :: String }
  deriving (Show, Eq)

data SourceFile = SourceFile String [Import] [Statement]
    deriving (Show)

data Import = Import (Maybe String) String
    deriving (Show)

data Key = KeyNone | KeyName String | KeyIndex Expr
    deriving (Show)

parseError s = error $ "Parse error: " ++ show s

}
