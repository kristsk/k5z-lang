// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

//=============================================================================================

//---------------------------------------------------------------------------------------------
tree grammar SymbolMapperParser;
//---------------------------------------------------------------------------------------------



/* tab size is 4 spaces */



//---------------------------------------------------------------------------------------------
options {
	tokenVocab = Ast;
	ASTLabelType = CommonTree;
	output = AST;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@header {
	package lv.kristsk.k5z.antlr.parsers;

	import java.io.File;

	import org.apache.log4j.Logger;
	import org.apache.log4j.NDC;

	import java.util.Vector;
	import java.util.HashMap;
	import java.util.HashSet;

	import lv.kristsk.k5z.*;
	import lv.kristsk.k5z.utilities.*;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@members {

	//---------------------------------------------------------------------------------------------
	public Library library;

	public ArrayList<SourceError> errors = new ArrayList<SourceError>();
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
 	public SymbolMapperParser(CommonTreeNodeStream inputStream, Library library) {

		this(inputStream);
		this.library = library;
	}
	//---------------------------------------------------------------------------------------------

	//---------------------------------------------------------------------------------------------
	public void displayRecognitionError(String[] tokenNames, RecognitionException e) {

		Library.logger.debug("EEE: " + e);

		SourceError error = null;

		if(e instanceof CompileTimeException) {
			
			error = new SourceError(
				((CompileTimeException) e).commonTreeNode,
				e.getMessage(),
				library
			);
		}
		else {
			error = new SourceError(
				e,
				getErrorMessage(e, tokenNames),
				library
			);
		}

		errors.add(error);
	}
	//---------------------------------------------------------------------------------------------


	//---------------------------------------------------------------------------------------------
	
	
	//---------------------------------------------------------------------------------------------


	//---------------------------------------------------------------------------------------------
	public void isPropperFunctionName(CommonTree node, String name) throws CompileTimeException {

		if(name.indexOf('_') != -1) {
			throw new CompileTimeException(node, "'" + name + "' is not valid function name (contains underscore)");
		}
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void isKnonwImportAlias(CommonTree node, String name) throws CompileTimeException {

		if( ! library.importAliasToDefinitionMap.containsKey(name)) {
			throw new CompileTimeException(node, "library alias '" + name + "' not known");
		}
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void isPropperImportAliasName(CommonTree node, String name) throws CompileTimeException {

		if(name.indexOf('_') != -1) {
			throw new CompileTimeException(node, "'" + name + "' is not valid alias name (contains underscore)");
		}
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void isPropperVariableId(CommonTree node, String id) throws CompileTimeException {

		if(!id.toLowerCase().equals(id)) {
			throw new CompileTimeException(node, "'" + id + "' is not valid variable name (contains uppercase letters)");
		}
	}
	//---------------------------------------------------------------------------------------------
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
library
	: ^(LIBRARY
			PROGRAM?

			id=FUNCTION_ID { library.importAliasToDefinitionMap.put($id.text, library.new ImportDefinition($id.text, "")); }

			library_imports

			library_includes

			function_declarations
		)
		EOF
	;



function_declarations
	: ^(FUNCTIONS function_declaration*)
	;



library_imports
	: ^(IMPORTS library_import*)
	;



library_includes
	: ^(INCLUDES library_include*)
	;



library_include
	@init {
		Library.Include include = null;
	}
	@after{
		library.includes.put($fn.text, include);
	}
	: ^(INCLUDE fn=QUOTED_STRING ft=FREE_ID (
			one=library_include_function_declaration { 
				include = new Library.Include(library, $fn.text);
				$one.declaration.include = include;
				$one.declaration.type = Declaration.Type.PHTML_INCLUDE; 
			}
			|
			^(FUNCTIONS {
				include = new Library.IncludeWithFunctions(library, $fn.text);
			}
			(d=library_include_function_declaration { 
				$d.declaration.include = include;
				$d.declaration.type = Declaration.Type.PHP_INCLUDE;
			})*)
		))
	;



library_include_function_declaration
	returns [Declaration declaration]
	@init{
		Declaration libraryDeclaration = new Declaration();
	}
	@after{
		//libraryDeclaration.name = $name.text;

		Library.logger.debug("library_include_function_declaration: " + $name.text);

		libraryDeclaration.byRef = $ref.text != null;

		if($internal != null) {
			libraryDeclaration.setPhpName($internal.text);
		}

		libraryDeclaration.setMode(Declaration.Mode.CLEAN);

		if($dirty != null) {
			libraryDeclaration.setMode(Declaration.Mode.DIRTY);
		}

		try {
			isPropperFunctionName($name, $name.text);
			library.addDeclaration(libraryDeclaration);
		}
		catch (Exception e) {
			throw new CompileTimeException($name, "could not declare library function, " + e.toString());
		}

		$declaration = libraryDeclaration;
	}
	: ^(INCLUDED_FUNCTION 
			^(FUNCTION 
				dirty=FDIRTY?
				ref=FREF? 
				name=FUNCTION_ID { libraryDeclaration.name = $name.text; }
				^(PARAMS (parameter[libraryDeclaration])*) 
				^(BODY STATEMENTS)
			) 
			internal=FREE_ID?
		)
	;



library_import
	: ^(IMPORT
			path=QUOTED_STRING
			(
				^(IMPORTITEM id=FUNCTION_ID alias=FUNCTION_ID
					{
						if(library.importAliasToDefinitionMap.containsKey($alias.text)) {
							
							SourceError error = new SourceError(
								$alias,
								"library alias '" + $alias.text + "' is already used",
								library
							);

							errors.add(error);
						}

						//Library.logger.info("IAM: " + $alias.text + " => " + $id.text);

						library.addImportDefinition($id.text, $path.text, $alias.text);
					}
				)
			)+
		)
	;



function_declaration
	: ^(FUNCTION
			dirty=FDIRTY?
			ref=FREF?
			id=FUNCTION_ID
			{
				Declaration functionDeclaration = new Declaration();

				functionDeclaration.name = $id.text;
				//Library.logger.info("ZZZ: " + $id.text + ":: " + $ref.text);
				functionDeclaration.byRef = $ref.text != null;
				functionDeclaration.library = library;
				functionDeclaration.line = $id.getLine();
				functionDeclaration.position = $id.getCharPositionInLine();
				functionDeclaration.setMode(($dirty != null) ? Declaration.Mode.DIRTY : Declaration.Mode.AUTO);
				functionDeclaration.type = Declaration.Type.FUNCTION;
				functionDeclaration.node = $id;

				try {
					isPropperFunctionName($id, $id.text);
					
					if(library.declarations.containsKey($id.text)) {
						
						Declaration existingDeclaration = library.declarations.get($id.text);

						String errorMessage = "'" + existingDeclaration.name + "' is already defined in " + existingDeclaration.library.getLongName();

						if (existingDeclaration.line != 0) {
							errorMessage = errorMessage + ", line " + existingDeclaration.line + ":" + existingDeclaration.position;
						}

						errors.add(
							new SourceError(
								$id,
								errorMessage,
								library
							)
						);	
					}
					else {
						library.addDeclaration(functionDeclaration);
					}
				}
				catch (Exception e) {
					throw new CompileTimeException($id, e.getMessage());
				}
			}
			^(PARAMS (parameter[functionDeclaration])*)
			body[functionDeclaration]
		)
	;



parameter
	[Declaration declaration]
	@after {
		isPropperVariableId($id, $id.text);

		Variable variable = declaration.getVariable($id.text);
		//variable.access(Variable.AccessMode.WRITE, $id);
		Declaration.Parameter parameter;
		if($v != null) {
			parameter = new Declaration.Parameter(variable, Declaration.Parameter.Mode.BYVAL);
		}
		else if($r != null) {
			parameter = new Declaration.Parameter(variable, Declaration.Parameter.Mode.BYREF);
		}
		else {
			parameter = new Declaration.Parameter(variable, Declaration.Parameter.Mode.BYOPT, $e.tree);
		}
		
		parameter.number = declaration.parameters.size();
		
		declaration.parameters.add(parameter);
		declaration.parameterMap.put($id.text, parameter);
		
        Library.logger.debug("SYMBOL MAPPER DECL PARAM: " + declaration.name + " -> " + parameter);
        if($e.tree != null) {
            Library.logger.debug("SYMBOL MAPPER DECL EXPRESSION: " + $e.tree);
        }
	}
	: ^((v=VAL|r=REF|o=OPT) id=VARIABLE_ID e=expression?)
	;



body
	[Declaration declaration_in]
	scope {
		Declaration declaration;
	}
	@init {
		$body::declaration = $declaration_in;
	}
	: ^(BODY ^(STATEMENTS statement*))
	;



block
	: ^(BLOCK ^(STATEMENTS statement*))
	;



math_op
	: (a='+'|a='-'|a='/'|a='*'|a='=='|a='>='|a='<='|a='==='|a='!=='|a='!='|a='<'|a='>'|a='..')
	;



expression
	returns [Declaration.ExpressionType type]
	@init {
		$type = Declaration.ExpressionType.RVALUE;
	}
	: ^(math_op expression expression)
	| ^((QUESTION|QUESTION_AND_DOUBLEDOT) expression expression expression?)
	| ^((QUESTION_AND_QUESTION) expression expression)
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
	| closure_declaration { $type = Declaration.ExpressionType.LVALUE; }
	| var { $type = Declaration.ExpressionType.LVALUE; }
	| array { $type = Declaration.ExpressionType.LVALUE; }
	| call
	| closure_invocation
	| ^(FID alias=FUNCTION_ID id=FUNCTION_ID)
		{
			isPropperImportAliasName($alias, $alias.text);
			isKnonwImportAlias($alias, $alias.text);
			isPropperFunctionName($id, $id.text);

			Declaration.CalleeIdentity calleeIdentity = new Declaration.CalleeIdentity(
				library.importAliasToDefinitionMap.get($alias.text).name,
				$id.text,
				$id
			);

			$body::declaration.calleeIdentities.put(calleeIdentity.node, calleeIdentity);
		}
	;



statement
	: NOP
	| block
	| expression
	| ^(VOID (call|closure_invocation))
	| ^(IF expression statement statement)
	| ^(FOR statement expression statement statement)
	| ^(FOREACH (var_or_array|array_declaration|call|closure_invocation) REF? var var? statement)
	| ^(WHILE expression statement)
	| ^(RETURN expression)
	| ^((BREAK|CONTINUE) INT)
		{
			$body::declaration.setMode(Declaration.Mode.DIRTY);
			Declaration.CalleeIdentity calleeIdentity = new Declaration.CalleeIdentity(
				"Core", 
				"DirtyDummy", 
				(CommonTree)adaptor.create(CALL, "DirtyDummy")
			);

			$body::declaration.calleeIdentities.put(calleeIdentity.node, calleeIdentity);
		}
	;



array_declaration
	: ^(ARRAYDEF (^(ARRAYELEM expression+ ASSIGNREF?))*)
	;



var_or_array
	: var
	| array
	;


var
	@after {
		isPropperVariableId($id, $id.text);

		if($val == null) {
			$body::declaration.getVariable($id.text); //.access(mode, $id);
		}
		else {

			if($body::declaration.type.equals(Declaration.Type.FUNCTION)) {
 				throw new CompileTimeException($id, "can not bind by value variable '" + $id.text + "', not inside closure.");
			}

			$body::declaration.getVariable("_val_" + $id.text).bindByValue = true;
			$body::declaration.getVariable("_val_" + $id.text).bindByValueToName = $id.text;
		}
	}
	: ^(VAR id=VARIABLE_ID val=VAL? ref=REF?)
	;



array
	@after  {
		isPropperVariableId($id, $id.text);

		if($val == null) {
			$body::declaration.getVariable($id.text); //.access(mode, $id);
		}
		else {

			if($body::declaration.type.equals(Declaration.Type.FUNCTION)) {
 				throw new CompileTimeException($id, "can not bind by value variable '" + $id.text + "', not inside closure.");
			}

			$body::declaration.getVariable("_val_" + $id.text).bindByValue = true;
			$body::declaration.getVariable("_val_" + $id.text).bindByValueToName = $id.text;
		}
	}
	: ^(VARA id=VARIABLE_ID val=VAL? ref=REF? (expression)+)
	;



call
	@after {
		isPropperImportAliasName($alias, $alias.text);
		isKnonwImportAlias($alias, $alias.text);
		isPropperFunctionName($id, $id.text);

		Declaration.CalleeIdentity calleeIdentity = new Declaration.CalleeIdentity(
				library.importAliasToDefinitionMap.get($alias.text).name,
				$id.text,
				$id
			);

		$body::declaration.calleeIdentities.put(calleeIdentity.node, calleeIdentity);
	}
	: ^(CALL ^(FID alias=FUNCTION_ID id=FUNCTION_ID) (^(ARGS expression*)|^(NARGS (^(NARG VARIABLE_ID expression))*)))
	;



closure_invocation
	@after {
		$body::declaration.setMode(Declaration.Mode.DIRTY);
		Declaration.CalleeIdentity calleeIdentity = new Declaration.CalleeIdentity(
			"Core",
			"InvocateClosure",
			$closinv
		);

		$body::declaration.calleeIdentities.put(calleeIdentity.node, calleeIdentity);
	}
	: ^(closinv=CLOSINV (var_or_array) (^(ARGS expression*)|^(NARGS (^(NARG VARIABLE_ID expression))*)))
	;



closure_declaration
	@init {
		Declaration closureDeclaration = new Declaration();

		closureDeclaration.setMode(Declaration.Mode.DIRTY);
		closureDeclaration.parent = $body::declaration;
		closureDeclaration.library = library;
		closureDeclaration.type = Declaration.Type.CLOSURE;
	}
	@after {
		closureDeclaration.name = $id.text;
		closureDeclaration.byRef = $ref.text != null;
		closureDeclaration.line = $closure_declaration.start.getLine();
		closureDeclaration.position = $closure_declaration.start.getCharPositionInLine();

		try {
			library.addDeclaration(closureDeclaration);
		}
		catch (Exception e) {
			throw new CompileTimeException($id, e.getMessage());
		}

		$body::declaration.closures.put($id.text, closureDeclaration);
	}
	: ^(CLOSDEF ref=FREF? id=VARIABLE_ID (^(PARAMS (parameter[closureDeclaration])*))? body[closureDeclaration])
	;

//---------------------------------------------------------------------------------------------

//=============================================================================================

