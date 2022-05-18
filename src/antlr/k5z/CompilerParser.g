// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

//=============================================================================================

//---------------------------------------------------------------------------------------------
tree grammar CompilerParser;
//---------------------------------------------------------------------------------------------



/* tab size is 4 spaces */



//---------------------------------------------------------------------------------------------
options{
	tokenVocab = Ast;
	ASTLabelType = CommonTree;
	output = AST;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
tokens {
	DUMMY1; DUMMY2; DUMMY3; DUMMY4;

	DFUNCTION; CFUNCTION;
	DCALL; CCALL;
	DIF; CIF;
	CFOR; DFOR;
	DFOREACH; CFOREACH;
	DRETURN; CRETURN;
	DCONTINUE; CCONTINUE;
	DBREAK; CBREAK;
	DWHILE; CWHILE;
	DVAR; CVAR;
	DVARA; CVARA;

	DBLOCK; CBLOCK;
	CBODY; DBODY;
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------
@header{
	package lv.kristsk.k5z.antlr.parsers;

	import java.io.*;

	import java.util.HashMap;
	import java.util.Vector;

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
	public CompilerParser(CommonTreeNodeStream inputStream, Library library) {

		this(inputStream);
		this.library = library;
	}
	//---------------------------------------------------------------------------------------------
	


	//---------------------------------------------------------------------------------------------
	public void displayRecognitionError(String[] tokenNames, RecognitionException e) {

		SourceError error = null;

		if(e instanceof CompileTimeException) {

			error = new SourceError(
				((CompileTimeException) e).commonTreeNode,
				((CompileTimeException) e).getMessage(),
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



	//---------------------------------------------------------------------------------------------
	public CommonTree getPendingDirtyCallStub() {

		CommonTree root_1 = (CommonTree)adaptor.nil();
		root_1 = (CommonTree)adaptor.becomeRoot((CommonTree)adaptor.create(DCALL, "DCALL"), root_1);
		return root_1;
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void makePendingDirtyCall(CommonTree pendingDirtyCall,
			RewriteRuleNodeStream FUNCTION_ID_nodes,
			RewriteRuleNodeStream ARGS_OR_NARGS_nodes,
			RewriteRuleElementStream arg_node_stream,
			Integer dirtyCounter) {

		// ^(FID alias=FUNCTION_ID id=FUNCTION_ID)
		CommonTree fid_root = (CommonTree) adaptor.nil();
		CommonTree fid = (CommonTree) adaptor.create(FID, "FID");
		fid_root = (CommonTree) adaptor.becomeRoot(fid, fid_root);
		adaptor.addChild(fid_root, FUNCTION_ID_nodes.nextNode());
		adaptor.addChild(fid_root, FUNCTION_ID_nodes.nextNode());
		adaptor.addChild(pendingDirtyCall, fid_root);

		// ^(ARGS ... ) or ^(NARGS ...) 
		CommonTree args_root = (CommonTree) adaptor.nil();
		args_root = (CommonTree) adaptor.becomeRoot(ARGS_OR_NARGS_nodes.nextNode(), args_root);

		while (arg_node_stream.hasNext()) {
			adaptor.addChild(args_root, arg_node_stream.nextTree());
		}
		arg_node_stream.reset();
		adaptor.addChild(pendingDirtyCall, args_root);

		// VARIABLE_ID[dirtyCounter]
		CommonTree result_dvar = (CommonTree) adaptor.create(VARIABLE_ID, dirtyCounter.toString());
		adaptor.addChild(pendingDirtyCall, result_dvar);

	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public CommonTree getPendingClosureInvocationStub() {

		CommonTree root_1 = (CommonTree)adaptor.nil();
		root_1 = (CommonTree)adaptor.becomeRoot((CommonTree)adaptor.create(CLOSINV, "CLOSINV"), root_1);

		return root_1;
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public void makePendingClosureInvocation(
			CommonTree pendingClosureInvocation, 
			RewriteRuleSubtreeStream var_nodes, 
			RewriteRuleNodeStream stream_ARGS, 
			RewriteRuleElementStream stream_expression, 
			ArrayList<Declaration.ExpressionType> argumentExpressionTypes, 
			Integer dirtyCounter
	) {

		adaptor.addChild(pendingClosureInvocation, adaptor.dupTree(var_nodes.nextTree()));

		CommonTree root_2 = (CommonTree)adaptor.nil();
		root_2 = (CommonTree)adaptor.becomeRoot(stream_ARGS.nextNode(), root_2);

		Integer argumentCounter = 0;
		while ( stream_expression.hasNext() ) {

			CommonTree root_3 = (CommonTree)adaptor.nil();
			if(argumentExpressionTypes.get(argumentCounter).equals(Declaration.ExpressionType.LVALUE)) {
				root_3 = (CommonTree)adaptor.becomeRoot((CommonTree)adaptor.create(REF, "REF"), root_3);
			}
			else {
				root_3 = (CommonTree)adaptor.becomeRoot((CommonTree)adaptor.create(VAL, "VAL"), root_3);
			}

			adaptor.addChild(root_3, stream_expression.nextTree());

			argumentCounter++;

			adaptor.addChild(root_2, root_3);

		}

		stream_expression.reset();

		adaptor.addChild(pendingClosureInvocation, root_2);

		adaptor.addChild(pendingClosureInvocation, (CommonTree)adaptor.create(VARIABLE_ID, dirtyCounter.toString()));
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public RewriteRuleSubtreeStream getPendingNodes(RewriteRuleSubtreeStream stream_expression) {

		return getPendingNodes(stream_expression, $body::pendingNodes);
	}
	//---------------------------------------------------------------------------------------------



	//---------------------------------------------------------------------------------------------
	public RewriteRuleSubtreeStream getPendingNodes(RewriteRuleSubtreeStream stream_expression, Stack<CommonTree> pendingNodesStack) {

		RewriteRuleSubtreeStream tmp_stream_expression = new RewriteRuleSubtreeStream(adaptor, "rule expression");

		List<CommonTree> list = new ArrayList<CommonTree>(pendingNodesStack);
		
		for (CommonTree x : list) {
			tmp_stream_expression.add(x);
        }

		pendingNodesStack.clear();

		//while( ! pendingNodesStack.isEmpty()) {
		//	tmp_stream_expression.add(pendingNodesStack.pop());
		//}

		if(stream_expression.size() > 0) {
			tmp_stream_expression.add(stream_expression.nextTree());
		}

		tmp_stream_expression.reset();

		return tmp_stream_expression;
	}
	//---------------------------------------------------------------------------------------------
}
//---------------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------------

library
	: ^(LIBRARY PROGRAM? FUNCTION_ID ^(IMPORTS .*) ^(INCLUDES include*) ^(FUNCTIONS function_declaration*)) EOF
		-> ^(LIBRARY PROGRAM? FUNCTION_ID ^(INCLUDES include*) ^(FUNCTIONS function_declaration*)) EOF
	;



include
	:   ^(INCLUDE QUOTED_STRING FREE_ID 
			(
				^(INCLUDED_FUNCTION function_declaration)
					-> function_declaration
				|
				^(FUNCTIONS included_function_declaration*)
				    -> included_function_declaration*
			)
		)
	;



included_function_declaration
    : ^(INCLUDED_FUNCTION function_declaration .?)
        -> ^(INCLUDED_FUNCTION function_declaration)
    ;



function_declaration
	@init {
		Declaration functionDeclaration;
	}
	: ^(FUNCTION
			FDIRTY?
			FREF?
			FUNCTION_ID
			{
				functionDeclaration = library.declarations.get($FUNCTION_ID.text);
			}

			^(PARAMS (parameter[functionDeclaration])*)

			body[functionDeclaration]
		)
		-> {(functionDeclaration.getMode() == Declaration.Mode.DIRTY)}? ^(DFUNCTION FUNCTION_ID ^(PARAMS parameter*) body)
			-> ^(CFUNCTION FUNCTION_ID ^(PARAMS parameter*) body)
	;



parameter
	[Declaration declaration]
	@after {
		if(
			$declaration.type.equals(Declaration.Type.CLOSURE) &&
			(!declaration.getVariable($id.text).getParent().equals(declaration.getVariable($id.text)))
		){
			throw new SourceErrorsException($id, "parameter '" + $id.text + "' of closure clashes with variable in parent declaration.", library);
		}
	}
	: ^((VAL|REF|OPT) id=VARIABLE_ID expression?)
	;



body
	[Declaration declaration_in]
	scope {
		Declaration declaration;
		Stack<CommonTree> pendingNodes;
	}
	@init {
		$body::declaration = $declaration_in;
		$body::pendingNodes = new Stack<CommonTree>();
	}
	:	^(BODY ^(STATEMENTS statement*))
		-> {$body::declaration.getMode().equals(Declaration.Mode.DIRTY)}? ^(DBODY ^(STATEMENTS statement*))
			-> ^(CBODY ^(STATEMENTS statement*))
	;



statement
	returns [Boolean hadPendingNodes]
	@init {
		Stack<CommonTree> stack1 = new Stack<CommonTree>();
		Stack<CommonTree> stack2 = new Stack<CommonTree>();
		Stack<CommonTree> stack3 = new Stack<CommonTree>();
		Stack<CommonTree> stack4 = new Stack<CommonTree>();
		$hadPendingNodes = false;
	}
	: NOP
		-> NOP

	| ^(CONTINUE INT dummy1*)
		{
			$hadPendingNodes = true;
			//!$body::pendingNodes.isEmpty();
			//stream_dummy1 = getPendingNodes(stream_dummy1);
		}
		-> {$hadPendingNodes}? dummy1* ^(DCONTINUE INT)
			-> ^(CCONTINUE INT)

	| ^(BREAK INT dummy1*)
		{
			$hadPendingNodes = true;
			//!$body::pendingNodes.isEmpty();
			//stream_dummy1 = getPendingNodes(stream_dummy1);
		}
		-> {$hadPendingNodes}? dummy1* ^(DBREAK INT)
			-> ^(CBREAK INT)

	| ^(VOID (call|closure_invocation) dummy1*)
		{
			$hadPendingNodes = !$body::pendingNodes.isEmpty();
			stream_dummy1 = getPendingNodes(stream_dummy1);
		}
		-> {$hadPendingNodes && (($call.tree != null && $call.isDirty) || $closure_invocation.tree != null)}? dummy1*
			-> dummy1* ^(VOID call?)

	| expression
		{
			$hadPendingNodes = !$body::pendingNodes.isEmpty();
			stream_expression = getPendingNodes(stream_expression);
		}
		-> expression*

	| ^(BLOCK
			^(STATEMENTS
				(s=statement
					{
						$hadPendingNodes = $hadPendingNodes || $s.hadPendingNodes;
					}
				)+
			)
		)
		-> {$hadPendingNodes}? statement*
			-> {$body::declaration.getMode().equals(Declaration.Mode.DIRTY)}? ^(DBLOCK ^(STATEMENTS statement*))
				-> ^(CBLOCK ^(STATEMENTS statement*))

	| ^(IF
			expression
			{
				stack1 = $body::pendingNodes;
				$body::pendingNodes = new Stack<CommonTree>();
			}

			s1=statement
			s2=statement
			dummy1*
		)
		{
			$hadPendingNodes = (!stack1.isEmpty()) || $s1.hadPendingNodes || $s2.hadPendingNodes;
			stream_dummy1 = getPendingNodes(stream_dummy1, stack1);
		}
		-> {$hadPendingNodes && $s1.hadPendingNodes && $s2.hadPendingNodes}? dummy1* ^(DIF expression ^(DBLOCK ^(STATEMENTS $s1)) ^(DBLOCK ^(STATEMENTS $s2)) VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()])
		-> {$hadPendingNodes && $s1.hadPendingNodes && !$s2.hadPendingNodes}? dummy1* ^(DIF expression ^(DBLOCK ^(STATEMENTS $s1)) $s2 VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()])
		-> {$hadPendingNodes && !$s1.hadPendingNodes && $s2.hadPendingNodes}? dummy1* ^(DIF expression $s1 ^(DBLOCK ^(STATEMENTS $s2)) VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()])
		-> {$hadPendingNodes && !$s1.hadPendingNodes && !$s2.hadPendingNodes}? dummy1* ^(CIF expression $s1 $s2)
			-> dummy1* ^(CIF expression statement statement)

	|	^(FOREACH
			(v=var|a=array|ad=array_declaration|c=call|i=closure_invocation)
			{
				stack1 = $body::pendingNodes;
				$body::pendingNodes = new Stack<CommonTree>();
			}

			REF?
			v1=var
			v2=var?
			s=statement
			dummy1*
		)
		{
			$hadPendingNodes = !stack1.isEmpty() || $s.hadPendingNodes;
			stream_dummy1 = getPendingNodes(stream_dummy1, stack1);
		}
		-> {$hadPendingNodes && $s.hadPendingNodes}? dummy1* ^(DFOREACH VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()] $v? $a? $ad? $c? $i? REF? $v1 $v2? ^(DBLOCK ^(STATEMENTS statement)))
		-> {$hadPendingNodes && !$s.hadPendingNodes}? dummy1* ^(DFOREACH VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()] $v? $a? $ad? $c? $i? REF? $v1 $v2? statement)
			-> ^(CFOREACH $v? $a? $ad? $c? $i? REF? $v1 $v2? statement)

	| ^(WHILE
			expression
			{
				stack1 = $body::pendingNodes;
				$body::pendingNodes = new Stack<CommonTree>();
			}

			s=statement
			dummy1*
		)
		{
  			$hadPendingNodes = !stack1.isEmpty() || $s.hadPendingNodes;
			stream_dummy1 = getPendingNodes(stream_dummy1, stack1);
		}
		-> {$hadPendingNodes && $s.hadPendingNodes}? ^(DWHILE VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()] ^(DBLOCK dummy1*) expression ^(DBLOCK ^(STATEMENTS statement)))
		-> {$hadPendingNodes && !$s.hadPendingNodes}? ^(DWHILE VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()] ^(DBLOCK dummy1)* expression statement)
			-> ^(CWHILE expression statement)

	| ^(FOR
			s1=statement
			e2=expression
			{
				stack1 = $body::pendingNodes;
				$body::pendingNodes = new Stack<CommonTree>();
			}

			s3=statement
			s=statement
			dummy1* dummy2* dummy3*
		)
		{
			$hadPendingNodes = !stack1.isEmpty() || !stack2.isEmpty() || !stack3.isEmpty() || $s.hadPendingNodes || $s1.hadPendingNodes || $s3.hadPendingNodes;
			stream_dummy1 = getPendingNodes(stream_dummy1, stack1);
		}
		-> {$hadPendingNodes && $s.hadPendingNodes}? ^(DFOR VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()] ^(DBLOCK $s1) ^(DBLOCK dummy1*) $e2 ^(DBLOCK ^(STATEMENTS $s)) ^(DBLOCK $s3))
		-> {$hadPendingNodes && !$s.hadPendingNodes}? ^(DFOR VARIABLE_ID[$body::declaration.getNextVariableId(3).toString()] ^(DBLOCK $s1) ^(DBLOCK dummy1*) $e2 $s ^(DBLOCK $s3))
			-> ^(CFOR $s1 $e2 $s $s3)

	| ^(RETURN
			expression
			dummy1*
		)
		{
			$hadPendingNodes = !$body::pendingNodes.isEmpty();
			stream_dummy1 = getPendingNodes(stream_dummy1);
			if($hadPendingNodes) {
				$body::declaration.setMode(Declaration.Mode.DIRTY);
			}
		}
		-> {$hadPendingNodes || $body::declaration.getMode() == Declaration.Mode.DIRTY}? dummy1* ^(DRETURN expression)
			-> ^(CRETURN expression)
	;



dummy1: DUMMY1;
dummy2: DUMMY2;
dummy3: DUMMY3;
dummy4: DUMMY4;



expression_op
	: (a='+'|a='-'|a='/'|a='*'|a='==='|a='!=='|a='=='|a='!='|a='..'|a='&&'|a='and'|a='||'|a='or'|a='>='|a='<='|a='<'|a='>')
	;



expression
	returns [Declaration.ExpressionType type, Boolean byRefCall]
	@after { 
		$type = $e.type;
	}
	: e=expression_inner
		-> ^(DBGSRCL INT[Integer.toString($e.start.getLine())] INT[Integer.toString($e.start.getCharPositionInLine())] ) expression_inner
	;



expression_inner
	returns [Declaration.ExpressionType type]
	@init { $type = Declaration.ExpressionType.RVALUE; }
	: ^(expression_op expression expression)
	| ^((QUESTION|QUESTION_AND_DOUBLEDOT) expression expression expression?)
	| ^(QUESTION_AND_QUESTION expression expression)
	| ^(STRING QUOTED_STRING)
	| ^(ASSIGN e=expression var_or_array ASSIGNREF? ASSIGNAE?)
	| ^(NUM INT)
	| ^(NUM FLOAT)
	| ^(NEGATE expression)
	| ^(NOT expression)
	| ^(POSTFIX var_or_array ('--'|'++'))
	| ^(PREFIX var_or_array ('--'|'++'))
	| ^(BOOLEAN TRUE)
	| ^(BOOLEAN FALSE)
	| array_declaration
	| ^(ISSET var_or_array)
	| var { $type = Declaration.ExpressionType.LVALUE; }
	| array { $type = Declaration.ExpressionType.LVALUE; }
	| call
	| closure_declaration //{ $type = Declaration.ExpressionType.LVALUE; }
	| closure_invocation
	| ^(FID FUNCTION_ID FUNCTION_ID)
	;



array_declaration
	: ^(ARRAYDEF array_definition_element*)
	;



array_definition_element
	: ^(ARRAYELEM e1=expression e2=expression? ASSIGNREF?)
		-> ^(ARRAYELEM $e1 $e2? ASSIGNREF?)
	;



var
	: ^(VAR id=VARIABLE_ID (REF|val=VAL))
		-> {($body::declaration.getMode().equals(Declaration.Mode.DIRTY)) && ($val != null)}? ^(DVAR VARIABLE_ID[$id.token, "_val_" + $id.text])
		-> {($body::declaration.getMode().equals(Declaration.Mode.DIRTY)) && ($val == null)}? ^(DVAR VARIABLE_ID)
			-> ^(CVAR VARIABLE_ID)
	;



array
	: ^(VARA id=VARIABLE_ID (REF|val=VAL) expression+)
		-> {($body::declaration.getMode().equals(Declaration.Mode.DIRTY)) && ($val != null)}? ^(DVARA VARIABLE_ID[$id.token, "_val_" + $id.text] expression+)
		-> {($body::declaration.getMode().equals(Declaration.Mode.DIRTY)) && ($val == null)}? ^(DVARA VARIABLE_ID expression+)
			-> ^(CVARA VARIABLE_ID expression+ )
	;



var_or_array
	: (var|array)
	;



closure_invocation
	scope {
		CommonTree pendingClosureInvocation;
		Declaration callee;
	}
	@init {
		Integer thisCallId = 0;
		$closure_invocation::pendingClosureInvocation = getPendingClosureInvocationStub();
		ArrayList<Declaration.ExpressionType> argumentExpressionTypes = new ArrayList<Declaration.ExpressionType>();

		HashMap<String, Declaration.ExpressionType> namedArgumentTypes = new HashMap<String, Declaration.ExpressionType>();
		HashMap<String, CommonTree> namedArgumentNodes = new HashMap<String, CommonTree>();
	}
	@after {
		if(namedArgumentTypes.size() == 0) {
			makePendingClosureInvocation($closure_invocation::pendingClosureInvocation, stream_var_or_array, stream_ARGS, stream_expression, argumentExpressionTypes, thisCallId);
		}
		else {
			makePendingClosureInvocation($closure_invocation::pendingClosureInvocation, stream_var_or_array, stream_NARGS, stream_named_call_argument, argumentExpressionTypes, thisCallId);
		}
	}
	: ^(closinv=CLOSINV
			v=var_or_array
			(
				^(ARGS
					(
						e=expression
						{
							argumentExpressionTypes.add($e.type);
						}
					)*
				)
				|
				^(NARGS
					(
						n=named_call_argument[namedArgumentTypes, namedArgumentNodes]
						{
							argumentExpressionTypes.add($n.type);
						}
					)*
				)
			)
			{
				thisCallId = $body::declaration.getNextVariableId();

				$body::declaration.getVariable(thisCallId.toString()).temporary = true;
				$body::declaration.getVariable(thisCallId.toString()).setId(thisCallId);

				Declaration.CalleeIdentity calleeIdentity = $body::declaration.calleeIdentities.get($closinv);

				if(calleeIdentity == null) {
					throw new CompileTimeException($closinv, "callee identity not found in declaration");
				}
				else {
					calleeIdentity.callId = thisCallId;
				}

				$body::pendingNodes.push($closure_invocation::pendingClosureInvocation);
			}
		)
		-> ^(DVAR VARIABLE_ID[$v.tree.token, thisCallId.toString()])
	;



call
	returns [Boolean isDirty]
	scope {
		CommonTree pendingDCall;
		Declaration callee;
	}
	@init {
		Integer thisCallId = 0;
		ArrayList<Declaration.ExpressionType> argumentTypes = new ArrayList<Declaration.ExpressionType>();
		ArrayList<CommonTree> argumentNodes = new ArrayList<CommonTree>();

		HashMap<String, Declaration.ExpressionType> namedArgumentTypes = new HashMap<String, Declaration.ExpressionType>();
		HashMap<String, CommonTree> namedArgumentNodes = new HashMap<String, CommonTree>();

		$call::pendingDCall = getPendingDirtyCallStub();
	}
 	@after {
		Integer suppliedArgumentCount = 0;

		if(namedArgumentTypes.isEmpty()) {
			suppliedArgumentCount = argumentTypes.size();
		}
		else {
			suppliedArgumentCount = namedArgumentTypes.size();
		}

		if((suppliedArgumentCount < $call::callee.getMandatoryArgumentCount()) || (suppliedArgumentCount > $call::callee.parameters.size())) {

			if(($call::callee.getMandatoryArgumentCount() == $call::callee.parameters.size())) {

				errors.add(
					new SourceError(
						$id,
						"wrong argument count - function " + $call::callee.getPrintableFormalDeclaration() + " takes exactly " + $call::callee.parameters.size() + ", but " + suppliedArgumentCount + " were given.",
						library
					)
				);
			}
			else {

				errors.add(
					new SourceError(
						$id,
						"wrong argument count - function " + $call::callee.getPrintableFormalDeclaration() + " takes at least " + $call::callee.getMandatoryArgumentCount() + ", at most " + $call::callee.parameters.size() + ", but " + suppliedArgumentCount + " were given.",
						library
					)
				);
			}
		}
		else {

			Integer counter = 0;

			if(namedArgumentTypes.isEmpty()) {

				for(Declaration.ExpressionType argumentType: argumentTypes) {

					Declaration.Parameter parameter = $call::callee.parameters.get(counter);

					if((parameter.mode.equals(Declaration.Parameter.Mode.BYREF)) && (argumentType.equals(Declaration.ExpressionType.RVALUE))) {

						errors.add(
							new SourceError(
								argumentNodes.get(counter),
								Common.getOrdinal(counter + 1) + " argument '" + parameter.variable.name + "' must be LVALUE. Formal declaration of called function - " + $call::callee.getPrintableFormalDeclaration(),
								library
							)
						);
					}

					counter++;
				}

				makePendingDirtyCall($call::pendingDCall, stream_FUNCTION_ID, stream_ARGS, stream_expression, thisCallId);
			}
			else {

				ArrayList<String> parameterNames = new ArrayList<String>();

				for(Declaration.Parameter parameter: $call::callee.parameters) {

					parameterNames.add(parameter.variable.name);

					if(parameter.mode.equals(Declaration.Parameter.Mode.BYOPT)) {
						continue;
					}
					else if(!namedArgumentTypes.containsKey(parameter.variable.name)) {

						errors.add(
							new SourceError(
								$id,
								"named mandatory argument '" + parameter.variable.name + "' is not set. Formal declaration of called function - " + $call::callee.getPrintableFormalDeclaration(),
								library
							)
						);
					}
					else if(parameter.mode.equals(Declaration.Parameter.Mode.BYREF) && namedArgumentTypes.get(parameter.variable.name).equals(Declaration.ExpressionType.RVALUE)) {

						errors.add(
							new SourceError(
								namedArgumentNodes.get(parameter.variable.name),
								"named mandatory argument '" + parameter.variable.name + "' must be LVALUE. Formal declaration of called function - " + $call::callee.getPrintableFormalDeclaration(),
								library
							)
						);
					}
				}

				for(String namedArgumentName: namedArgumentTypes.keySet()) {

					if(!parameterNames.contains(namedArgumentName)) {

						errors.add(
							new SourceError(
								namedArgumentNodes.get(namedArgumentName),
								"unknown named argument '" + namedArgumentName + "' found. Formal declaration of called function - " + $call::callee.getPrintableFormalDeclaration(),
								library
							)
						);
					}
				}

				makePendingDirtyCall($call::pendingDCall, stream_FUNCTION_ID, stream_NARGS, stream_named_call_argument, thisCallId);
			}
		}
 	}
 	: ^(c=CALL
			^(FID alias=FUNCTION_ID id=FUNCTION_ID)
			(
			 	^(ARGS
					(
						e=expression
						{
							argumentTypes.add($e.type);
							argumentNodes.add(e.tree);
						}
					)*
				)
				|
			 	^(NARGS named_call_argument[namedArgumentTypes, namedArgumentNodes]*)
		 	)
			{
				$isDirty = false;

				Declaration.Identity calleeDeclarationIdentity = new Declaration.Identity(
					library.importAliasToDefinitionMap.get($alias.text).name, $id.text
				);

				$call::callee = lv.kristsk.k5z.Compiler.knownDeclarations.get(calleeDeclarationIdentity);

				library.logger.debug("K5Z CALL IN " + library.name + "::"+ $body::declaration.name + ", CALLEE IDENTITY: " + calleeDeclarationIdentity + ", MODE: " + $call::callee.getMode());

				if($call::callee.getMode() == Declaration.Mode.DIRTY) {

					$isDirty = true;
					thisCallId = $body::declaration.getNextVariableId();
					$body::declaration.getVariable(thisCallId.toString()).temporary = true;
					$body::declaration.getVariable(thisCallId.toString()).setId(thisCallId);

					Declaration.CalleeIdentity calleeIdentity = $body::declaration.calleeIdentities.get($id);

					if(calleeIdentity == null) {
						throw new CompileTimeException($id, "callee identity not found in declaration");
					}
					else {
						calleeIdentity.callId = thisCallId;
					}

					//library.logger.debug("K5Z CALL - PUSH TO PENDING NODES: " + $call::pendingDCall);

					$body::pendingNodes.push($call::pendingDCall);
				}
			}
		)
		-> {$call::callee.getMode() == Declaration.Mode.DIRTY}? ^(DVAR VARIABLE_ID[$id.token, thisCallId.toString()])
			-> {namedArgumentTypes.size() == 0}? ^(CCALL ^(FID $alias $id) ^(ARGS expression*))
				-> ^(CCALL ^(FID $alias $id) ^(NARGS named_call_argument*))
	;



named_call_argument
	[HashMap<String, Declaration.ExpressionType> namedArgumentTypes, HashMap<String, CommonTree> namedArgumentNodes]
	returns [Declaration.ExpressionType type]
	@after{
		namedArgumentTypes.put($id.text, $e.type);
		namedArgumentNodes.put($id.text, e.tree);
		$type = $e.type;
	}
	: ^(NARG id=VARIABLE_ID e=expression)
	;



closure_declaration
	@init {
		Declaration closureDeclaration = null;
	}
	: ^(CLOSDEF
			FREF?
			VARIABLE_ID
			{
				closureDeclaration = library.declarations.get($VARIABLE_ID.text);
			}
			^(PARAMS (parameter[closureDeclaration])*)
			body[closureDeclaration]
			dummy1*
		)
		-> ^(CLOSDEF VARIABLE_ID ^(PARAMS parameter*) body)
	;

//---------------------------------------------------------------------------------------------

//=============================================================================================

 