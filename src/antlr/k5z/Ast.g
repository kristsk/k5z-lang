// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>.
 All rights reserved.
// SPDX-License-Identifier: MIT

//=============================================================================================

//--------------------------------------------------------------------------------------------- 
grammar Ast;
//---------------------------------------------------------------------------------------------



/* tab size is 4 spaces */



//---------------------------------------------------------------------------------------------
options{
	output = AST;
	ASTLabelType = CommonTree;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
tokens {
	LIBRARY;
	FUNCTIONS;
	FUNCTION;
	PROGRAM;
	FID;
	BLOCK;
	BODY;
	STATEMENTS;
	NOP;
	ASSIGN;
	ARRAYDEF;
	ARRAYELEM;
	STRING;
	VAR;
	VARA;
	NUM;
	CALL;
	IF;
	FOR;
	FOREACH;
	WHILE;
	TRY; CATCH; THROW;
	NOT;
	NEGATE;
	POSTFIX;
	PREFIX;
	ARGS;
	NARGS; NARG;
	PARAMS;
	REF; VAL; OPT;
	CLOSDEF; CLOSINV;
	BOOLEAN; TRUE; FALSE;
	RETURN;
	FAUTO; FCLEAN; FDIRTY;
	IMPORT;
	IMPORTS;
	IMPORTITEM;
	VOID;
	BREAK;
	CONTINUE;
	FREE_ID;
	VARIABLE_ID;
	DBGSRCL;
	INCLUDE;
	PHP_LIBRARY;
	INCLUDES;
	PHP_FILE;
	INCLUDED_FUNCTION;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@lexer::header {
	package lv.kristsk.k5z.antlr.parsers;

	import java.io.*;
	import org.antlr.runtime.tree.CommonTree;

	import lv.kristsk.k5z.*;
	import lv.kristsk.k5z.utilities.*;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@parser::header {
	package lv.kristsk.k5z.antlr.parsers;

	import java.util.Random;
	import java.util.Stack;
	import java.io.*;

	import lv.kristsk.k5z.*;
	import lv.kristsk.k5z.utilities.*;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@parser::members {

	//---------------------------------------------------------------------------------------------
	public Stack<String> paraphrases = new Stack<String>();

	public Library library = null;

	public Random randomNumberGenerator = new Random();

	public ArrayList<SourceError> errors = new ArrayList<SourceError>();
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public AstParser(CommonTokenStream inputStream, Library library) {
		this(inputStream);
		this.library = library;
		paraphrases.push("in header");
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void displayRecognitionError(String[] tokenNames, RecognitionException e) {

		String paraphrase = "";

		if(!paraphrases.empty()) {
			paraphrase = paraphrases.pop() + ": ";
		}

		SourceError error = null;

		if(e instanceof CompileTimeException) {
			
			error = new SourceError(
				((CompileTimeException) e).commonTreeNode,
				paraphrase + e.getMessage(),
				library
			);
		}
		else {
			error = new SourceError(
				e,
				paraphrase + getErrorMessage(e, tokenNames),
				library
			);
		}

		errors.add(error);
	}
	//---------------------------------------------------------------------------------------------
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@lexer::members {

	//---------------------------------------------------------------------------------------------
	public Library library;

	public ArrayList<SourceError> errors = new ArrayList<SourceError>();
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public AstLexer(ANTLRInputStream inputStream, Library library) {
		this(inputStream);
		this.library = library;
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void displayRecognitionError(String[] tokenNames, RecognitionException e) {
		errors.add(new SourceError(
			e,
			getErrorMessage(e, tokenNames),
			this.library
		));
	}
	//---------------------------------------------------------------------------------------------
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
library
	: (p='program'|l='library')
		id=FUNCTION_ID
		{ 
			library.name = $id.text;
			library.isProgram = $p != null;
		}
		';'
		
		import_line*
		
		include_line*

		function_declaration*
		
		EOF
		-> {$p != null}? ^(LIBRARY PROGRAM $id ^(IMPORTS import_line*) ^(INCLUDES include_line*) ^(FUNCTIONS function_declaration*) )
			-> ^(LIBRARY $id ^(IMPORTS import_line*) ^(INCLUDES include_line*) ^(FUNCTIONS function_declaration*) )
	;



import_line
	: 'import' import_item  (',' import_item)*  ('from' qs=QUOTED_STRING)? ';'
		-> {$qs == null}? ^(IMPORT QUOTED_STRING[""] import_item+)
			-> ^(IMPORT QUOTED_STRING[$qs, $qs.text] import_item+)
	;



import_item
	: name=FUNCTION_ID ('as' alias=FUNCTION_ID)?
		-> { $alias != null }? ^(IMPORTITEM $name $alias)
			-> ^(IMPORTITEM $name FUNCTION_ID[$name, $name.text])
	;



include_function_declaration
	: d=FDIRTY? f='function' FREF? id=FUNCTION_ID parameter_list
		-> {$d != null}? ^(FUNCTION FDIRTY[$d, "dirty"] FREF? FUNCTION_ID[$id] parameter_list ^(BODY ^(STATEMENTS)))
			-> ^(FUNCTION FREF? FUNCTION_ID[$id] parameter_list ^(BODY ^(STATEMENTS)))
	;



include_line
	: include_line1
	| include_line2
	;



include_line1
	: 'include' ft=('phtml'|'php') fn=QUOTED_STRING 'as' include_function_declaration ';'
		-> ^(INCLUDE QUOTED_STRING FREE_ID ^(INCLUDED_FUNCTION include_function_declaration))
	;



include_function_declaration_with_internal_name
	: include_function_declaration 'as' internal=QUOTED_STRING ';'
		-> ^(INCLUDED_FUNCTION include_function_declaration FREE_ID[$internal, org.apache.commons.lang.StringEscapeUtils.unescapeJava($internal.text)])
	;



include_line2
	: 'include' ft=('php') fn=QUOTED_STRING 'with' '{' include_function_declaration_with_internal_name* '}'
		-> ^(INCLUDE QUOTED_STRING FREE_ID ^(FUNCTIONS include_function_declaration_with_internal_name*))
	;



function_declaration
	scope {
		Integer loopDepth;
	}
	@init{ 
		paraphrases.push("in function declaration"); 
		$function_declaration::loopDepth = 0;
	}
	:	FDIRTY? f='function' FREF? s=FUNCTION_ID parameter_list '{' statement_list '}'
			-> ^(FUNCTION FDIRTY? FREF? FUNCTION_ID[$s] parameter_list ^(BODY ^(STATEMENTS statement_list)))
	;




parameter_list
	: '(' (parameters (',' optional_parameters)? | optional_parameters )? ')'
		-> ^(PARAMS parameters* optional_parameters*)
	;



parameters
	: parameter (',' parameter)*
		-> parameter*
	;



optional_parameters
	: optional_parameter (',' optional_parameter)*
		-> optional_parameter*
	;



parameter
	: ref='ref' id=ID
		-> ^(REF VARIABLE_ID[$id])

	| val='val' id=ID
		-> ^(VAL VARIABLE_ID[$id])
	;



optional_parameter
	: 'opt' id=ID '=' static_atom
		-> ^(OPT VARIABLE_ID[$id] static_atom)
	;



try_catch_block
	@init{ paraphrases.push("in try block"); }
	@after { paraphrases.pop(); }
	: 'try' block catch_block+
		-> ^(TRY block catch_block+)
	;



catch_block
	@init{ paraphrases.push("in catch block"); }
	@after { paraphrases.pop(); }
	: 'catch' '(' exception_id=FUNCTION_ID 'as' id=ID ')' block
		-> ^(CATCH FUNCTION_ID ID block)
	;



block
	@init{ paraphrases.push("in block"); }
	@after { paraphrases.pop(); }
	: '{' statement_list '}'
		-> ^(BLOCK ^(STATEMENTS statement_list))
	;



statement_list
	@init {
		Boolean hadStatements = false;
	}
	: (statement { hadStatements = true; })*
		-> {hadStatements}? statement*
			-> NOP
	;



statement
	@init{ paraphrases.push("in statement"); }
	@after{ if(!paraphrases.empty()) { paraphrases.pop(); } }
	: ';'
		-> NOP

	| (function_identifier '(')=> call ';'
		-> ^(VOID call)

	| ('@' var_or_array '(')=> closure_invocation ';'
		-> ^(VOID closure_invocation)

	//| expression ';'
	//	-> expression

	| 'return' expression ';'
		-> ^(RETURN expression)

	| (var_or_array ASSIGNAE? '=')=> assign_statement

	| (var_or_array ('++'|'--'))=> postfix_var_or_array

	| (('++'|'--') var_or_array)=> prefix_var_or_array

	| if_statement

	| for_statement

	| foreach_statement

	| while_statement

	| break_statement

	| continue_statement

	| block
	;



postfix_var_or_array
	: var_or_array (d='++'|d='--')
		-> ^(POSTFIX var_or_array $d)
	;



prefix_var_or_array
	: (d='++'|d='--') var_or_array
		-> ^(PREFIX var_or_array $d)
	;



assign_statement_no_semi
	:	var_or_array ae=ASSIGNAE? a='=' ref=ASSIGNREF? expression
		-> ^(ASSIGN[$a, "ASSIGN"] expression var_or_array ASSIGNREF[$ref, "ASSIGNREF"]? ASSIGNAE[$ae, "ASSIGNAE"]?)
	;



assign_statement
	:  assign_statement_no_semi ';'
		-> assign_statement_no_semi
	;



if_statement
	: 'if' '(' expression ')' s1=statement (('else')=> 'else' s2+=statement)?
		-> {$s2 != null}? ^(IF expression $s1 $s2)
			-> ^(IF expression $s1 ^(BLOCK ^(STATEMENTS NOP NOP)))
	;



for_statement
	: 'for' '(' (a1=assign_statement_no_semi|b1=block) ';' e2=expression ';' (a3=assign_statement_no_semi|b3=block) ')'
		{
			$function_declaration::loopDepth++;
		}
		s=statement
		{
			$function_declaration::loopDepth--;
		}
		-> ^(FOR $a1? $b1? $e2 $a3? $b3? $s)
	;



while_statement
 	: 'while' '(' e=expression ')' 
		{
			$function_declaration::loopDepth++;
		}
		s=statement
		{
			$function_declaration::loopDepth--;
		}
		-> ^(WHILE $e $s)
	;



foreach_statement
	: 'foreach' '(' (v=var|a=array|ad=array_declaration|c=call|cl=closure_invocation) 'as' r1=ASSIGNREF? p1=var ('=>' r2=ASSIGNREF? p2=var)? ')' 
		{
			$function_declaration::loopDepth++;
		}
		statement
		{
			$function_declaration::loopDepth--;
		}
		-> {($r1 != null) || ($r2 != null)}? ^(FOREACH $v? $a? $ad? $c? $cl? REF $p1 $p2? statement)
			-> ^(FOREACH $v? $a? $ad? $c? $cl? $p1 $p2? statement)
	;



break_statement
	@init {
		Integer level = 1;
	}
	: 'break' i=INT? ';' 
		{
			if(i != null) {
				level = Integer.parseInt($i.text);
			}
			
			if($function_declaration::loopDepth < level) {
				throw new CompileTimeException((CommonTree)adaptor.create(INT, $i), "trying to break out from too deep.");
			}
		}
		-> ^(BREAK INT[level.toString()])
	;



continue_statement
	@init {
		Integer level = 1;
	}
	: 'continue' i=INT? ';'
		{
			if(i != null) {
				level = Integer.parseInt($i.text);
			}
		
			if($function_declaration::loopDepth < level) {
				throw new CompileTimeException((CommonTree)adaptor.create(INT, $i), "trying to restart from too deep.");
			}
		}
		-> ^(CONTINUE INT[level.toString()])
	;



expression
	@init{ paraphrases.push("in expression"); }
	@after { paraphrases.pop(); }
	: or_expression
	;



or_expression
	: and_expression (('or'|'||')^ and_expression)*
	;



and_expression
	: null_coalesce_expression (('and'|'&&')^ null_coalesce_expression)*
	;



//null_coalesce_expression
//	: ternary_expression (QUESTION_AND_QUESTION ternary_expression)*
//	;



null_coalesce_expression
	: (ternary_expression QUESTION_AND_QUESTION) => null_coalesce_expression_down
	| ternary_expression
	;



null_coalesce_expression_down
	: t1=ternary_expression qq=QUESTION_AND_QUESTION t2=null_coalesce_expression
		-> ^(QUESTION_AND_QUESTION[qq] $t1 $t2)
	;



ternary_expression
	: equality_expression ( (QUESTION^ equality_expression DOUBLEDOT! equality_expression) | (QUESTION_AND_DOUBLEDOT^ equality_expression) )?
	;



equality_expression
	: comparison_expression (('=='|'!='|'==='|'!==')^ comparison_expression)*
	;



comparison_expression
	: additive_expression (('>'|'<'|'<='|'>=')^ additive_expression)*
	;



additive_expression
	: multiplicative_expression (('+'|'-'|'..')^ multiplicative_expression)*
	;



multiplicative_expression
	: not_expression (('*'|'/')^ not_expression)*
	;



not_expression
	: (op='!'|op='not')? negation_expression
		-> {$op != null}? ^(NOT[$op, "NOT"] negation_expression)
			-> negation_expression
	;



negation_expression
	: (op='-')? primary
		-> {$op != null}? ^(NEGATE[$op, "NEGATE"] primary)
			-> primary
	;



primary
	: atom

	| ('@' '(' expression ')') => expression_as_closure

	|'(' expression ')'
		-> expression
	;



static_atom
	: s=QUOTED_STRING
		-> ^(STRING[$s, "STRING"] QUOTED_STRING)

	| s=INT
		-> ^(NUM[$s, "NUM"] INT)

	| s=FLOAT
		-> ^(NUM[$s, "FLOAT"] FLOAT)

	| s='[]'
		->  ^(ARRAYDEF[$s, "ARRAYDEF"])

	| s='TRUE'
		-> ^(BOOLEAN[$s, "BOOLEAN"] TRUE)

	| s='FALSE'
		-> ^(BOOLEAN[$s, "BOOLEAN"] FALSE)
	;



atom
	: (function_identifier '(')=> call

	| var_or_array (d='++'|d='--')?
		-> {$d != null}? ^(POSTFIX var_or_array $d)
			-> var_or_array

	| prefix_var_or_array

	| array_declaration

	| ('@' var_or_array '(')=> closure_invocation

	| closure_declaration

	| function_identifier

	| static_atom
	;



expression_as_closure
	@init {
		String closureName = "";
		Integer randomSuffix = randomNumberGenerator.nextInt(100000000);
	}
	: (c='@' '(' expression ')' ) { closureName = "Closure_" + String.format("\%" + "04d", $c.getLine()) + "_" + $c.getCharPositionInLine() + "_" + randomSuffix.toString(); }
		-> ^(CLOSDEF VARIABLE_ID[$c, closureName] ^(PARAMS) ^(BODY ^(STATEMENTS ^(RETURN expression))))
	;



closure_declaration
	@init {
		String closureName = "";
		Integer randomSuffix = randomNumberGenerator.nextInt(100000000);
	}
	: FREF? c='@' f+=parameter_list? '{' statement_list '}' { closureName = "Closure_" + String.format("\%" + "04d", $c.getLine()) + "_" + $c.getCharPositionInLine() + "_" + randomSuffix.toString(); }
		-> {$f == null}? ^(CLOSDEF FREF? VARIABLE_ID[$c, closureName] ^(PARAMS) ^(BODY ^(STATEMENTS statement_list)))
			-> ^(CLOSDEF FREF? VARIABLE_ID[$c, closureName] parameter_list ^(BODY ^(STATEMENTS statement_list)))
	;



function_identifier
	: (a=FUNCTION_ID? dd=DOUBLEDOUBLEDOT)? s=FUNCTION_ID
		-> {$dd == null}? ^(FID FUNCTION_ID[$s, "Core"] FUNCTION_ID[$s])
			-> {$a == null}? ^(FID FUNCTION_ID[$s, this.library.name] FUNCTION_ID[$s])
				-> ^(FID FUNCTION_ID[$a] FUNCTION_ID[$s])
	;



call
	: fi=function_identifier '(' argument_list ')'
		-> ^(CALL[$fi.start, "CALL"] $fi argument_list)
	;



argument_list
	: (ID ':')=> named_argument_list
		-> named_argument_list

	| ordered_argument_list
		-> ordered_argument_list
	;



ordered_argument_list
	: (expression (',' expression)*)?
		-> ^(ARGS expression*)
	;



named_argument_list
	: (named_argument (',' named_argument)*)?
		-> ^(NARGS named_argument*)
	;



named_argument
	: id=ID ':' expression
		-> ^(NARG VARIABLE_ID[$id] expression)
	;



closure_invocation
	: c='@' var_or_array '(' argument_list ')'
		->^(CLOSINV[$c, "CLOSINV"] var_or_array argument_list)
	;



var_or_array
	: (var ('['|DOT))=> array
	| var
	;



var
	: by_val='$'? s=ID
		-> {$by_val == null}? ^(VAR[$s, "VAR"] VARIABLE_ID[$s] REF)
			-> ^(VAR[$s, "VAR"] VARIABLE_ID[$s] VAL)
	;



array
	: by_val='$'? s=ID array_segment+
		-> {$by_val == null}? ^(VARA[$s, "VARA"] VARIABLE_ID[$s] REF array_segment+)
			-> ^(VARA[$s, "VARA"] VARIABLE_ID[$s] VAL array_segment+)
	;



array_segment
	: (DOT id=ID)
		-> ^(STRING[$id, "STRING"] QUOTED_STRING[$id])
	| ('[' expression ']')
		-> expression
	;



array_element_declaration
	: (expression '=>')=> array_keyed_element_declaration
	| (DOT)=> array_keyed_element_declaration
	| array_keyless_element_declaration
	;



array_keyless_element_declaration
	: ref=ASSIGNREF? e1=expression
		-> ^(ARRAYELEM $e1 $ref?)
	;



array_keyed_element_declaration
	: array_element_key '=>' ref=ASSIGNREF? e2=expression
		-> ^(ARRAYELEM $e2 array_element_key $ref?)
	;



array_element_key
	: (DOT id=ID)
		-> ^(STRING[$id, "STRING"] QUOTED_STRING[$id])
	| expression
	;


array_element_declaration_list
	: array_element_declaration (',' array_element_declaration)*
		-> array_element_declaration*
	;



array_declaration
	:	s='[' array_element_declaration_list?  ']'
		-> ^(ARRAYDEF[$s, "ARRAYDEF"] array_element_declaration_list?)
	;



//---------------------------------------------------------------------------------------------
//Begin Lexer

FDIRTY: 'dirty';
FCLEAN: 'clean';
FREF: 'ref';



QUOTED_STRING
	: '"' (QUOTED_STRING_ESCAPE_SEQUENCE | ~('\\'|'"') )* '"'
		{
			setText(getText().substring(1, getText().length() - 1));
		}
	;



fragment QUOTED_STRING_ESCAPE_SEQUENCE
	: '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
	;



/*VARIABLE_ID
	:	LC(LC|'_'|DIGIT)*
	;
*/



FUNCTION_ID
	: UC(UC|LC|DIGIT)*
	;



ID
	: (UC|LC|'_')(UC|LC|'_'|DIGIT)*
	;



ID_WITH_BSLASH
	: '\\' (CHAR|'_') (CHAR|DIGIT|'_')*
	;



fragment CHAR
	: LC|UC
	;



fragment LC
	:	'a'..'z'
	;



fragment UC
	: 'A'..'Z'
	;



INT
	: '0'|('1'..'9' DIGIT*)
	;



fragment DIGIT
	: '0'..'9'
	;



FLOAT
	: INT '.' INT
	;



ASSIGNREF
	: '&'
	;



QUESTION
	: '?'
	;



QUESTION_AND_DOUBLEDOT
	: '?:'
	;



QUESTION_AND_QUESTION
	: '??'
	;



DOUBLEDOT
	: ':'
	;



DOT : '.'
	;



DOUBLEDOUBLEDOT
	: '::'
	;



ASSIGNAE
	: '[]'
	;



fragment NEWLINE
	: '\r'|'\n'
	;



WS
	: ('\t'|' '|NEWLINE)+ { $channel=HIDDEN; }
	;

COMMENT
	: '/*' (options {greedy=false;}:.)* '*/' { $channel=HIDDEN; }
	;



LINECOMMENT
	: '//' ~('\r'|'\n')* NEWLINE { $channel=HIDDEN; }
	;

//---------------------------------------------------------------------------------------------

//=============================================================================================

