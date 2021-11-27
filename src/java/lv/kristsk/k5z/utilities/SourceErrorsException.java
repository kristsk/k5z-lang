// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z.utilities;

import lv.kristsk.k5z.Library;
import org.antlr.runtime.tree.CommonTree;
import org.apache.log4j.NDC;

import java.util.ArrayList;

public class SourceErrorsException extends GenericCompilerException {

    public ArrayList<SourceError> errors;

    public SourceErrorsException(ArrayList<SourceError> errors, String message) {

        super(message);

        this.errors = errors;
    }

    public SourceErrorsException(CommonTree node, String message, Library library) {

        super();

        SourceError error = new SourceError(node, message, library);

        errors = new ArrayList<SourceError>();
        errors.add(error);
    }

    public SourceErrorsException(SourceError error) {

        super();

        errors = new ArrayList<SourceError>();
        errors.add(error);
    }

    public SourceErrorsException(SourceError error, String message) {

        super(message);

        errors = new ArrayList<SourceError>();
        errors.add(error);
    }

    @Override
    public String toString() {

        NDC.clear();
        for (SourceError error : errors) {
            lv.kristsk.k5z.Compiler.logger.error(error);
        }

        return "There were " + errors.size() + " compile error(s)";
    }
}
