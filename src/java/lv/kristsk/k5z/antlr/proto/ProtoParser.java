// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z.antlr.proto;

import lv.kristsk.k5z.Library;
import lv.kristsk.k5z.utilities.CompileTimeException;
import lv.kristsk.k5z.utilities.SourceError;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.RecognizerSharedState;
import org.antlr.runtime.TokenStream;

import java.util.ArrayList;

public class ProtoParser extends org.antlr.runtime.Parser {

    public Library library = null;
    public ArrayList<SourceError> errors = new ArrayList<SourceError>();

    public ProtoParser(TokenStream stream) {

        super(stream);
    }

    public ProtoParser(TokenStream stream, RecognizerSharedState state) {

        super(stream, state);
    }

    @Override
    public void displayRecognitionError(String[] tokenNames, RecognitionException e) {

        SourceError sourceError;

        if (e instanceof CompileTimeException) {
            sourceError = new SourceError(
                ((CompileTimeException) e).commonTreeNode,
                e.getMessage(),
                this.library);
        }
        else {
            sourceError = new SourceError(
                e,
                getErrorMessage(e, tokenNames),
                this.library);
        }

        errors.add(sourceError);

    }
}
