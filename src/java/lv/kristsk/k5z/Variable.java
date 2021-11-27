// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Stack;

public class Variable implements Serializable {

    public enum AccessMode {
        READ, WRITE, READWRITE
    }

    public String name;
    public Declaration declaration;
    private Integer id;
    private Variable parent = null;
    public Boolean transit = false;
    public Boolean neverGarbage = false;
    public Boolean temporary = false;

    public Boolean bindByValue = false;
    public String bindByValueToName;
    transient public ArrayList<CfgVertex> reads = new ArrayList<CfgVertex>();
    transient public ArrayList<CfgVertex> writes = new ArrayList<CfgVertex>();
    transient public ArrayList<CfgVertex> accesses = new ArrayList<CfgVertex>();

    public Variable() {

    }

    public Variable(String name) {

        this.name = name;

        id = 0;

        transit = false;
    }

    public void setId(Integer id) {

        this.id = id;
    }

    public Integer getId() {

        if (id == 0) {
            id = declaration.getNextVariableId();
        }

        return id;
    }

    public Variable getParent() {

        if (parent != null) {
            return parent;
        }
        String parentVariableName = bindByValue ? bindByValueToName : name;

        Declaration declaration = this.declaration.parent;
        Stack<Declaration> declarationStack = new Stack<Declaration>();

        while (declaration != null) {

            if (declaration.variables.containsKey(parentVariableName)) {

                while (!declarationStack.isEmpty()) {
                    Variable variable = declarationStack.peek().getVariable(parentVariableName);
                    variable.parent = declaration.variables.get(parentVariableName);
                    variable.transit = true;
                    declaration = declarationStack.pop();
                }

                parent = declaration.variables.get(parentVariableName);
                return parent;
            }

            declarationStack.push(declaration);
            declaration = declaration.parent;
        }

        parent = this;

        return parent;
    }

    public void addRead(CfgVertex vertex) {

        accesses.add(vertex);
        reads.add(vertex);
    }

    public void addWrite(CfgVertex vertex) {

        accesses.add(vertex);
        writes.add(vertex);
    }
}
