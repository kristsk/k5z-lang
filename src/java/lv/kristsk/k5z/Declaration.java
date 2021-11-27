// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z;

import lv.kristsk.k5z.utilities.Common;
import lv.kristsk.k5z.utilities.CompileTimeException;
import lv.kristsk.k5z.utilities.SourceError;
import lv.kristsk.k5z.utilities.SourceErrorsException;
import org.antlr.runtime.tree.CommonTree;
import org.apache.commons.lang.StringUtils;
import org.apache.log4j.Logger;
import org.jgrapht.DirectedGraph;
import org.jgrapht.ext.DOTExporter;
import org.jgrapht.ext.StringNameProvider;
import org.jgrapht.graph.DefaultDirectedGraph;
import org.jgrapht.graph.DefaultEdge;

import java.io.*;
import java.util.*;

public class Declaration implements Serializable {

    public static Logger logger = Common.logger;
    public static Integer variableIdCounterBase = 100;

    public enum Mode {
        CLEAN, DIRTY, AUTO
    }

    public enum ExpressionType {
        LVALUE, RVALUE
    }

    public enum Type {
        FUNCTION, CLOSURE, PHP_INCLUDE, PHTML_INCLUDE
    }

    public static class Identity implements Serializable {

        public String libraryName;
        public String declarationName;

        public Identity() {

        }

        public Identity(String libraryName, String declarationName) {

            this.libraryName = libraryName;
            this.declarationName = declarationName;
        }

        public String toString() {

            return "[" + libraryName + "::" + declarationName + "]";
        }

        @Override
        public int hashCode() {

            int hash = 3;
            hash = 53 * hash + (this.libraryName != null ? this.libraryName.hashCode() : 0);
            hash = 53 * hash + (this.declarationName != null ? this.declarationName.hashCode() : 0);
            return hash;
        }

        @Override
        public boolean equals(Object obj) {

            if (obj == null) {
                return false;
            }

            if (getClass() != obj.getClass()) {
                return false;
            }

            final Identity other = (Identity) obj;

            return !(
                (this.libraryName == null)
                    ? (other.libraryName != null)
                    : !this.libraryName.equals(other.libraryName)
            ) && !(
                (this.declarationName == null)
                    ? (other.declarationName != null)
                    : !this.declarationName.equals(other.declarationName)
            );

        }
    }

    public static class CalleeIdentity implements Serializable {

        public Identity identity;
        public CommonTree node;
        public Integer callId;

        public CalleeIdentity() {

        }

        public CalleeIdentity(String libraryName, String declarationName, CommonTree node) {

            this.identity = new Identity(libraryName, declarationName);

            this.node = node;
        }
    }

    public static class Parameter implements Serializable {

        public enum Mode {
            BYVAL, BYREF, BYOPT
        }

        public Mode mode;
        public Variable variable;
        public Integer number;
        public String optionalDefaultValue;
        transient public CommonTree optionalDefaultValueNode = null;

        public Parameter() {

        }

        public Parameter(Variable variable, Mode mode) {

            this.variable = variable;
            this.mode = mode;
        }

        public Parameter(Variable variable, Mode mode, CommonTree optionalValueNode) {

            this(variable, mode);
            this.optionalDefaultValueNode = optionalValueNode;
        }

        @Override
        public String toString() {

            return mode.toString() + ": " + variable.name;
        }
    }

    private Mode mode = Mode.AUTO;
    public Boolean byRef = false;
    public Type type = Type.FUNCTION;
    public transient org.antlr.runtime.tree.CommonTree node;
    public String name;
    private String phpName = null;
    public Integer line;
    public Integer position;
    public Library library;
    protected Identity identity = null;
    public Declaration parent = null;

    public ArrayList<Parameter> parameters = new ArrayList<Parameter>();
    public HashMap<String, Parameter> parameterMap = new HashMap<String, Parameter>();

    public transient HashMap<CommonTree, CalleeIdentity> calleeIdentities = new HashMap<CommonTree, CalleeIdentity>();
    public HashSet<Declaration> callers = new HashSet<Declaration>();
    public transient HashSet<Declaration> callees = new HashSet<Declaration>();

    public transient HashMap<String, Declaration> closures = new HashMap<String, Declaration>();

    public transient HashMap<String, Variable> variables = new HashMap<String, Variable>();

    public transient DirectedGraph<CfgVertex, DefaultEdge> cfg = new DefaultDirectedGraph<CfgVertex, DefaultEdge>(DefaultEdge.class);
    public transient CfgVertex lastCfgVertex;
    public transient CfgVertex startCfgVertex;
    public transient HashMap<CommonTree, CfgVertex> calleeCfgVertices = new HashMap<CommonTree, CfgVertex>();

    public Library.Include include = null;

    public Declaration() {

    }

    public String getPhpName() {

        if (phpName == null) {
            phpName = library.name + "_" + name;
        }

        return phpName;
    }

    public void setPhpName(String phpName) {

        this.phpName = phpName;
    }

    public Identity getIdentity() {

        if (this.identity == null) {
            this.identity = new Identity(this.library.name, this.name);
        }

        return this.identity;
    }

    public void addCfgEdge(CfgVertex v1, CfgVertex v2) {

        cfg.addVertex(v2);
        cfg.addEdge(v1, v2);
        lastCfgVertex = v2;
    }

    public Set<CfgVertex> getCfgVertexSuccessors(CfgVertex vertex) {

        Set<CfgVertex> result = new HashSet<CfgVertex>();

        for (DefaultEdge edge : cfg.outgoingEdgesOf(vertex)) {
            result.add(cfg.getEdgeTarget(edge));
        }

        return result;
    }

    public Variable getVariable(String name) {

        if (variables.containsKey(name)) {
            return variables.get(name);
        }

        Variable newVariable = new Variable(name);
        newVariable.declaration = this;

        variables.put(name, newVariable);

        return newVariable;
    }

    public Integer getMandatoryArgumentCount() {

        Integer result = 0;

        for (Parameter parameter : parameters) {

            if (parameter.mode != Parameter.Mode.BYOPT) {
                result++;
            }
        }

        return result;
    }

    public String getPrintableFormalDeclaration() {

        ArrayList<String> printableParameters = new ArrayList<String>();

        for (Parameter parameter : parameters) {

            if (parameter.mode == Parameter.Mode.BYVAL) {
                printableParameters.add("val " + parameter.variable.name);
            }
            else if (parameter.mode == Parameter.Mode.BYOPT) {
                printableParameters.add("opt " + parameter.variable.name);
            }
            else if (parameter.mode == Parameter.Mode.BYREF) {
                printableParameters.add("ref " + parameter.variable.name);
            }
        }

        return name + "(" + StringUtils.join(printableParameters, ", ") + ")";
    }

    public String toString() {

        return "<" + name + ", " + mode + ", " + parameters + ", " + this.getPhpName() + ", " + variables + ", " + library.sourceFile.getName() + ", " + line + ", " + position + ">";
    }

    public Boolean hasDirtyCallees() throws CompileTimeException {

        for (Declaration callee : callees) {

            logger.debug("HAS DIRTY CALLEES?: " + this.library.name + "::" + this.name + ": " + callee.name + " " + callee.getMode());

            if (callee.getMode().equals(Declaration.Mode.DIRTY)) {
                logger.debug("HAS DIRTY CALLEES: " + this.library.name + "::" + this.name + ": YES");
                return true;
            }
        }

        logger.debug("HAS DIRTY CALLEES: " + this.library.name + "::" + this.name + ": NO");

        return false;
    }

    public void setMode(Declaration.Mode mode) {

        this.mode = mode;
    }

    public Declaration.Mode readMode() {

        return mode;
    }

    public Declaration.Mode getMode() throws CompileTimeException {

        if (!mode.equals(Declaration.Mode.AUTO)) {
            return mode;
        }

        return getMode(new Stack<Declaration.Identity>());
    }

    public Declaration.Mode getMode(Stack<Declaration.Identity> stack) throws CompileTimeException {

        if (library.state.equals(Library.State.PARSED)) {

            try {
                library.compile();
            }
            catch (SourceErrorsException e) {
                throw e;
            }
            catch (Exception e) {

                logger.error(e.toString(), e);

                throw new CompileTimeException(node, "could not get mode");
            }
        }

        if (!mode.equals(Declaration.Mode.AUTO)) {
            return mode;
        }

        stack.push(this.getIdentity());

        for (Declaration d : callees) {

            if (this.getIdentity().equals(d.getIdentity())) {
                continue;
            }

            if (stack.contains(d.getIdentity())) {
                continue;
            }

            if (d.mode.equals(Declaration.Mode.DIRTY)) {

                mode = Declaration.Mode.DIRTY;
                for (Declaration caller : callers) {
                    caller.mode = Declaration.Mode.DIRTY;
                }

                break;
            }

        }

        if (!mode.equals(Declaration.Mode.DIRTY)) {

            for (Declaration declaration : callees) {

                if (this.getIdentity().equals(declaration.getIdentity())) {
                    continue;
                }

                if (stack.contains(declaration.getIdentity())) {
                    continue;
                }

                if (declaration.mode.equals(Declaration.Mode.AUTO)) {

                    Declaration.Mode tmpMode = declaration.getMode(stack);

                    if (tmpMode.equals(Declaration.Mode.DIRTY)) {

                        mode = Declaration.Mode.DIRTY;

                        for (Declaration caller : callers) {
                            caller.mode = Declaration.Mode.DIRTY;
                        }

                        break;
                    }
                }
            }
        }

        stack.pop();

        if (mode.equals(Declaration.Mode.AUTO)) {
            mode = Declaration.Mode.CLEAN;
        }

        return mode;
    }

    public void processCalleeIdentities() throws SourceErrorsException {

        if (calleeIdentities == null) {
            return;
        }

        for (CalleeIdentity calleeIdentity : calleeIdentities.values()) {

            if (!Compiler.knownDeclarations.containsKey(calleeIdentity.identity)) {

                throw new SourceErrorsException(
                    new SourceError(
                        calleeIdentity.node,
                        "'" + calleeIdentity.identity + "' is not defined",
                        library));
            }

            Declaration calledDeclaration = Compiler.knownDeclarations.get(calleeIdentity.identity);
            Declaration thisDeclaration = this;

            if (thisDeclaration.callees.contains(calledDeclaration)
                && calledDeclaration.callers.contains(thisDeclaration)) {
                continue;
            }

            thisDeclaration.callees.add(calledDeclaration);
            calledDeclaration.callers.add(thisDeclaration);
        }
    }

    public void processCfg() {

        if (this.startCfgVertex == null) {
            logger.debug(name + " CFG: no start vertex");
            return;
        }

        if (logger.isDebugEnabled()) {
            logger.debug(name + " CFG: " + cfg);
            logger.debug(name + " CFG vertices: " + cfg.vertexSet());
        }

        Boolean hadChange;
        ArrayList<CfgVertex> cfgVertices = new ArrayList<CfgVertex>(cfg.vertexSet());

        Collections.reverse(cfgVertices);

        logger.debug(cfgVertices);

        do {
            //logger.debug("+");

            hadChange = false;

            for (CfgVertex vertex : cfgVertices) {

                Set<Variable> tmp_ins = new HashSet<Variable>(vertex.ins);
                Set<Variable> tmp_outs = new HashSet<Variable>(vertex.outs);

                vertex.ins.clear();
                vertex.ins.addAll(vertex.Rs);

                Set<Variable> t1 = new HashSet<Variable>(vertex.outs);
                t1.removeAll(vertex.Ws);
                vertex.ins.addAll(t1);

                for (CfgVertex successorVertex : getCfgVertexSuccessors(vertex)) {
                    vertex.outs.addAll(successorVertex.ins);
                }

                if (!(tmp_ins.containsAll(vertex.ins) && tmp_outs.containsAll(vertex.outs))) {
                    hadChange = true;
                }
            }
        }
        while (hadChange);

        for (CfgVertex vertex : cfg.vertexSet()) {

            if (logger.isDebugEnabled()) {
                logger.debug(vertex.name + ":");

                String ins = "";
                for (Variable v : vertex.ins) {
                    ins = ins + v.name + " ";
                }
                logger.debug(" ins - " + ins);

                String outs = "";
                for (Variable v : vertex.outs) {
                    outs = outs + v.name + " ";
                }
                logger.debug(" outs - " + outs);
            }

            Set<Variable> garbageVariables = new HashSet<Variable>(variables.values());
            garbageVariables.removeAll(vertex.outs);
        }

        for (Variable variable : startCfgVertex.ins) {

            logger.warn(
                "In " + library.getLongName() + "@" + variable.reads.get(0).node.getLine() + ":" + variable.reads.get(0).node.getCharPositionInLine()
                + " - '" + variable.name + "' is potentially uninitialized"
                + (
                    !variable.writes.isEmpty()
                        ? ", first write is in line " + variable.writes.get(0).node.getLine() + ":" + variable.writes.get(0).node.getCharPositionInLine()
                        : ""
                ) + ".");

            logger.warn("Declaration: " + name);

            for (CfgVertex vertex : variable.reads) {
                logger.warn("Variable '" + variable.name + "' read in " + vertex.node.getLine() + ":" + vertex.node.getCharPositionInLine());
            }

            for (CfgVertex vertex : variable.writes) {
                logger.warn("Variable '" + variable.name + "' written in " + vertex.node.getLine() + ":" + vertex.node.getCharPositionInLine());
            }

        }

        if (Configuration.generateDotFiles) {

            Writer dotWriter;

            String declarationDotDirname = Compiler.dotFileDirectory.getAbsolutePath() + "/declarations";
            File outputDirectory = new File(declarationDotDirname);
            if (outputDirectory.mkdirs()) {
                logger.debug("Declaration DOT file directory exists.");
            }

            try {
                StringNameProvider<CfgVertex> cfgVertexStringNameProvider = new StringNameProvider<CfgVertex>();
                DOTExporter<CfgVertex, DefaultEdge> exporter = new DOTExporter<CfgVertex, DefaultEdge>(cfgVertexStringNameProvider, null, null);

                File dotFile = new File(outputDirectory.getCanonicalPath() + "/" + name + "-" + name + ".dot");
                dotWriter = new BufferedWriter(new FileWriter(dotFile));
                exporter.export(dotWriter, cfg);

                dotWriter.close();
            }
            catch (IOException e) {
                logger.error(e.getMessage());
            }
            catch (Exception e) {
                logger.error(e.getMessage());
            }
        }
    }

    public Integer getNextVariableId() {

        return getNextVariableId(1);
    }

    public Integer getNextVariableId(Integer gap) {

        Integer currentVariableId = variableIdCounterBase;

        variableIdCounterBase = variableIdCounterBase + gap;

        return currentVariableId;
    }
}
