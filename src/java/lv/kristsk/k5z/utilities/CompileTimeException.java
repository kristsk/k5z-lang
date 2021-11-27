// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z.utilities;

import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.tree.CommonTree;

public class CompileTimeException extends RecognitionException {

    public CommonTree commonTreeNode;
    public String message;

    public CompileTimeException(CommonTree node, String message) {

        this.commonTreeNode = node;
        this.message = message;
    }

    @Override
    public String getMessage() {

        return message;
    }

    @Override
    public String toString() {

        if (commonTreeNode != null) {
            return ", line " + commonTreeNode.getLine() + ":" + commonTreeNode.getCharPositionInLine() + " - " + message;
        }
        else {
            return message;
        }
    }
}
