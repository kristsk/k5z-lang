// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

//=============================================================================================

//---------------------------------------------------------------------------------------------
tree grammar EmitterParser;
//---------------------------------------------------------------------------------------------



/* tab size is 4 spaces */



//---------------------------------------------------------------------------------------------
options {
	tokenVocab = CompilerParser;
	ASTLabelType = CommonTree;
	output = template;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@header {
	package lv.kristsk.k5z.antlr.parsers;

	import java.util.HashSet;

	import org.apache.log4j.Logger;
	import org.apache.log4j.NDC;

	import org.apache.commons.lang.StringEscapeUtils;
	import org.apache.commons.lang.StringUtils;

	import org.antlr.stringtemplate.*;
	import org.antlr.stringtemplate.language.*;

	import lv.kristsk.k5z.*;
	import lv.kristsk.k5z.utilities.*;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@members {

	//---------------------------------------------------------------------------------------------
	public Library library;
	
	public ArrayList<SourceError> errors = new ArrayList<SourceError>();
	
	public ArrayList<String> declarationOutputs = new ArrayList<String>();
	
	public ArrayList<String> includedPhpFilenames = new ArrayList<String>();
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public EmitterParser(CommonTreeNodeStream input, Library library) {

		this(input);
		this.library = library;
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void displayRecognitionError(String[] tokenNames, RecognitionException e) {

		SourceError error = null;

		if(e instanceof CompileTimeException) {
			error = new SourceError(
				((CompileTimeException) e).commonTreeNode,
				e.getMessage(),
				this.library
			);
		}
		else {
			error = new SourceError(
				e,
				getErrorMessage(e, tokenNames),
				this.library
			);
		}

		errors.add(error);
	}
	//---------------------------------------------------------------------------------------------
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
library
	: ^(LIBRARY PROGRAM? FUNCTION_ID ^(INCLUDES function_declaration*) ^(FUNCTIONS function_declaration*))
		{
			StringTemplate libraryOutput = %library_output(
					name={library.name},
					declarations={declarationOutputs},
					has_initializer={library.declarations.containsKey("Initialize")},
					is_program={library.isProgram}
				);

			library.compileResult = libraryOutput.toString();
		}
		EOF
	;



function_declaration
	@init {
		String declarationResult = "";
		Library.logger.debug("QQQ2 FUNCTION DECL");
	}
	@after {
	    declarationOutputs.add(declarationResult);
	}
	: cfunction_declaration
		{
			declarationResult = $cfunction_declaration.st.toString();
		}

	| dfunction_declaration
		{
			declarationResult = $dfunction_declaration.st.toString();
		}
	| included_function_declaration
	;



included_function_declaration
    @init {
	    Declaration declaration;
    }
	:   ^(INCLUDED_FUNCTION 
	        ^(
	            (CFUNCTION|DFUNCTION) 
	            id=FUNCTION_ID
                {
                    declaration = library.declarations.get($id.text);
                }
                ^(PARAMS (parameter[declaration])* )
                ^((CBODY|DBODY) STATEMENTS)
	        )
	    )
	;



parameter
	[Declaration declaration]
	@after {
		
		if($o != null) {
			
			Declaration.Parameter parameter = declaration.parameterMap.get($id.text);
			parameter.optionalDefaultValue = $e.st.toString();
	        Library.logger.debug("QQQ2: " + declaration.name + ":" + parameter.toString() + " >> " + parameter.optionalDefaultValue);
		}
		
		if(declaration.getMode().equals(Declaration.Mode.CLEAN)) {
			
			if($v != null) {
				$st = %cparameter_val(id={$id});
			}
			else if($r != null) {
				$st = %cparameter_ref(id={$id});
			}
			else {
				$st = %cparameter_opt(id={$id}, e={$e.st});
			}
		}
	}
	: ^((v=VAL|r=REF|o=OPT) id=VARIABLE_ID e=expression?)
	;



cfunction_declaration
	@init {
		 Declaration declaration;
	}
	@after {
		
		if(declaration.include != null) {
			$st = %clean_declare_include_function(
					name={declaration.name},
					by_ref={declaration.byRef},
					php_name={declaration.getPhpName()},
					parameters={$parameters}, 
					body={declaration.include.getSafeContent()},
					with_debug_info={ ! Configuration.withoutDebug },
					include_filename={ declaration.include.getFullFilename() }
				);
		}
		else {
			$st = %clean_declare_function(
					name={declaration.name},
					by_ref={declaration.byRef},
					php_name={declaration.getPhpName()},
					parameters={$parameters}, 
					body={$b.st},
					with_debug_info={ ! Configuration.withoutDebug }
				);
		}
	}
	: ^(CFUNCTION
			id=FUNCTION_ID
			{
				declaration = library.declarations.get($id.text);
			}

			^(PARAMS (parameters+=parameter[declaration])* )
			b=body[declaration]
		)
	;



dfunction_declaration
	@init {
		 Declaration declaration;
	}
	@after {
		
		if(declaration.include != null) {
			$st = %dirty_declare_include_function(
					name={declaration.name},
					by_ref={declaration.byRef},
					php_name={declaration.getPhpName()},
					parameters={declaration.parameters},
					body={declaration.include.getSafeContent()}, 
					have_jumps={declaration.hasDirtyCallees()},
					variables={new ArrayList(declaration.variables.values())},
					with_debug_info={ ! Configuration.withoutDebug },
					callee_identities={declaration.calleeIdentities},
					include_filename={ declaration.include.getFullFilename() }
				);
		}
		else {
		
			$st = %dirty_declare_function(
					name={declaration.name},
					by_ref={declaration.byRef},
					php_name={declaration.getPhpName()},
					parameters={declaration.parameters},
					body={$b.st}, 
					have_jumps={declaration.hasDirtyCallees()},
					variables={new ArrayList(declaration.variables.values())},
					with_debug_info={ ! Configuration.withoutDebug },
					callee_identities={declaration.calleeIdentities}
				);
		}
	}
	: ^(DFUNCTION
			id=FUNCTION_ID
			{
				declaration = library.declarations.get($id.text);
			}

			^(PARAMS (parameters+=parameter[declaration])* )
			b=body[declaration]
		)
	;



body
	[Declaration declaration_in]
	scope {
		Declaration declaration;
		Stack<Integer> loopJumps;
	}
	@init{
		$body::declaration = $declaration_in;
		$body::loopJumps = new Stack<Integer>();
	}
 	: cbody
		-> {$cbody.st}
	| dbody
		-> {$dbody.st}
	;



cbody
	: ^(CBODY ^(STATEMENTS statements+=statement*))
		-> cblock(statements={$statements})
	;



dbody
	: ^(DBODY ^(STATEMENTS statements+=statement*))
		-> dblock(statements={$statements})
	;



statement
	: NOP
	
	| ^(CBLOCK ^(STATEMENTS statements+=statement*))
		-> cblock(statements={$statements})

	| ^(DBLOCK ^(STATEMENTS statements+=statement*))
		-> dblock(statements={$statements})

	| expression
		-> expression_with_semi(expression={$expression.st})

	| ^(VOID ccall)
		-> void_ccall(this_ccall={$ccall.st})

	| closure_invocation
		-> {$closure_invocation.st}

	| dcall
		-> {$dcall.st}

	| ^(CIF e=expression s1=statement s2=statement)
		-> cif(
				e={$e.st}, 
				s1={$s1.st}, 
				s2={ $s2.st.toString().length() > 0 ? $s2.st.toString() : null }
			)

	| ^(DIF e=expression s1=statement s2=statement jump=VARIABLE_ID)
		-> dif(
				e={$e.st}, 
				s1={$s1.st}, 
				s2={ $s2.st.toString().length() > 0 ? $s2.st.toString() : null }, 
				jump={Integer.parseInt($jump.text)},
				jump1={Integer.parseInt($jump.text) + 1},
				jump2={Integer.parseInt($jump.text) + 2}
			)

	| ^(CFOR s1=statement e2=expression s=statement s3=statement)
		-> cfor(
				s1={$s1.st}, 
				e2={$e2.st}, 
				s3={$s3.st}, 
				s={$s.st}
			)

	| ^(DFOR 
			jump=VARIABLE_ID 
			^(DBLOCK dfors1+=statement*) 
			^(DBLOCK e2pn+=statement*) 
			e2=expression s=statement
			{
				$body::loopJumps.push(Integer.parseInt($jump.text));
			}
			^(DBLOCK dfors3+=statement*)
			{
				$body::loopJumps.pop();
			}
		)
		-> dfor(
				s1={$dfors1}, 
				e2={$e2.st}, 
				e2pn={$e2pn}, 
				s3={$dfors3}, 
				s={$s.st}, 
				jump={Integer.parseInt($jump.text)},
				jump1={Integer.parseInt($jump.text) + 1},
				jump2={Integer.parseInt($jump.text) + 2}
			)

	| ^(CFOREACH (v=var|array|array_definition|call|closure_invocation) ref=REF? p1=var p2=var? s=statement)
		-> cforeach(
				v={$v.st}, 
				a={$array.st}, 
				ad={$array_definition.st}, 
				c={$call.st}, 
				cl={$closure_invocation.st}, 
				p1={$p1.st}, 
				p2={$p2.st}, 
				s={$s.st}, 
				ref={$ref}
			)

	| ^(DFOREACH 
			jump=VARIABLE_ID 
			(v=var|array|array_definition|call|closure_invocation) 
			ref=REF? 
			p1=var
			p2=var? 
			{
				$body::loopJumps.push(Integer.parseInt($jump.text));
			}
			s=statement
			{
				$body::loopJumps.pop();
			}
		)
		-> dforeach(
				v={$v.st}, 
				a={$array.st}, 
				ad={$array_definition.st}, 
				c={$call.st}, 
				cl={$closure_invocation.st}, 
				p1={$p1.st}, 
				p2={$p2.st}, 
				s={$s.st},
				ref={$ref},
				jump={Integer.parseInt($jump.text)}, 
				jump1={Integer.parseInt($jump.text) + 1},
				jump2={Integer.parseInt($jump.text) + 2}
			)

	| ^(CWHILE e=expression s=statement)
		-> cwhile(
				e={$e.st}, 
				s={$s.st}
			)

	| ^(DWHILE 
			jump=VARIABLE_ID 
			^(DBLOCK pn+=statement*) 
			e=expression 
			{
				$body::loopJumps.push(Integer.parseInt($jump.text));
			}
			s=statement
			{
				$body::loopJumps.pop();
			}
		)
		-> dwhile(
				e={$e.st}, 
				s={$s.st}, 
				pn={$pn}, 
				jump={Integer.parseInt($jump.text)},
				jump1={Integer.parseInt($jump.text) + 1},
				jump2={Integer.parseInt($jump.text) + 2}
			)

	| ^(CRETURN expression)
		-> creturn(e={$expression.st})

	| dreturn_statement 
		-> {$dreturn_statement.st}

	| ^(CBREAK i=INT)
		-> cbreak(e={$i.text})

	| dbreak_statement
		-> {$dbreak_statement.st}

	| ^(CCONTINUE i=INT)
		-> ccontinue(e={$i.text})

	| dcontinue_statement
		-> {$dcontinue_statement.st}
	;



dbreak_statement
	@init{
		Integer level = 0;
		Integer label = 0;
	}
	: ^(DBREAK i=INT)
		{
			level = Integer.parseInt($i.text);
			label = $body::loopJumps.get($body::loopJumps.size() - level) + 2;
		}
		-> dbreak(l={label.toString()})
	;



dcontinue_statement
	@init{
		Integer level = 0;
		Integer label = 0;
	}
	: ^(DCONTINUE i=INT)
		{
			level = Integer.parseInt($i.text);
			label = $body::loopJumps.get($body::loopJumps.size() - level) + 1;
		}
		-> dcontinue(l={label.toString()})
	;


dreturn_statement
	: ^(DRETURN expression)
	{
		Declaration declaration = $body::declaration;
		
		$st = %dreturn(
			e={$expression.st}
		);
	}	
	;


expression_op
	: (a='+'|a='-'|a='/'|a='*'|a='=='|a='>='|a='<='|a='!='|a='==='|a='!=='|a='<'|a='>'|a='or'|a='and'|a='||'|a='&&')
		-> op(t={$a})
	| (b='..')
		-> op(t={"."})
	;



expression
	: (^(DBGSRCL line=INT position=INT))?
		expression_inner
		{
			if(Configuration.withoutDebug == false) {
				$st = %dbgsrc(type={"L"}, line={$line.text}, position={$position.text}, e={$expression_inner.st});
			}
			else {
				$st = $expression_inner.st;
			}
		}
	;



expression_inner
	: ^(op+=expression_op ea+=expression eb+=expression)
		-> expression_op(op={$op}, a_e={$ea}, b_e={$eb})

	| ^(STRING QUOTED_STRING)
		{
			// Library.logger.info("QUOTED_STRING: 0<<<" + $QUOTED_STRING.text + ">>>");
			String sss1 = StringUtils.replace($QUOTED_STRING.text, "'", "\\'");
			// Library.logger.info("QUOTED_STRING: 1<<<" + sss1 + ">>>");
		  	String sss2 = StringUtils.replace(sss1, "\\\"", "\"");
			// Library.logger.info("QUOTED_STRING: 2<<<" + sss2 + ">>>");
			String sss3 = StringUtils.replace(sss2, "\\n", "'.\"\\n\".'");
			// Library.logger.info("QUOTED_STRING: 3<<<" + sss3 + ">>>");
		}
		-> expression_string(s={sss3})

	| ^(ASSIGN e=expression var_or_array ref=ASSIGNREF? ae=ASSIGNAE?)
		-> expression_assign(t={$var_or_array.st}, e={$e.st}, ref={$ref.text}, ae={$ae.text})

	| ^(type=(QUESTION|QUESTION_AND_DOUBLEDOT) c=expression e1=expression e2=expression?)
		-> expression_ternary(type={$type.text}, c={$c.st}, e1={$e1.st}, e2={$e2.st})

	| ^(QUESTION_AND_QUESTION e1=expression e2=expression)
		-> expression_null_coalesce(e1={$e1.st}, e2={$e2.st})

	| ^(NUM INT)
		-> expression_int(i={$INT.text})

	| ^(NUM FLOAT)
		-> expression_float(f={$FLOAT.text})

	| ^(NEGATE e=expression)
		-> expression_negate(e={$e.st})

	| ^(NOT e=expression)
		-> expression_not(e={$e.st})

	| ^(POSTFIX var_or_array (d='--'|d='++'))
		-> expression_postfix(v={$var_or_array.st}, d={$d.text})

	| ^(PREFIX var_or_array (d='--'|d='++'))
		-> expression_prefix(v={$var_or_array.st}, d={$d.text})

	| ^(BOOLEAN (b=TRUE|b=FALSE))
		-> expression_boolean(b={$b.text})

	| array_definition
		-> {$array_definition.st}

	| var
		-> {$var.st}

	| array
		-> {$array.st}

	| ccall
		-> {$ccall.st}

	| closure_declaration
		-> {$closure_declaration.st}

	| fid=function_identifier
		{
			Declaration declaration = $fid.declaration;
		}
		-> function_as_value(
				php_name={declaration.getPhpName()},
				dirty={declaration.getMode().equals(Declaration.Mode.DIRTY)}
			)
	;



array_definition
	: ^(ARRAYDEF ades+=array_definition_element*)
		-> array_definition(ades={$ades})
	;



var_or_array
	@after{
		if($a.st == null) {
			$st = $v.st;
		}
		else {
			$st = $a.st;
		}
	}
	: (v=var | a=array)
	;



var
	: cvar
		-> {$cvar.st}
		
	| dvar
		-> {$dvar.st}
	;



cvar
	: ^(CVAR id=VARIABLE_ID)
		-> cvar(id={$id.text})
	;



dvar
	: ^(DVAR id=VARIABLE_ID)
		-> dvar(id={$body::declaration.getVariable($id.text).getId()})
	;



array
	: carray
		-> {$carray.st}
		
	| darray
		-> {$darray.st}
	;



array_definition_element
	: ^(ARRAYELEM value=expression key=expression? ref=ASSIGNREF?)
		-> {$ref != null}? array_definition_element(value={$value.st}, key={$key.st}, ref={$ref})
			-> array_definition_element(value={$value.st}, key={$key.st})
	;



carray
	: ^(CVARA id=VARIABLE_ID e+=expression+)
		-> carray(id={$id.text}, idx={$e})
	;



darray
	: ^(DVARA id=VARIABLE_ID e+=expression+)
		-> darray(id={$body::declaration.getVariable($id.text).getId()}, idx={$e})
	;



call
	: ccall
		-> {$ccall.st}
	// | dcall
	//	-> {$dcall.st}
	;



named_argument
	returns [String name]
	@after {
	 	$name = $id.text;
		$st = $e.st;
	}
	: ^(NARG id=VARIABLE_ID e=expression)
	;



ccall
	@init {
		HashMap<String, StringTemplate> namedArguments = new HashMap<String, StringTemplate>();
	}
	@after {
		Declaration callee = $fid.declaration;
		
		//Library.logger.info("ZZZ2: " + callee.getPhpName() + ":: " + callee.byRef);

		if($nargs != null) {

			ArrayList<String> argumentValueList = new ArrayList<String>();

			for(Declaration.Parameter parameter: callee.parameters) {

				String argumentValue;

				if(namedArguments.containsKey(parameter.variable.name)) {

					argumentValue = namedArguments.get(parameter.variable.name).toString();
				}
				else {

					if(parameter.optionalDefaultValueNode != null && parameter.optionalDefaultValue == null) {

						TreeNodeStream z = this.getTreeNodeStream();

						this.setTreeNodeStream(new CommonTreeNodeStream(parameter.optionalDefaultValueNode));
						EmitterParser.expression_return expression_return = this.expression();

						this.setTreeNodeStream(z);

						parameter.optionalDefaultValue = expression_return.toString();
					}
					
					argumentValue = parameter.optionalDefaultValue;
				}
				
				argumentValueList.add(argumentValue);
			}
			
			$st = %ccall(
					by_ref={callee.byRef},
					php_name={callee.getPhpName()}, 
					arguments={argumentValueList}
				);
		}
		else {
			$st = %ccall(
					by_ref={callee.byRef},
					php_name={callee.getPhpName()},
					arguments={$arguments}
				);
		}
	}
	: ^(CCALL
			fid=function_identifier
			(
				^(ARGS arguments+=argument*) |
				^(nargs=NARGS
					(
						named_argument
						{
							namedArguments.put($named_argument.name, $named_argument.st);
						}
					)*
				)
			)
		)
 	;



function_identifier
	returns [Declaration declaration]
	@after {
		String libraryName = library.importAliasToDefinitionMap.get($alias.text).name;
		
		$declaration = lv.kristsk.k5z.Compiler.knownLibraries.get(libraryName).declarations.get($id.text);
	}
	: ^(FID alias=FUNCTION_ID id=FUNCTION_ID)
	;



dcall
	@init{
		Declaration callee;

 		ArrayList<StringTemplate> argumentArrayElements = new ArrayList<StringTemplate>();
		Boolean haveNamedArguments = null;
	}
	: ^(d=DCALL
			fid=function_identifier 
			{
			 	callee = $fid.declaration;
			
				// Check and get any missing optional default values
				for(Declaration.Parameter parameter: callee.parameters) {
					if(parameter.optionalDefaultValueNode != null && parameter.optionalDefaultValue == null) {

						TreeNodeStream z = this.getTreeNodeStream();

						this.setTreeNodeStream(new CommonTreeNodeStream(parameter.optionalDefaultValueNode));
						EmitterParser.expression_return expression_return = this.expression();

						this.setTreeNodeStream(z);

						parameter.optionalDefaultValue = expression_return.toString();
					}
				}
			}
			(
				^(ARGS 
					{
						haveNamedArguments = false;
						
						HashMap<Integer, StringTemplate> hm = new HashMap<Integer, StringTemplate>();
						
						for(Declaration.Parameter parameter: callee.parameters) {
							
							hm.put(parameter.number, %array_definition_element(
								value={parameter.optionalDefaultValue},
								ref={parameter.mode.equals(Declaration.Parameter.Mode.BYREF)}
							));
						}

					    Library.logger.debug("DCALL ARG HM 1: " + hm);

						Integer argumentCounter = 0;
					}
					(
						argument
						{
							Declaration.Parameter parameter = callee.parameters.get(argumentCounter++);

							hm.put(parameter.number, %array_definition_element(
								value={$argument.st},
								ref={parameter.mode.equals(Declaration.Parameter.Mode.BYREF)}
							));
						}
					)*
					{
						for(Declaration.Parameter parameter: callee.parameters) {
							argumentArrayElements.add(hm.get(parameter.number));
						}

					    Library.logger.debug("DCALL ARG HM 2: " + hm);
					    Library.logger.debug("DCALL ARG CALLEE PARAMETERS: " + callee.parameters);
						Library.logger.debug("DCALL ARG ARGUENT COUNTER: " + argumentCounter);
					    Library.logger.debug("DCALL ARG ARGUMENT ARRAY: " + argumentArrayElements);
					}
				)
				|
				^(NARGS
					{
						haveNamedArguments = true; 
						
						HashMap<String, StringTemplate> hm = new HashMap<String, StringTemplate>();
						
						for(Declaration.Parameter parameter: callee.parameters) {
							hm.put(parameter.variable.name, %array_definition_element(
								key={"'" + parameter.variable.name + "'"},
								value={parameter.optionalDefaultValue},
								ref={parameter.mode.equals(Declaration.Parameter.Mode.BYREF)}
							));
						}
					}
					(
						named_argument
						{
							Declaration.Parameter parameter = callee.parameterMap.get($named_argument.name);

							hm.put(parameter.variable.name, %array_definition_element(
								key={"'" + parameter.variable.name + "'"},
								value={$named_argument.st},
								ref={parameter.mode.equals(Declaration.Parameter.Mode.BYREF)}
							));
						}
					)*
					{
						for(Declaration.Parameter parameter: callee.parameters) {
							argumentArrayElements.add(hm.get(parameter.variable.name));
						}
					}
				)
			)
			jump=VARIABLE_ID
		)
		{
			StringTemplate argumentArray = %array_definition(ades={argumentArrayElements});

			HashSet<Integer> notGarbageVariables = new HashSet<Integer>();
			HashSet<Integer> garbageVariables = new HashSet<Integer>();

			for(Variable v: $body::declaration.calleeCfgVertices.get(fid.start).outs) {
				notGarbageVariables.add(v.getId());
			}

			for(Variable variable: $body::declaration.variables.values()) {
				
				if(variable.neverGarbage) {
					notGarbageVariables.add(variable.getId());
				}
				
				if(!notGarbageVariables.contains(variable.getId())) {
					garbageVariables.add(variable.getId());
				}
			}
		}
		-> dcall(
				by_ref={callee.byRef},
				jump={$jump}, 
				php_name={callee.getPhpName()}, 
				arguments={argumentArray}, 
				not_garbage={notGarbageVariables},
				garbage={garbageVariables},
				have_named_arguments={haveNamedArguments}
			)
	;



closure_invocation
	@init{
		ArrayList<StringTemplate> argumentArrayElements = new ArrayList<StringTemplate>();
		
		Boolean haveNamedArguments = false;
	}
	: ^(c=CLOSINV
			id=var_or_array
			(
				^(ARGS
					(
						^((ref=REF|val=VAL) expression)
						{
							argumentArrayElements.add(%array_definition_element(
								value={$expression.st},
								ref={$ref != null)}
							);

							$val = null;
							$ref = null;
						}
					)*
				)
				|
				^(nargs=NARGS
					{
						haveNamedArguments = true;
					}
					(
						^((ref=REF|val=VAL)
							named_argument
							{
								argumentArrayElements.add(%array_definition_element(
									key={"'" + $named_argument.name + "'"},
									value={$named_argument.st},
									ref={$ref != null}
								));

								$val = null;
								$ref = null;
							}
						)
					)*
				)
			)
			jump=VARIABLE_ID
		)
		{
			StringTemplate argumentArray = %array_definition(ades={argumentArrayElements});

			ArrayList<Integer> notGarbageVariables = new ArrayList<Integer>();
			HashSet<Integer> garbageVariables = new HashSet<Integer>();
			
			for(Variable variable: $body::declaration.calleeCfgVertices.get($c).outs) {
				notGarbageVariables.add(variable.getId());
			}

			for(Variable variable: $body::declaration.variables.values()) {
				
				if(variable.neverGarbage) {
					notGarbageVariables.add(variable.getId());
				}
				
				if(!notGarbageVariables.contains(variable.getId())) {
					garbageVariables.add(variable.getId());
				}
			}
		}
		-> closure_invocation(
				ref={$body::declaration.byRef},
				variable={$id.st},
				jump={$jump},
				have_named_arguments={haveNamedArguments},
				arguments={argumentArray},
				not_garbage={notGarbageVariables},
				garbage={garbageVariables}
			)
	;



argument
	: expression
		-> {$expression.st}
	;



closure_declaration
	@init {
		Declaration closureDeclaration;
	}
	: ^(CLOSDEF
			id=VARIABLE_ID
			{
				closureDeclaration = library.declarations.get($id.text);
			}

			^(PARAMS (parameters+=parameter[closureDeclaration])*)

			body[closureDeclaration]
		)
		{
			ArrayList<StringTemplate> initialFrameArrayElements = new ArrayList<StringTemplate>();
			ArrayList<StringTemplate> initialDummyFrameArrayElements = new ArrayList<StringTemplate>();

			Library.logger.debug("DECIDING CLOSURE FRAME FOR " + closureDeclaration.getPhpName());
				
		 	for(Variable variable: closureDeclaration.variables.values()) {
			
				Library.logger.debug("VARIABLE " + variable.getId() + " (" + variable.name + "): " +
					" " + (variable.temporary ? "IS TEMPORARY; " : "") +
				 	"PARENT: " + variable.getParent().declaration.getPhpName() + "/" + variable.getParent().getId());

				if(variable.getParent().equals(variable) || variable.temporary) {
					continue;
				}

				StringTemplate value;
				StringTemplate frameValue;

				if($body::declaration.getMode().equals(Declaration.Mode.DIRTY)) {
					value = %dvar(id={variable.getParent().getId()});
				}
				else {
					value = %cvar(id={variable.getParent().name});
				}

				if(variable.bindByValue == false) {
					frameValue = %by_ref(item={value});
				}
				else {
					frameValue = value;
				}

				initialFrameArrayElements.add(%array_definition_element(
						key={variable.getId()}, 
						value={frameValue}
				));

				StringTemplate dummyFrameValue = %by_ref(item={value});
				initialDummyFrameArrayElements.add(%array_definition_element(
					value={dummyFrameValue}
				));
			}

			StringTemplate initialFrameArray = %array_definition(ades={initialFrameArrayElements});
			StringTemplate initialDummyFrameArray = %array_definition(ades={initialDummyFrameArrayElements});

			declarationOutputs.add(
				(%dirty_declare_function(
					ref={closureDeclaration.byRef},
					name={closureDeclaration.name},
					php_name={closureDeclaration.getPhpName()},
					parameters={closureDeclaration.parameters},
					body={$body.st},
					have_jumps={closureDeclaration.hasDirtyCallees()},
					variables={new ArrayList(closureDeclaration.variables.values())},
					with_debug_info={!Configuration.withoutDebug},
					callee_identities={closureDeclaration.calleeIdentities}
				)).toString()
			);
		}
		-> declare_closure(
				php_name={closureDeclaration.getPhpName()},
				initial_frame={initialFrameArray},
				initial_dummy_frame={initialDummyFrameArray}
			)
	;
//---------------------------------------------------------------------------------------------



//=============================================================================================
