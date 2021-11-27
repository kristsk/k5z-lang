// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>.
 All rights reserved.
// SPDX-License-Identifier: MIT

//=============================================================================================

//---------------------------------------------------------------------------------------------
tree grammar VariableAccessMapperParser;
//---------------------------------------------------------------------------------------------



/* tab size is 4 spaces */



//---------------------------------------------------------------------------------------------
options {
	tokenVocab = CompilerParser;
	ASTLabelType = CommonTree;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@header {
	package lv.kristsk.k5z.antlr.parsers;

	import java.util.HashMap;
	import java.util.Vector;
	import java.util.Map;
	import java.util.HashSet;
	import java.util.Set;

	import java.io.*;
	import org.apache.log4j.Logger;
	import org.apache.log4j.NDC;

	import org.jgrapht.ext.*;

	import lv.kristsk.k5z.*;
	import lv.kristsk.k5z.utilities.*;

	import org.antlr.runtime.tree.CommonTree;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@members {

	//---------------------------------------------------------------------------------------------
	public Library library;

	public ArrayList<SourceError> errors = new ArrayList<SourceError>();
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public VariableAccessMapperParser(CommonTreeNodeStream inputStream, Library library) {

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
	: ^(LIBRARY PROGRAM? id=FUNCTION_ID ^(INCLUDES .*) ^(FUNCTIONS function_declaration*)) EOF
	;



function_declaration
	: ^((CFUNCTION|DFUNCTION)
			id=FUNCTION_ID
			{
				Declaration declaration = library.declarations.get($id.text);
				
				Library.logger.debug("START FD: " + declaration.name);
				NDC.push(" ");

				CfgVertex startVertex = new CfgVertex("START");
				declaration.cfg.addVertex(startVertex);
				declaration.startCfgVertex = startVertex;
				declaration.lastCfgVertex = startVertex;
				
				//Library.logger.debug("lastCfgVertex: " + declaration.lastCfgVertex);

			}
			^(PARAMS (parameter[declaration])* )
			body[declaration]
		)
		{
			CfgVertex declarationEnd = new CfgVertex("END");
			declaration.addCfgEdge(declaration.lastCfgVertex, declarationEnd);

			NDC.pop();
			Library.logger.debug("END FD: " + declaration.name);

		}
	;



parameter
 	[Declaration declaration]
	@after {
		//$declaration.getVariable($id.text).access(Variable.AccessMode.WRITE, $id);
		declaration.addCfgEdge(
			declaration.lastCfgVertex,
			new CfgVertex(declaration.getVariable($id.text), Variable.AccessMode.WRITE, $id)
		);
	}
	: ^((VAL|REF|OPT) id=VARIABLE_ID expression?)
	;



block
	: ^((CBLOCK|DBLOCK) ^(STATEMENTS statement*))
	;



body
	[Declaration declaration_in]
	scope {
		Declaration declaration;
	}
	@init {
		$body::declaration = $declaration_in;
	}
	: ^((CBODY|DBODY) ^(STATEMENTS statement*))
	;



statement
	scope {
		Variable jumpVariable;
	}
	: NOP
	| block
	| expression
	| ^(VOID call)
	| ^(CIF
			expression
			{
				//Library.logger.warn("CIFSTART"); NDC.push(" ");
				CfgVertex ifStart = new CfgVertex("IFSTART");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					ifStart);
			}

			statement
			{
				//NDC.pop(); Library.logger.warn("CIFELSE"); NDC.push(" ");
				CfgVertex b1 = $body::declaration.lastCfgVertex;
				$body::declaration.lastCfgVertex = ifStart;
			}

			statement
			{
				//Library.logger.warn("CIFEND"); NDC.push(" ");

				CfgVertex ifEnd = new CfgVertex("IFEND");
				$body::declaration.cfg.addVertex(ifEnd);

				$body::declaration.cfg.addEdge(b1, ifEnd);
				$body::declaration.cfg.addEdge($body::declaration.lastCfgVertex, ifEnd);

				$body::declaration.lastCfgVertex = ifEnd;
			}
		)

	| ^(DIF
			expression
			{
				//Library.logger.warn("DIFSTART"); NDC.push(" ");
				CfgVertex ifStart = new CfgVertex("IFSTART");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					ifStart);
			}

			statement
			{
				//NDC.pop(); Library.logger.warn("DIFELSE"); NDC.push(" ");
				CfgVertex b1 = $body::declaration.lastCfgVertex;
				$body::declaration.lastCfgVertex = ifStart;
			}

			statement
			{
				//Library.logger.warn("DIFEND"); NDC.push(" ");
				CfgVertex ifEnd = new CfgVertex("IFEND");
				$body::declaration.cfg.addVertex(ifEnd);

				$body::declaration.cfg.addEdge(b1, ifEnd);
				$body::declaration.cfg.addEdge($body::declaration.lastCfgVertex, ifEnd);

				$body::declaration.lastCfgVertex = ifEnd;
			}

			VARIABLE_ID
		)

	| ^(CFOR
			statement
			{
				//Library.logger.warn("CFORSTART"); NDC.push(" ");
				CfgVertex forCheck = new CfgVertex("CFOR_CHECK");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					forCheck
				);
			}

			expression
			{
				//Library.logger.warn("CFORSTART"); NDC.push(" ");
				CfgVertex forCheckEnd = new CfgVertex("CFOR_CHECK_END");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					forCheckEnd
				);
			}

			statement

			statement
			{
				//NDC.pop(); Library.logger.warn("DFOREND");
				$body::declaration.cfg.addEdge(
					$body::declaration.lastCfgVertex,
					forCheck
				);

				$body::declaration.lastCfgVertex = forCheckEnd;
			}
		)

	| ^(dfor=DFOR
			jump_var=VARIABLE_ID
			{
				$statement::jumpVariable = $body::declaration.getVariable("DFOR_JUMP_" + $jump_var.text);
				$statement::jumpVariable.setId(new Integer($jump_var.text));
			}

			^(DBLOCK statement*)
			{
				CfgVertex forCheck = new CfgVertex("DFOR_CHECK");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					forCheck
				);

				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					new CfgVertex($statement::jumpVariable, Variable.AccessMode.WRITE, $dfor)
				);
			}

			^(DBLOCK statement*)

			expression
			{
				//Library.logger.warn("DFORSTART"); NDC.push(" ");
				CfgVertex forCheckEnd = new CfgVertex("DFOR_CHECK_END");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					forCheckEnd
				);
			}

			statement

			^(DBLOCK statement*)
			{
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					new CfgVertex($statement::jumpVariable, Variable.AccessMode.READ, $dfor)
				);

				$body::declaration.cfg.addEdge(
					$body::declaration.lastCfgVertex,
					forCheck
				);

				$body::declaration.lastCfgVertex = forCheckEnd;
			}
		)

	| ^(CFOREACH
			(var[Variable.AccessMode.READ]|array[Variable.AccessMode.READ]|array_declaration|call|closure_invocation)
			{
				//Library.logger.warn("CFOREACHFETCH"); NDC.push(" ");
				CfgVertex foreachFetch = new CfgVertex("CFOREACH_FETCH");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					foreachFetch
				);
				
				CfgVertex foreachCheck = new CfgVertex("CFOREACH_CHECK");
				$body::declaration.addCfgEdge(
					foreachFetch,
					foreachCheck
				);
			}

			REF?
			var[Variable.AccessMode.WRITE]
			var[Variable.AccessMode.WRITE]?
			{
				//NDC.pop(); Library.logger.warn("CFOREACHSTART");
				CfgVertex foreachFetchEnd = new CfgVertex("CFOREACH_FETCH_END");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					foreachFetchEnd
				);
			}

			statement
			{
				//NDC.pop(); Library.logger.warn("CFOREACHEND");
				$body::declaration.cfg.addEdge(
					$body::declaration.lastCfgVertex,
					foreachFetch
				);

				$body::declaration.lastCfgVertex = foreachCheck;
			}
		)

	| ^(dforeach=DFOREACH
			jump_var=VARIABLE_ID
			{
				$statement::jumpVariable = $body::declaration.getVariable("DFOREACH_JUMP_" + $jump_var.text);
				$statement::jumpVariable.setId(new Integer($jump_var.text));
			}

			(var[Variable.AccessMode.READ]|array[Variable.AccessMode.READ]|call|array_declaration|closure_invocation)
			{
				//Library.logger.warn("DFOREACHFETCH"); NDC.push(" ");
				CfgVertex foreachFetch = new CfgVertex("DFOREACH_FETCH");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					foreachFetch
				);

				CfgVertex foreachCheck = new CfgVertex("DFOREACH_CHECK");
				$body::declaration.addCfgEdge(
					foreachFetch,
					foreachCheck
				);
			}

			REF? 
			var[Variable.AccessMode.WRITE]
			var[Variable.AccessMode.WRITE]? 

			{
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					new CfgVertex($statement::jumpVariable, Variable.AccessMode.WRITE, $dforeach)
				);
			}

			statement
			{
				//NDC.pop(); Library.logger.warn("DFOREACHEND");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					new CfgVertex($statement::jumpVariable, Variable.AccessMode.READ, $dforeach)
				);

				$body::declaration.cfg.addEdge(
					$body::declaration.lastCfgVertex,
					foreachFetch
				);
				
				$body::declaration.lastCfgVertex = foreachCheck;
			}
		)

	| ^(CWHILE
			{
				//Library.logger.warn("DWHILESTEST"); NDC.push(" ");
				CfgVertex whileCheck = new CfgVertex("CWHILE_CHECK");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					whileCheck
				);
			}

			expression
			{
				//Library.logger.warn("DWHILESTART"); NDC.push(" ");
				CfgVertex whileCheckEnd = new CfgVertex("CWHILE_CHECK_END");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					whileCheckEnd
				);
			}

			statement
			{
				//NDC.pop(); Library.logger.warn("DWHILEEND");
				$body::declaration.cfg.addEdge(
					$body::declaration.lastCfgVertex,
					whileCheck
				);

				$body::declaration.lastCfgVertex = whileCheckEnd;
			}
		)

	| ^(dwhile=DWHILE
			jump_var=VARIABLE_ID
			{
				$statement::jumpVariable = $body::declaration.getVariable("DWHILE_JUMP_" + $jump_var.text);
				$statement::jumpVariable.setId(new Integer($jump_var.text));

				//Library.logger.warn("DWHILESTEST"); NDC.push(" ");
				CfgVertex whileCheck = new CfgVertex("DWHILE_CHECK");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					whileCheck
				);

				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					new CfgVertex($statement::jumpVariable, Variable.AccessMode.WRITE, $dwhile)
				);
			}

			^(DBLOCK statement*) expression
			{
				//Library.logger.warn("DWHILESTART"); NDC.push(" ");
				CfgVertex whileCheckEnd = new CfgVertex("DWHILE_CHECK_END");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					whileCheckEnd
				);
			}

			statement
			{
				//NDC.pop(); Library.logger.warn("DWHILEEND");
				$body::declaration.addCfgEdge(
					$body::declaration.lastCfgVertex,
					new CfgVertex($statement::jumpVariable, Variable.AccessMode.READ, $dwhile)
				);

				$body::declaration.cfg.addEdge(
					$body::declaration.lastCfgVertex,
					whileCheck
				);

				$body::declaration.lastCfgVertex = whileCheckEnd;
			}
 		)

	| ^((CRETURN|DRETURN) expression)

	| ^(CBREAK INT)

	| ^(DBREAK
			{
				//{ Library.logger.warn("DBREAK"); NDC.push(" "); $body::declaration.setDbreak($DBREAK); }
			}
			INT
		)

	| ^(CCONTINUE INT)

	| ^(DCONTINUE
			{
				//{ Library.logger.warn("DCONTINUE"); NDC.push(" "); $body::declaration.setDcontinue($DCONTINUE); }
			}
			INT
		)
	;



math_op
	: (a='+'|a='-'|a='/'|a='*'|a='=='|a='>='|a='<='|a='!='|a='==='|a='!=='|a='<'|a='>'|a='..')
	;



expression
	: (^(DBGSRCL INT INT))? expression_inner
	;



expression_inner
	: ^(math_op expression expression)
	| ^((QUESTION|QUESTION_AND_DOUBLEDOT) expression expression expression?)
	| ^(QUESTION_AND_QUESTION expression expression)
	| ^(STRING QUOTED_STRING)
	| ^(ASSIGN expression (var[Variable.AccessMode.WRITE]|array[Variable.AccessMode.READWRITE]) ASSIGNREF? ASSIGNAE?)
	| ^(NUM INT)
	| ^(NUM FLOAT)
	| ^(NEGATE expression)
	| ^(NOT expression)
	| ^(POSTFIX (var[Variable.AccessMode.READWRITE]|array[Variable.AccessMode.READWRITE]) ('--'|'++'))
	| ^(PREFIX (var[Variable.AccessMode.READWRITE]|array[Variable.AccessMode.READWRITE]) ('--'|'++'))
	| ^(BOOLEAN (TRUE|FALSE))
	| ^(('&&'|'and'|'||'|'or') expression expression)
	| array_declaration
	| ^(ISSET .)
	| closure_declaration
	| var[Variable.AccessMode.READ]
	| array[Variable.AccessMode.READ]
	| call
	| closure_invocation
	| ^(FID FUNCTION_ID FUNCTION_ID)
	;



array_declaration
	: ^(ARRAYDEF (^(ARRAYELEM expression+ ASSIGNREF?))*)
	;



var
	[Variable.AccessMode accessMode]
	@after {
		//$body::declaration.getVariable($id.text).access(accessMode, $id);
		Variable v = $body::declaration.getVariable($id.text);

		if(accessMode == Variable.AccessMode.READWRITE) {
			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				new CfgVertex(v, Variable.AccessMode.READ, $id)
			);
			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				new CfgVertex(v, Variable.AccessMode.WRITE, $id)
			);
		}
		else {
			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				new CfgVertex(v, accessMode, $id)
			);
		}
	}
	: ^((CVAR|DVAR) id=VARIABLE_ID)
	;



array
	[Variable.AccessMode accessMode]
	@after {
		//$body::declaration.getVariable($id.text).access(accessMode, $id);
		Variable v = $body::declaration.getVariable($id.text);

		if(accessMode == Variable.AccessMode.READWRITE) {
			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				new CfgVertex(v, Variable.AccessMode.READ, $id)
			);
			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				new CfgVertex(v, Variable.AccessMode.WRITE, $id)
			);
		}
		else {
			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				new CfgVertex(v, accessMode, $id)
			);
		}
	}
	: ^((CVARA|DVARA) id=VARIABLE_ID expression+)
	;



call
	@after {
		if($result_id != null) {

			//Library.logger.warn("DCALL " + $fid.text + " / " + $dcall + "@" + Integer.toHexString(System.identityHashCode($dcall)));
			//$body::declaration.dirtyCallAccess($dcall);
			//$body::declaration.getVariable($result_id.text).access(Variable.AccessMode.WRITE, $fid);
			CfgVertex dcallCfgVertex = new CfgVertex("D" + $fid);

			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				dcallCfgVertex
			);

			$body::declaration.addCfgEdge(
				$body::declaration.lastCfgVertex,
				new CfgVertex($body::declaration.getVariable($result_id.text), Variable.AccessMode.WRITE, $fid)
			);

			$body::declaration.calleeCfgVertices.put($fid, dcallCfgVertex);
		}
	}
	: ^((dcall=DCALL|CCALL) ^(fid=FID alias=FUNCTION_ID id=FUNCTION_ID) (^(ARGS expression*) | (^(NARGS (^(NARG VARIABLE_ID expression))* )) ) result_id=VARIABLE_ID?)
	;



closure_invocation
	@after {
		//Library.logger.warn("CLOSINV");
		//$body::declaration.dirtyCallAccess($closinv);
		//$body::declaration.getVariable($result_id.text).access(Variable.AccessMode.WRITE, $closinv);

		CfgVertex invocationCfgVertex = new CfgVertex("Dc" + $closinv);

		$body::declaration.addCfgEdge(
			$body::declaration.lastCfgVertex,
			invocationCfgVertex
		);

		$body::declaration.addCfgEdge(
			$body::declaration.lastCfgVertex,
			new CfgVertex($body::declaration.getVariable($result_id.text), Variable.AccessMode.WRITE, $closinv)
		);

		$body::declaration.calleeCfgVertices.put($closinv, invocationCfgVertex);

	}
	: ^(closinv=CLOSINV
			(var[Variable.AccessMode.READ]|array[Variable.AccessMode.READ])
			(^(ARGS (^( (REF|VAL) expression))*)  | (^(NARGS (^( (REF|VAL) ^(NARG VARIABLE_ID expression)))* )) )
			result_id=VARIABLE_ID
		);



closure_declaration
	: ^(CLOSDEF
			id=VARIABLE_ID
			{
				Declaration declaration = library.declarations.get($id.text);
				
				Library.logger.debug("START CD: " + declaration.name);
				NDC.push(" ");

				CfgVertex startVertex = new CfgVertex("START");
				declaration.cfg.addVertex(startVertex);
				declaration.startCfgVertex = startVertex;
				declaration.lastCfgVertex = startVertex;

				for(Variable variable: declaration.variables.values()) {
					
					Library.logger.debug("name: " + variable.name);

					if(variable.bindByValue && variable.getParent().equals(variable)) {
						errors.add(
							new SourceError(
								$id,
								"parent variable not found for bind-by-value variable '" + variable.bindByValueToName + "'.",
								library
							)
						);
					}

					if(variable.temporary || variable.getParent().equals(variable)) {
						continue;
					}

					Variable originVariable = variable.getParent();
					Library.logger.debug("parent name: " + originVariable.name);
					
					while(originVariable.transit != false)  {
						originVariable.neverGarbage = true;
						originVariable = originVariable.getParent();
						Library.logger.debug("parent name: " + originVariable.name);
					}

					Library.logger.debug("OV D: " + originVariable.declaration);

					Library.logger.debug("OV D lastCfgVertex: " + originVariable.declaration.lastCfgVertex);

					originVariable.declaration.addCfgEdge(
						originVariable.declaration.lastCfgVertex,
						new CfgVertex(originVariable, Variable.AccessMode.READ, $id)
					);

					declaration.addCfgEdge(
						declaration.lastCfgVertex,
						new CfgVertex(variable, Variable.AccessMode.WRITE, $id)
					);

					//originVariable.access(Variable.AccessMode.READ, $id);
					originVariable.neverGarbage = true;
					//v.access(Variable.AccessMode.WRITE, $id);
					variable.neverGarbage = true;
				}
			}
			^(PARAMS (parameter[declaration])*) body[declaration]
		)
		{
			CfgVertex declarationEnd = new CfgVertex("END");
			declaration.addCfgEdge(declaration.lastCfgVertex, declarationEnd);
			
			NDC.pop();
			Library.logger.debug("END CD: " + declaration.name);
		}
	;

//---------------------------------------------------------------------------------------------

//=============================================================================================

