// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z.utilities;

import lv.kristsk.k5z.Declaration;
import lv.kristsk.k5z.Library;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.tree.CommonTree;

public class SourceError {

    Integer line = -1;
    Integer charPositionInLine = -1;
    public String filename = "";
    public String message = null;
    Library library = null;
    Declaration declaration = null;
    Declaration function = null;

    public SourceError(Integer line, Integer charPositionInLine, String message, Library library) {

        this.filename = library.sourceFile.getAbsolutePath();
        this.line = line;
        this.charPositionInLine = charPositionInLine;
        this.message = message;
        this.library = library;
    }

    public SourceError(RecognitionException e, String message, Library library) {

        this(e.line, e.charPositionInLine, message, library);
        //this.filename = library.sourceFile.getAbsolutePath();
        //this.line = e.line;
        //this.charPositionInLine = e.charPositionInLine;
        //this.message = message;
        //this.library = library;
    }

    public SourceError(CommonTree node, String message, Library library) {

        this(node.getLine(), node.getCharPositionInLine(), message, library);
        //this.line = node.getLine();
        //this.charPositionInLine = node.getCharPositionInLine();
        //this.filename = library.sourceFile.getAbsolutePath();
        //this.message = message;
        //this.library = library;
    }

    @Override
    public String toString() {

        if (library != null) {
            return library.getLongName() + " in " + line + ":" + charPositionInLine + " - " + message;
        }
        else {
            return "somewhere(!?) in " + line + ":" + charPositionInLine + " - " + message;
        }
    }
}
