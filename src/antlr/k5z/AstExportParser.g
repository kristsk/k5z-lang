// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>.
 All rights reserved.
// SPDX-License-Identifier: MIT

//=============================================================================================

//---------------------------------------------------------------------------------------------
tree grammar AstExportParser;
//---------------------------------------------------------------------------------------------



/* tab size is 4 spaces */



//---------------------------------------------------------------------------------------------
options {
	tokenVocab = Ast;
	ASTLabelType = CommonTree;
	output = template;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@header {
	package lv.kristsk.k5z.antlr.parsers;

	import lv.kristsk.k5z.*;
	import lv.kristsk.k5z.utilities.*;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@members {
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
library
	: ^(LIBRARY program=PROGRAM? name=FUNCTION_ID library_imports library_includes function_declarations ) EOF
		-> library(name={$name.text}, program={$program != null}, library_imports={$library_imports.st}, library_includes={$library_includes.st}, function_declarations={$function_declarations.st})
	;



function_declarations
	: ^(FUNCTIONS function_declaration*)
		-> function_declarations()
	;



library_imports
	: ^(IMPORTS i+=library_import*)
		-> library_imports(i={$i})
	;



library_includes
	: ^(INCLUDES library_include*)
		-> library_includes()
	;



library_include
	: ^(INCLUDE QUOTED_STRING FREE_ID (library_include_function_declaration | ^(FUNCTIONS library_include_function_declaration*) ) )
	;



library_include_function_declaration
	: ^(INCLUDED_FUNCTION ^(FUNCTION FDIRTY? FREF? FUNCTION_ID ^(PARAMS (parameter)*) ^(BODY STATEMENTS) ) FREE_ID?)
	;



library_import
	: ^(IMPORT QUOTED_STRING (^(IMPORTITEM FUNCTION_ID FUNCTION_ID) )+ )
	;



function_declaration
	: ^(FUNCTION FDIRTY? FREF? FUNCTION_ID ^(PARAMS (parameter)*) body )
	;



parameter
	: ^((VAL|REF|OPT) VARIABLE_ID expression?)
	;



body
	: ^(BODY ^(STATEMENTS statement*) )
	;



block
	: ^(BLOCK ^(STATEMENTS statement*) )
	;



math_op
	: (a='+'|a='-'|a='/'|a='*'|a='=='|a='>='|a='<='|a='!='|a='==='|a='!=='|a='<'|a='>'|a='..')
	;



expression
	: ^(math_op expression expression)
	| ^((QUESTION|QUESTION_AND_DOUBLEDOT) expression expression expression?)
	| ^(STRING QUOTED_STRING)
	| ^(ASSIGN expression (var_or_array) ASSIGNREF? ASSIGNAE?)
	| ^(NUM INT)
	| ^(NUM FLOAT)
	| ^(NEGATE expression)
	| ^(NOT expression)
	| ^(POSTFIX (var_or_array) ('--'|'++'))
	| ^(PREFIX (var_or_array) ('--'|'++'))
	| ^(BOOLEAN (TRUE|FALSE))
	| ^(('&&'|'and'|'||'|'or') expression expression)
	| ^(ARRAYDEF (^(ARRAYELEM expression+ ASSIGNREF?))*)
	| ^(ISSET (var_or_array))
	| closure_declaration
	| var
	| array
	| call
	| closure_invocation
	| ^(FID FUNCTION_ID FUNCTION_ID)
	;



statement
	: NOP
	| block
	| expression
	| ^(VOID (call|closure_invocation) )
	| ^(IF expression statement statement)
	| ^(FOR statement expression statement statement)
	| ^(FOREACH (var_or_array|array_declaration|call|closure_invocation) REF? var var? statement)
	| ^(WHILE expression statement)
	| ^(RETURN expression)
	| ^((BREAK|CONTINUE) INT)
	;



array_declaration
	: ^(ARRAYDEF (^(ARRAYELEM expression+ ASSIGNREF?))*)
	;



var_or_array
	: var
	| array
	;


var
	: ^(VAR VARIABLE_ID VAL? REF?)
	;



array
	: ^(VARA VARIABLE_ID VAL? REF? (expression)+ )
	;



call
	: ^(CALL ^(FID FUNCTION_ID FUNCTION_ID) (^(ARGS expression*)|^(NARGS (^(NARG VARIABLE_ID expression) )* ) ) )
	;



closure_invocation
	: ^(CLOSINV (var_or_array) (^(ARGS expression*)|^(NARGS (^(NARG VARIABLE_ID expression) )* ) ) )
	;



closure_declaration
	: ^(CLOSDEF FREF? VARIABLE_ID (^(PARAMS (parameter)*))? body)
	;

//---------------------------------------------------------------------------------------------

//=============================================================================================

