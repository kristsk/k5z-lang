// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z;

import org.antlr.runtime.tree.CommonTree;

import java.util.HashSet;
import java.util.Set;

public class CfgVertex {

    static Integer cfgVertexCounter = 0;

    public String name;
    public Set<Variable> Rs = new HashSet<Variable>();
    public Set<Variable> Ws = new HashSet<Variable>();
    public Set<Variable> ins = new HashSet<Variable>();
    public Set<Variable> outs = new HashSet<Variable>();

    public CommonTree node;

    public Integer cfgVertexNumber = 0;

    public CfgVertex() {

        cfgVertexNumber = cfgVertexCounter++;
    }

    public CfgVertex(Variable v, Variable.AccessMode accessMode, CommonTree node) {

        this();

        this.node = node;
        if (accessMode.equals(Variable.AccessMode.READ)) {
            name = "R" + v.name;
            Rs.add(v);
            v.addRead(this);
        }
        else if (accessMode.equals(Variable.AccessMode.WRITE)) {
            name = "W" + v.name;
            Ws.add(v);
            v.addWrite(this);
        }

    }

    public CfgVertex(String name) {

        this();
        this.name = name;
    }

    public String getName() {

        return "N" + cfgVertexNumber.toString() + "_" + this.name;
    }

    @Override
    public String toString() {

        return getName();
    }
}
