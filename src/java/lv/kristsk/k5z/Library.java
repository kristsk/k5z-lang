// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z;

import com.esotericsoftware.kryo.io.Input;
import com.esotericsoftware.kryo.io.Output;
import lv.kristsk.k5z.antlr.parsers.*;
import lv.kristsk.k5z.utilities.Common;
import lv.kristsk.k5z.utilities.GenericCompilerException;
import lv.kristsk.k5z.utilities.SourceError;
import lv.kristsk.k5z.utilities.SourceErrorsException;
import org.antlr.runtime.ANTLRInputStream;
import org.antlr.runtime.CommonTokenStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.tree.CommonTree;
import org.antlr.runtime.tree.CommonTreeNodeStream;
import org.antlr.runtime.tree.DOTTreeGenerator;
import org.antlr.stringtemplate.StringTemplate;
import org.antlr.stringtemplate.StringTemplateGroup;
import org.apache.log4j.Logger;
import org.apache.log4j.NDC;

import java.io.*;
import java.util.*;

public class Library implements Serializable {

    public enum State {
        SOURCE, PARSED, PARSING, COMPILING, COMPILED, FAILED
    }

    public enum Type {
        PHP, K5Z
    }

    public class ImportDefinition implements Serializable {

        public String name;
        public String path;
        public String alias;
        public Long compileNanoTime = 0L;

        public ImportDefinition() {

        }

        public ImportDefinition(String name, String path) {

            this.name = name;
            this.path = path;
        }

        public ImportDefinition(String name, String path, String alias) {

            this.name = name;
            this.path = path;
            this.alias = alias;
        }

        @Override
        public String toString() {

            return "[name: " + name + ", path: " + path + ", compileNanoTime: " + compileNanoTime + "]";
        }
    }

    public static class LoadException extends GenericCompilerException {

        public LoadException(String message) {

            super(message);
        }

        @SuppressWarnings("unused")
        public LoadException() {

            super();
        }
    }

    public static class ImportLoadException extends GenericCompilerException {

        Library library = null;
        Library importedLibrary = null;
        ImportDefinition importDefinition = null;

        public ImportLoadException(Library library, Library importedLibrary, ImportDefinition importDefinition, String message) {

            super(message);

            this.library = library;
            this.importedLibrary = importedLibrary;
            this.importDefinition = importDefinition;
        }

        @Override
        public String toString() {

            return this.getMessage();
        }
    }

    abstract public static class ImportLibraryClashException extends GenericCompilerException {

        Library library1 = null;
        Library library2 = null;

        public ImportLibraryClashException(Library library1, Library library2) {

            super();
            this.library1 = library1;
            this.library2 = library2;
        }

        @Override
        public String toString() {

            return super.toString() + " library1: " + library1.getLongName() + ", library2: " + library2.getLongName();
        }
    }

    public static class ImportLibraryNameClashException extends ImportLibraryClashException {

        public ImportLibraryNameClashException(Library library1, Library library2) {

            super(library1, library2);
        }
    }

    public static class ImportLibraryVersionClashException extends ImportLibraryClashException {

        public ImportLibraryVersionClashException(Library library1, Library library2) {

            super(library1, library2);
        }
    }

    public static class IncludeLoadException extends LoadException {

        public IncludeLoadException(String message) {

            super(message);
        }
    }

    public static class Include implements Serializable {

        public String relativeFilename;
        public Long modificationNanoTime = 0L;

        public Library library;

        transient public String contents;

        public boolean hasOpeningTag = false;
        public boolean hasClosingTag = false;

        public Include() {

        }

        public Include(Library library, String filename) {

            this.library = library;
            this.relativeFilename = filename;

            String filenameForLoading = getFullFilename();

            try {
                this.contents = Common.readFromFilenameAsString(filenameForLoading);

                if (this.contents.startsWith("<?php")) {
                    this.hasOpeningTag = true;
                    this.contents = this.contents.substring(5);
                }

                if (this.contents.endsWith("?>")) {
                    this.hasClosingTag = true;
                    this.contents = this.contents.substring(0, this.contents.length() - 2);
                }

                File file = new File(filenameForLoading);

                this.modificationNanoTime = file.lastModified();

                Library.logger.debug("Include file " + this.relativeFilename
                                     + " hasOpeningTag: " + this.hasOpeningTag + ", "
                                     + " hasClosingTag: " + this.hasClosingTag + ", "
                                     + " modificationNanoTime: " + this.modificationNanoTime
                );

            }
            catch (IOException e) {
                throw new Library.IncludeLoadException("could not read include file - " + e.getMessage());
            }
        }

        public String getFullFilename() {

            return this.library.sourceFile.getParent() + File.separator + this.relativeFilename;
        }

        public String getSafeContent() {

            StringBuilder sb = new StringBuilder();

            if (!this.hasOpeningTag) {
                sb.append("?>");
            }

            sb.append(this.contents);

            if (!this.hasClosingTag) {
                sb.append("<?php");
            }

            return sb.toString();
        }

        public Boolean fileExists() {

            File file = new File(this.getFullFilename());

            return file.exists();
        }

        public boolean isUptodate() {

            File file = new File(this.getFullFilename());

            return file.lastModified() <= this.modificationNanoTime;
        }

        public ArrayList<String> getCompileMeta() {

            ArrayList<String> libraryMeta = new ArrayList<String>();

            File file = new File(this.getFullFilename());

            if (file.exists()) {
                try {
                    libraryMeta.add("'" + this.relativeFilename + "'");
                    libraryMeta.add(this.modificationNanoTime.toString());
                    libraryMeta.add("'" + file.getCanonicalPath() + "'");
                    libraryMeta.add("'" + library.compiledFile.getCanonicalPath() + "'");
                }
                catch (IOException ignored) {
                }
            }

            return libraryMeta;
        }

    }

    public static class IncludeWithFunctions extends Include {

        public IncludeWithFunctions(Library library, String filename) {

            super(library, filename);
        }
    }

    transient public static Logger logger;

    public HashMap<String, Declaration> declarations;
    public HashMap<String, ImportDefinition> importNameToDefinitionMap;
    public LinkedHashSet<ImportDefinition> importOrder;
    public HashMap<String, ImportDefinition> importAliasToDefinitionMap;

    public String name;
    public Boolean isProgram;

    transient public File sourceFile;
    transient public File compiledFile;
    transient public File saveFile;

    transient public boolean isInternal = false;

    public Long compileNanoTime;
    public Type type;
    public State state;
    public String compileResult;

    transient public CommonTree library_ast_tree;
    transient public CommonTreeNodeStream library_ast_nodes;
    transient public CommonTokenStream library_tokens;

    public HashMap<String, Include> includes;

    static {
        logger = Common.logger;
    }

    public Library() {

        compileResult = "";
        state = State.SOURCE;
        type = Type.K5Z;

        compileNanoTime = 0L;

        importNameToDefinitionMap = new HashMap<String, ImportDefinition>();
        importAliasToDefinitionMap = new HashMap<String, ImportDefinition>();
        importOrder = new LinkedHashSet<ImportDefinition>();
        declarations = new HashMap<String, Declaration>();

        includes = new HashMap<String, Include>();

        sourceFile = null;
        compiledFile = null;
        saveFile = null;

        isProgram = false;
    }

    public Library(File sourceFile) {

        this();

        this.sourceFile = sourceFile;

        parseSource();
    }

    @Override
    public String toString() {

        return "[" + name + "]";
    }

    public static Library readCompiledFromStream(InputStream in) {

        Library library;

        try {

            Input input = new Input(in);
            library = Common.kryo.readObject(input, Library.class);
            input.close();

            for (Declaration declaration : library.declarations.values()) {

                declaration.library = library;
                declaration.callers = new HashSet<Declaration>();
            }

            return library;
        }
        catch (Exception e) {

            logger.trace(e);

            // catches both IOException and ClassNotFoundException
            throw new Library.LoadException("Could not load library from stream - " + e.getMessage());
        }
    }

    public static Library load(InputStream in, String sourceFilename, String compiledFilename) {

        Library library;

        logger.debug("Starting to load from stream...");

        library = readCompiledFromStream(in);

        logger.debug("Done");

        library.sourceFile = new File(sourceFilename);
        library.compiledFile = new File(compiledFilename);

        library.register(Compiler.LibraryLoadStrategy.ONLY_COMPILED);

        return library;
    }

    public static Library loadInternal(InputStream in) {

        Library library = Library.load(in, "<internal>", "<internal>");

        library.isInternal = true;

        return library;
    }

    public static Library load(File file, Compiler.LibraryLoadStrategy loadStrategy) {

        Library library;

        File sourceFile = file;
        File compiledFile = file;

        if (hasCompiledFilename(file)) {
            sourceFile = sourceFileFromCompiledFile(file);
        }
        else if (hasSourceFilename(file)) {
            compiledFile = compiledFileFromSourceFile(file);
        }

        logger.debug("LIBRARY.LOAD: " + compiledFile + " COMPILED EXISTS: " + compiledFile.exists());
        logger.debug("LIBRARY.LOAD: " + sourceFile + " SOURCE EXISTS: " + sourceFile.exists());

        if (
            compiledFile.exists() // if compiled file exists ...
            &&
            (
                (
                    sourceFile.exists() // ... and source file also exists
                    &&
                    sourceFile.lastModified() < compiledFile.lastModified() // ... and compiled file is more recent
                )
                ||
                !sourceFile.exists() // ... or source file does not exist
            )
            &&
            (
                (
                    !loadStrategy.equals(Compiler.LibraryLoadStrategy.PREFER_SOURCE) // ... and we are not forcing compile from source
                    ||
                    !sourceFile.exists() // ... or source file does not exist
                )
            )
        ) {
            // ... then try to load compiled file
            try {
                logger.debug("Loading library from compiled file " + compiledFile + " ...");

                library = readCompiledFromStream(new FileInputStream(compiledFile));

                library.compiledFile = compiledFile;
                library.sourceFile = sourceFile;

                logger.debug("Checking included files...");
                for (Include include : library.includes.values()) {
                    if (include.fileExists()) {
                        if (!include.isUptodate()) {
                            LoadException loadException = new LoadException("Included file " + include.relativeFilename + " has been modified since last compile.");
                            logger.debug(loadException.getMessage());
                            throw loadException;
                        }
                        else {
                            logger.debug("Included file " + include.relativeFilename + " up to date with existing file.");
                        }
                    }
                    else {
                        logger.debug("Included file " + include.relativeFilename + " not found in filesystem, assuming it is OK.");
                    }
                }

                library.register(loadStrategy);

                return library;

            }
            catch (FileNotFoundException e) {

                if (loadStrategy.equals(Compiler.LibraryLoadStrategy.ONLY_COMPILED)) {

                    throw new LoadException("Could not load library from compiled file " + compiledFile + " - " + e.getMessage());
                }
            }
//            catch (ImportLoadException e) {
//
//                throw e;
//            }
            catch (LoadException e) {

                if (loadStrategy.equals(Compiler.LibraryLoadStrategy.ONLY_COMPILED)) {

                    throw e;
                }
            }
        }

        if (loadStrategy.equals(Compiler.LibraryLoadStrategy.ONLY_COMPILED)) {

            throw new LoadException("Could not load library from compiled file " + compiledFile + " - non-existent or too old?)");
        }

        library = new Library(sourceFile);

        library.register(loadStrategy);

        return library;
    }

    public static Library load(String filename, Collection<String> libraryPaths, Compiler.LibraryLoadStrategy loadStrategy) {

        LoadException lastLoadException = null;

        for (String libraryPath : libraryPaths) {

            File file = new File(libraryPath + File.separator + filename);

            try {
                return Library.load(file, loadStrategy);
            }
            catch (IncludeLoadException e) {
                lastLoadException = e;
                break;
            }
            catch (LoadException e) {
                lastLoadException = e;
            }
        }

        throw lastLoadException;
    }

    public static Boolean hasCompiledFilename(File file) {

        return file.getAbsolutePath().toLowerCase().endsWith(".k5z.lib");
    }

    public static Boolean hasSourceFilename(File file) {

        return file.getAbsolutePath().toLowerCase().endsWith(".k5z");
    }

    public static File compiledFileFromSourceFile(File sourceFile) {

        if (!hasSourceFilename(sourceFile)) {
            throw new Library.LoadException("not a source file - " + sourceFile);
        }

        return new File(sourceFile.getAbsolutePath() + ".lib");
    }

    public static File sourceFileFromCompiledFile(File compiledFile) {

        if (!hasCompiledFilename(compiledFile)) {
            throw new Library.LoadException("not a compiled file - " + compiledFile);
        }

        String compiledFilename = compiledFile.getAbsolutePath();

        return new File(compiledFilename.substring(0, compiledFilename.length() - 4));
    }

    public void addImportDefinition(String name, String path, String alias) {

        ImportDefinition importDefinition = new ImportDefinition(name, path, alias);

        importAliasToDefinitionMap.put(alias, importDefinition);
        importNameToDefinitionMap.put(name, importDefinition);
        importOrder.add(importDefinition);
    }

    public void addDeclaration(Declaration declaration) {

        declaration.library = this;

        logger.debug("ADD DECLARATION: " + declaration.getPrintableFormalDeclaration());

        declarations.put(declaration.name, declaration);
    }

    private void parseSource() {

        if (!sourceFile.exists()) {
            throw new Library.LoadException("source file " + sourceFile + " does not exist");
        }

        logger.info("Parsing " + getLongName() + " ...");

        if (state.equals(State.PARSED)) {

            logger.info(getLongName() + " is already parsed, skipping");
            return;
        }

        compileNanoTime = Compiler.nanoTimeNow;

        NDC.push(" ");

        try {

            ANTLRInputStream inputStream = new ANTLRInputStream(new FileInputStream(sourceFile));

            AstLexer library_lexer = new AstLexer(inputStream);
            library_lexer.library = this;

            if (!library_lexer.errors.isEmpty()) {

                logger.debug("LEXER ERRORS: " + library_lexer.errors);
                throw new SourceErrorsException(library_lexer.errors, "lexer errors");
            }

            library_tokens = new CommonTokenStream(library_lexer);
            AstParser library_ast_parser = new AstParser(library_tokens);
            library_ast_parser.library = this;

            AstParser.library_return library_ast = library_ast_parser.library();

            if (!library_ast_parser.errors.isEmpty()) {

                logger.debug("AST PARSER ERRORS: " + library_ast_parser.errors);
                throw new SourceErrorsException(library_ast_parser.errors, "parser errors");
            }

            library_ast_tree = (CommonTree) library_ast.getTree();

            if (Configuration.printAsts) {
                logger.debug("SOURCE AST: " + library_ast_tree.toStringTree());
            }

            if (!Configuration.withoutCore) {

                ImportDefinition coreImportDefinition = new ImportDefinition(Compiler.coreLibrary.name, null);
                coreImportDefinition.compileNanoTime = Compiler.coreLibrary.compileNanoTime;
                importNameToDefinitionMap.put(Compiler.coreLibrary.name, coreImportDefinition);
                importAliasToDefinitionMap.put(Compiler.coreLibrary.name, coreImportDefinition);
            }

            library_ast_nodes = new CommonTreeNodeStream(library_ast_tree);
            library_ast_nodes.setTokenStream(library_tokens);
            SymbolMapperParser symbolMapper = new SymbolMapperParser(library_ast_nodes);
            symbolMapper.library = this;
            symbolMapper.library();

            if (!symbolMapper.errors.isEmpty()) {

                logger.debug("SYMBOL MAPPER ERRORS: " + symbolMapper.errors);
                throw new SourceErrorsException(symbolMapper.errors, "symbol mapper errors");
            }

            state = State.PARSED;

            logger.info("Parsing of " + getLongName() + " successful");
        }
        catch (IOException e) {
            String message = "Parsing of " + getLongName() + " failed - " + e;
            logger.info(message);
        }
        catch (RecognitionException e) {

            String message = "Parsing of " + getLongName() + " failed - " + e;
            logger.info(message);
            throw new SourceErrorsException(
                new SourceError(
                    e.line,
                    e.charPositionInLine,
                    message,
                    this));
        }
        finally {
            NDC.pop();
        }
    }

    public void register(Compiler.LibraryLoadStrategy loadStrategy) {

        logger.debug("Registering " + getLongName() + " ... ");

        NDC.push(" ");

        Compiler.addKnownLibrary(this);

        logger.debug("Import definitions: " + importNameToDefinitionMap);
        loadImportedLibraries(loadStrategy);

        logger.debug("Checking declarations of " + getLongName() + "...");
        NDC.push(" ");

        for (Declaration declaration : declarations.values()) {
            declaration.processCalleeIdentities();
        }

        NDC.pop();

        logger.debug("Registering of " + getLongName() + " successful");

        NDC.pop();
    }

    public void compile() {

        logger.info("Compiling " + getLongName() + " ...");
        NDC.push(" ");

        try {

            if (!state.equals(State.PARSED)) {
                throw new Library.LoadException("library not in state PARSED");
            }

            state = State.COMPILING; // need this to prevent looping

            logger.debug("Starting CompilerParser...");

            library_ast_nodes = new CommonTreeNodeStream(library_ast_tree);
            library_ast_nodes.setTokenStream(library_tokens);
            CompilerParser compiler = new CompilerParser(library_ast_nodes);
            compiler.library = this;
            CompilerParser.library_return compiled_library_ast = compiler.library();

            logger.debug("Done");

            if (!compiler.errors.isEmpty()) {

                logger.debug("CompilerParser errors: " + compiler.errors);
                throw new SourceErrorsException(compiler.errors, "compiler errors");
            }

            CommonTree compiled_library_ast_tree = (CommonTree) compiled_library_ast.getTree();

            if (Configuration.printAsts) {
                logger.debug("Compiled AST: " + compiled_library_ast_tree.toStringTree());
            }

            logger.debug("Starting VariableAccessMapperParser...");

            CommonTreeNodeStream compiled_library_ast_nodes = new CommonTreeNodeStream(compiled_library_ast_tree);
            compiled_library_ast_nodes.setTokenStream(library_tokens);
            VariableAccessMapperParser variableAccessMapper = new VariableAccessMapperParser(compiled_library_ast_nodes);
            variableAccessMapper.library = this;
            variableAccessMapper.library();

            logger.debug("Done");

            if (!variableAccessMapper.errors.isEmpty()) {

                logger.debug("VariableAccessMapperParser errors: " + variableAccessMapper.errors);
                throw new SourceErrorsException(variableAccessMapper.errors, "variable access mapper errors");
            }

            logger.debug("Starting CFG processing...");
            for (Declaration declaration : declarations.values()) {
                declaration.processCfg();
            }
            logger.debug("Done");

            if (Configuration.generateDotFiles) {
                generateDotFiles(compiled_library_ast_tree);
            }

            StringTemplateGroup templates = Common.getK5zPhpStgTemplateGroup();

            logger.debug("Starting EmitterParser...");

            compiled_library_ast_nodes = new CommonTreeNodeStream(compiled_library_ast_tree);
            compiled_library_ast_nodes.setTokenStream(library_tokens);
            EmitterParser emitter = new EmitterParser(compiled_library_ast_nodes);
            emitter.library = this;
            emitter.setTemplateLib(templates);
            emitter.library();

            logger.debug("Done");

            if (!emitter.errors.isEmpty()) {

                logger.debug("EmitterParser errors: " + emitter.errors);
                throw new SourceErrorsException(emitter.errors, "emitter errors");
            }

            logger.debug("Processing includes...");

            for (Include include : this.includes.values()) {
                if (include instanceof IncludeWithFunctions) {

                    StringBuilder a = new StringBuilder();

                    if (!include.hasOpeningTag) {
                        a.append("\n?>");
                    }

                    a.append(include.contents);

                    if (!include.hasOpeningTag && !include.hasClosingTag) {
                        a.append("<?php\n");
                    }

                    this.compileResult = a.toString() + this.compileResult;
                }
            }

            logger.debug("Done");

            state = State.COMPILED;

            save();

            logger.debug("Compiling of " + getLongName() + " successful");
        }
        catch (RecognitionException e) {

            String message = "Compiling of " + getLongName() + " failed - " + e;
            logger.debug(message);

            throw new SourceErrorsException(
                new SourceError(
                    e.line,
                    e.charPositionInLine,
                    message,
                    this));
        }
        finally {
            NDC.pop();
        }
    }

    public String link() {

        logger.info("Linking " + importNameToDefinitionMap.keySet() + "...");

        NDC.push(" ");

        Declaration.Identity mainDeclarationIdentity = new Declaration.Identity(this.name, "Main");

        if (!Compiler.knownDeclarations.containsKey(mainDeclarationIdentity)) {
            throw new GenericCompilerException("Function 'Main' is not defined!");
        }

        StringTemplateGroup templates;

        try {
            InputStream in = Common.getK5zPhpStgResourceStream();
            templates = new StringTemplateGroup(new InputStreamReader(in));
            in.close();
        }
        catch (IOException e) {
            throw new GenericCompilerException("Could not load translation template");
        }

        ArrayList<String> programStateProcessors = new ArrayList<String>();
        ArrayList<String> bootstrappers = new ArrayList<String>();
        ArrayList<String> linkedLibraryCode = new ArrayList<String>();

        StringTemplate programTemplate = templates.getInstanceOf("program_output");

        String programVersion = "v" + compileNanoTime.toString();

        programTemplate.setAttribute("compile_date", (new Date(compileNanoTime)).toString());
        programTemplate.setAttribute("compiler_version", Compiler.class.getPackage().getImplementationVersion());
        programTemplate.setAttribute("program_name", name);
        programTemplate.setAttribute("program_version", programVersion);
        programTemplate.setAttribute("with_debug_info", !Configuration.withoutDebug);

        HashSet<Library> linkedLibraries = new HashSet<Library>();

        linkLibrary(
            templates,
            programStateProcessors,
            bootstrappers,
            linkedLibraryCode,
            programVersion,
            Compiler.coreLibrary
        );
        linkedLibraries.add(Compiler.coreLibrary);

        for (Object libraryImport : importOrder) {

            Library library = Compiler.knownLibraries.get(((ImportDefinition) libraryImport).name);

            if (!linkedLibraries.contains(library)) {
                linkLibrary(
                    templates,
                    programStateProcessors,
                    bootstrappers,
                    linkedLibraryCode,
                    programVersion,
                    library
                );
                linkedLibraries.add(library);
            }
        }

        for (Library library : Compiler.knownLibraries.values()) {

            if (!linkedLibraries.contains(library)) {
                linkLibrary(
                    templates,
                    programStateProcessors,
                    bootstrappers,
                    linkedLibraryCode,
                    programVersion,
                    library
                );
            }
        }

//		try {
//			for (Declaration declaration : Compiler.knownDeclarations.values()) {
//				logger.debug(declaration.name + ": " + declaration.hasDirtyCallees().toString());
//			}
//		} catch (Common.CompileTimeException ignore) {
//
//		}
//		catch(java.lang.NullPointerException e) {
//			e.printStackTrace();
//		}


        programTemplate.setAttribute("linked_library_code", linkedLibraryCode);
        programTemplate.setAttribute("name", this.name);
        programTemplate.setAttribute("bootstrappers", bootstrappers);
        programTemplate.setAttribute("program_state_processors", programStateProcessors);

        NDC.pop();
        logger.info("Linking done.");

        return programTemplate.toString();
    }

    private void linkLibrary(
        StringTemplateGroup templates,
        ArrayList<String> programStateProcessors,
        ArrayList<String> bootstrappers,
        ArrayList<String> linkedLibraries,
        String programVersion,
        Library library
    ) {

        logger.info("Linking " + library.getLongName() + "...");

        if (logger.isDebugEnabled()) {
            logger.debug("Declarations: " + library.declarations.keySet());
        }

        StringTemplate linkedLibraryTemplate = templates.getInstanceOf("linked_library_output");

        linkedLibraryTemplate.setAttribute("name", library.name);
        linkedLibraryTemplate.setAttribute("program_name", name);
        linkedLibraryTemplate.setAttribute("program_version", programVersion);
        linkedLibraryTemplate.setAttribute("with_debug_info", !Configuration.withoutDebug);

        bootstrappers.add(library.name);
        programStateProcessors.add(library.name);

        if (!Configuration.withoutDebug) {
            linkedLibraryTemplate.setAttribute(
                "source_filename",
                library.isInternal
                    ? ""
                    : library.sourceFile.getAbsolutePath()
            );
        }

        List<ArrayList<String>> metas = new ArrayList<ArrayList<String>>();

        metas.add(library.getCompileMeta());

        for (Include include : library.includes.values()) {
            metas.add(include.getCompileMeta());
        }

        linkedLibraryTemplate.setAttribute("metas", metas);

        linkedLibraryTemplate.setAttribute("content", library.compileResult);

        linkedLibraries.add(linkedLibraryTemplate.toString());
    }

    public ArrayList<String> getCompileMeta() {

        ArrayList<String> libraryMeta = new ArrayList<String>();

        if (compiledFile != null && compiledFile.exists()) {
            try {
                libraryMeta.add("'" + this.name + "'");
                libraryMeta.add(Long.toString(this.compiledFile.lastModified()));
                libraryMeta.add("'" + this.sourceFile.getCanonicalPath() + "'");
                libraryMeta.add("'" + this.compiledFile.getCanonicalPath() + "'");
            }
            catch (IOException ignored) {
            }
        }

        return libraryMeta;
    }

    public void save() {

        try {

            logger.debug("Starting save...");

            if (compiledFile == null) {
                compiledFile = compiledFileFromSourceFile(sourceFile);
            }

            for (String declarationName : declarations.keySet()) {

                declarations.get(declarationName).library = null;
                declarations.get(declarationName).callers = null;
            }

            FileOutputStream fos = new FileOutputStream(compiledFile);

            Output output = new Output(fos);
            Common.kryo.writeObject(output, this);
            output.close();

            if (!compiledFile.setLastModified(this.compileNanoTime)) {
                throw new Library.LoadException("Could not set last modified time to " + compiledFile);
            }

            logger.debug("Done");

            logger.info("Wrote to file '" + compiledFile.getCanonicalPath() + "'");
        }
        catch (Exception e) {
            throw new Library.LoadException("Could not save to " + compiledFile + " - " + e);
        }
    }

    public String getLongName() {

        File file = sourceFile.exists() ? sourceFile : compiledFile;

        String filename;

        String currentDirectory = System.getProperty("user.dir");

        if (file.exists()) {

            try {

                filename = file.getCanonicalPath();
            }
            catch (IOException e) {

                filename = file.getAbsolutePath();
            }
        }
        else {

            filename = file.getAbsolutePath();
        }

        if (filename.startsWith(currentDirectory)) {

            filename = filename.replaceFirst(currentDirectory, ".");
        }

        if (name == null) {

            return "(" + filename + ")";
        }
        else {

            return "'" + name + "' (" + filename + ")";
        }
    }

    private void loadImportedLibraries(Compiler.LibraryLoadStrategy loadStrategy) {

        for (ImportDefinition importDefinition : importNameToDefinitionMap.values()) {

            Library importedLibrary;

            logger.debug("LOADING IMPORT DEFINITION FOR " + name + " => " + importDefinition);

            if (Compiler.knownLibraries.containsKey(importDefinition.name)) {

                logger.debug("IMPORT DEFINITION NAME " + importDefinition.name + " FOUND IN KNOWN LIBRARIES");

                importedLibrary = Compiler.knownLibraries.get(importDefinition.name);

                if (state.equals(State.COMPILED)) {

                    if (importDefinition.compileNanoTime < importedLibrary.compileNanoTime) { // if imported library has a newer compiled version

                        logger.debug("+++ COMPILED IMPORT DEFINITION REQUIRES OLDER IMPORTED LIBRARY");
                        logger.debug("+++ COMPILED IMPORT DEFINITION.CNT: " + importDefinition.compileNanoTime);
                        logger.debug("+++ IMPORTED LIBRARY.CNT : " + importedLibrary.compileNanoTime);

                        ArrayList<String> importingLibraryNames = new ArrayList<String>();
                        for (Library importingLibrary : Compiler.getImportingLibraries(this)) {

                            importingLibraryNames.add(importingLibrary.getLongName());
                        }

                        throw new ImportLoadException(
                            this,
                            importedLibrary,
                            importDefinition,
                            "Compiled library " + this.getLongName() + " " +
                            "requires older version of library " +
                            importedLibrary.getLongName() + " than we have now. " +
                            "It is used in: " + org.apache.commons.lang.StringUtils.join(importingLibraryNames, ",")
                        );
                    }
                    else if (importDefinition.compileNanoTime > importedLibrary.compileNanoTime) {

                        logger.debug("+++ COMPILED IMPORT DEFINITION REQUIRES NEWER IMPORTED LIBRARY");
                        logger.debug("+++ IMPORT DEFINITION.CNT: " + importDefinition.compileNanoTime);
                        logger.debug("+++ IMPORTED LIBRARY.CNT : " + importedLibrary.compileNanoTime);

                        ArrayList<String> importingLibraryNames = new ArrayList<String>();
                        for (Library importingLibrary : Compiler.getImportingLibraries(this)) {

                            importingLibraryNames.add(importingLibrary.getLongName());
                        }

                        throw new ImportLoadException(
                            this,
                            importedLibrary,
                            importDefinition,
                            "Compiled library " + this.getLongName() + " " +
                            "requires more recent version of library " +
                            importedLibrary.getLongName() + " than we have now. " +
                            "It is used in: " + org.apache.commons.lang.StringUtils.join(importingLibraryNames, ",")
                        );
                    }
                }
            }
            else {

                String relativeFilename = importDefinition.path + File.separator + importDefinition.name + ".k5z";

                Collection<String> localImportPaths = new ArrayList<String>(Configuration.libraryPaths);
                localImportPaths.add(sourceFile.getParentFile().getPath() + File.separator);

                if (state.equals(Library.State.COMPILED)) {

                    importedLibrary = Library.load(relativeFilename, localImportPaths, Compiler.LibraryLoadStrategy.ONLY_COMPILED);
                }
                else {

                    importedLibrary = Library.load(relativeFilename, localImportPaths, loadStrategy);
                }

                if (
                    state.equals(Library.State.COMPILED)
                    &&
                    !importedLibrary.compileNanoTime.equals(importDefinition.compileNanoTime)
                ) {

                    logger.debug("+++ LOADED LIBRARY COMPILE NANO TIME NOT SAME AS IN IMPORT DEFINITION");
                    logger.debug("+++ IMPORTED LIBRARY.CNT : " + importedLibrary.compileNanoTime);
                    logger.debug("+++ IMPORT DEFINITION.CNT: " + importDefinition.compileNanoTime);

                    throw new ImportLoadException(
                        this,
                        importedLibrary,
                        importDefinition,
                        "In library " + this.getLongName() + " " +
                        "compile times of an import definition and library found for it " +
                        importedLibrary.getLongName() + " do not match"
                    );
                }
            }

            importDefinition.compileNanoTime = importedLibrary.compileNanoTime;
            Compiler.addLibraryDependency(this, importedLibrary);

            logger.debug("RESOLVED IMPORT DEFINITION " + importDefinition);
        }
    }

    private void readObject(ObjectInputStream ois) throws IOException, ClassNotFoundException {

        ois.defaultReadObject();
    }

    private void generateDotFiles(CommonTree compiled_library_ast_tree) {

        DOTTreeGenerator gen = new DOTTreeGenerator();

        //noinspection SpellCheckingInspection
        DOTTreeGenerator._treeST = new StringTemplate(
            "digraph {\n\n"
            + "\tordering=out;\n"
            + "\tranksep=.4;\n"
            + "\tbgcolor=\"white\"; node [shape=box, fixedsize=false, fontsize=12, fontname=\"Helvetica-bold\", fontcolor=\"blue\"\n"
            + "\t\twidth=.25, height=.25, color=\"black\", fillcolor=\"white\", style=\"filled, solid\"];\n"
            + "\tedge [arrowsize=.5, color=\"black\", style=\"bold\"]\n\n"
            + "  $nodes$\n"
            + "  $edges$\n"
            + "}\n");

        StringTemplate st = gen.toDOT(library_ast_tree);
        try {

            File dotFile = new File(Compiler.dotFileDirectory.getAbsolutePath() + "/AST-" + name + ".dot");
            FileOutputStream dotFileStream = new FileOutputStream(dotFile);
            dotFileStream.write(st.toString().getBytes());
            dotFileStream.close();
        }
        catch (IOException e) {
            logger.error(e.getMessage());
        }

        st = gen.toDOT(compiled_library_ast_tree);

        try {

            File dotFile = new File(Compiler.dotFileDirectory.getAbsolutePath() + "/COMPILED-" + name + ".dot");
            FileOutputStream dotFileStream = new FileOutputStream(dotFile);
            dotFileStream.write(st.toString().getBytes());
            dotFileStream.close();
        }
        catch (IOException e) {
            logger.error(e.getMessage());
        }
    }

    public void exportAst() {

        try {
            InputStream in = new FileInputStream(Configuration.customStgFilename);

            StringTemplateGroup templates = new StringTemplateGroup(new InputStreamReader(in));
            in.close();

            CommonTreeNodeStream library_ast_nodes2 = new CommonTreeNodeStream(library_ast_tree);
            library_ast_nodes2.setTokenStream(library_tokens);
            AstExportParser exporter = new AstExportParser(library_ast_nodes2);
            exporter.setTemplateLib(templates);

            AstExportParser.library_return libraryReturn = exporter.library();

            logger.info("=============" + libraryReturn.toString());

        }
        catch (RecognitionException e) {
            e.printStackTrace();
        }
        catch (FileNotFoundException e) {
            e.printStackTrace();
        }
        catch (IOException e) {
            e.printStackTrace();
        }
    }
}
