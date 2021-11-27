// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z;

import lv.kristsk.k5z.utilities.Common;
import lv.kristsk.k5z.utilities.GenericCompilerException;
import lv.kristsk.k5z.utilities.SourceError;
import lv.kristsk.k5z.utilities.SourceErrorsException;
import org.apache.commons.cli.*;
import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.apache.log4j.NDC;
import org.jgrapht.DirectedGraph;
import org.jgrapht.ext.DOTExporter;
import org.jgrapht.ext.IntegerNameProvider;
import org.jgrapht.ext.StringNameProvider;
import org.jgrapht.graph.DefaultDirectedGraph;
import org.jgrapht.graph.DefaultEdge;

import java.io.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;

public class Compiler {

    public static Logger logger = Common.logger;

    public enum LibraryLoadStrategy {
        ONLY_COMPILED,
        PREFER_SOURCE,
        DEFAULT
    }

    public static CommandLine commandLine;
    public static Library coreLibrary = null;

    public static HashMap<String, Library> knownLibraries = new HashMap<String, Library>();
    public static LinkedHashSet<Library> knownLibraryOrder = new LinkedHashSet<Library>();
    public static HashMap<Declaration.Identity, Declaration> knownDeclarations = new HashMap<Declaration.Identity, Declaration>();

    public static DirectedGraph<Library, DefaultEdge> ldg = new DefaultDirectedGraph<Library, DefaultEdge>(DefaultEdge.class);

    public static File dotFileDirectory = null;

    public static Long nanoTimeNow = System.currentTimeMillis();

    public static class CommandLineParseException extends Exception {

        protected Integer suggestedExitCode = 0;

        public CommandLineParseException(Integer suggestedExitCode) {

            super();
            this.suggestedExitCode = suggestedExitCode;
        }

        public Integer getSuggestedExitCode() {

            return suggestedExitCode;
        }
    }

    public static void initialize() {

        knownLibraries = new HashMap<String, Library>();
        knownDeclarations = new HashMap<Declaration.Identity, Declaration>();
        ldg = new DefaultDirectedGraph<Library, DefaultEdge>(DefaultEdge.class);

        if (!Configuration.withoutCore) {

            logger.debug("Starting to load Core...");

            if (!Configuration.customCore) {
                InputStream in = Compiler.class.getResourceAsStream("/Resources/Core.k5z.lib");
                coreLibrary = Library.loadInternal(in);
            }
            else {
                coreLibrary = Library.load(new File(Configuration.customCoreFilename), LibraryLoadStrategy.DEFAULT);
            }

            logger.debug("Done");
        }
    }

    public static boolean parseCommandLine(String[] args) throws CommandLineParseException {

        Options options = new Options();

        Option help = new Option("help", "print this message");

        Option verbose = new Option("verbose", "print messages along the way");
        Option debug = new Option("debug", "print debug along the way");

        Option printAst = new Option("printAst", "print AST(s) for parsed libraries (must be used with -debug");

        Option exportAst = new Option("exportAst", "export AST");
        Option preferSource = new Option("preferSource", "force PREFER_SOURCE library load strategy (ignores compiled version if source is available");

        Option withoutDebug = new Option("withoutDebug", "do not include debug info in compile result");

        Option withoutCore = new Option("withoutCore", "do not use default Core.k5z");

        Option readOnly = new Option("readOnly", "do not write any files");

        OptionBuilder.withArgName("path");
        OptionBuilder.hasArg();
        OptionBuilder.withDescription("library search path (multiple allowed)");
        Option libraryPath = OptionBuilder.create("libraryPath");

        OptionBuilder.withArgName("filename");
        OptionBuilder.hasArg();
        OptionBuilder.withDescription("use custom stg");
        Option stg = OptionBuilder.create("stg");

        OptionBuilder.withArgName("filename");
        OptionBuilder.hasArg();
        OptionBuilder.withArgName("filename");
        OptionBuilder.withDescription("use external library as core");
        Option core = OptionBuilder.create("core");

        OptionBuilder.withArgName("filename");
        OptionBuilder.hasArg();
        OptionBuilder.withDescription("output filename");
        Option output = OptionBuilder.create("output");

        OptionBuilder.withArgName("path");
        OptionBuilder.hasArg();
        OptionBuilder.withDescription("where to put .dot files");
        Option dotPath = OptionBuilder.create("dotPath");

        options.addOption(help);
        options.addOption(verbose);
        options.addOption(debug);
        options.addOption(printAst);
        options.addOption(exportAst);

        options.addOption(libraryPath);
        options.addOption(core);
        options.addOption(output);
        options.addOption(dotPath);
        options.addOption(stg);

        options.addOption(preferSource);
        options.addOption(withoutCore);

        options.addOption(withoutDebug);

        options.addOption(readOnly);

        HelpFormatter formatter = new HelpFormatter();
        formatter.setWidth(80);

        CommandLineParser parser = new BasicParser();

        try {
            Compiler.commandLine = parser.parse(options, args);

            //for(Option opt: Compiler.commandLine.getOptions()) {
            //	logger.info(opt.getOpt() + "/" + opt.getLongOpt() + ": " + opt.hasArg() + ": " + opt.getValuesList());
            //}
            //logger.info("ARG LIST: " + Compiler.commandLine.getArgList());

            if (Compiler.commandLine.hasOption("help")) {
                System.out.println("Version: " + Compiler.class.getPackage().getImplementationVersion());
                formatter.printHelp(Compiler.class + " [options] file.k5z", options);
                throw new Compiler.CommandLineParseException(0);
            }

            if (Compiler.commandLine.getArgs().length == 0) {
                logger.fatal("no input files");
                throw new Compiler.CommandLineParseException(-2);
            }

            if (Compiler.commandLine.hasOption("withoutCore")) {
                Configuration.withoutCore = true;
            }

            if (Compiler.commandLine.hasOption("withoutDebug")) {
                Configuration.withoutDebug = true;
            }

            if (Compiler.commandLine.hasOption("preferSource")) {
                Configuration.preferSource = true;
            }

            if (Compiler.commandLine.hasOption("printAst")) {
                Configuration.printAsts = true;
            }

            if (Compiler.commandLine.hasOption("core")) {
                Configuration.customCore = true;
                Configuration.customCoreFilename = Compiler.commandLine.getOptionValue("core");
            }

            if (Compiler.commandLine.hasOption("dotPath")) {
                Configuration.generateDotFiles = true;
                Configuration.dotPath = Compiler.commandLine.getOptionValue("dotPath");
            }

            if (Compiler.commandLine.hasOption("stg")) {
                Configuration.customStg = true;
                Configuration.customStgFilename = Compiler.commandLine.getOptionValue("stg");
            }

            if (Compiler.commandLine.hasOption("libraryPath")) {

                Configuration.libraryPaths.clear();

                for (String libraryPathString : Compiler.commandLine.getOptionValues("libraryPath")) {
                    File libraryPathFile = new File(libraryPathString);

                    if (!libraryPathFile.exists() || !libraryPathFile.isDirectory()) {

                        logger.fatal(String.format("specified library path '%s' does no exist or is not a directory", libraryPathString));
                        System.exit(-2);
                    }
                    else {
                        Configuration.libraryPaths.add(libraryPathFile.getCanonicalPath() + File.separator);
                    }
                }
            }

            if (Compiler.commandLine.hasOption("readOnly")) {
                Configuration.readOnly = true;
            }

            if (Compiler.commandLine.hasOption("debug")) {
                logger.setLevel(Level.DEBUG);
            }
            else if (Compiler.commandLine.hasOption("verbose")) {
                logger.setLevel(Level.INFO);
            }
            else {
                logger.setLevel(Level.WARN);
            }

            if (Compiler.commandLine.hasOption("output")) {
                if (Compiler.commandLine.getArgs().length > 1) {
                    throw new UnrecognizedOptionException("output filename is for single files only");
                }

                Configuration.outputFilenameSpecified = true;
                Configuration.outputFilename = commandLine.getOptionValue("output");
            }

        }
        catch (Compiler.CommandLineParseException e) {
            throw e;
        }
        catch (Exception e) {
            System.out.println("Command line parse exception: " + e);

            String implementationVersion = Compiler.class.getPackage().getImplementationVersion();

            System.out.println("Version: " + ((implementationVersion == null) ? "N/A" : implementationVersion));
            formatter.printHelp(Compiler.class + " [options] file", options);
            throw new Compiler.CommandLineParseException(-1);
        }

        return true;
    }

    /**
     * @param filename filename for .dot file
     */
    public static void writeLdgDotFile(String filename) {

        IntegerNameProvider<Library> libraryIntegerNameProvider = new IntegerNameProvider<Library>();
        StringNameProvider<Library> libraryStringNameProvider = new StringNameProvider<Library>();

        DOTExporter<Library, DefaultEdge> exporter = new DOTExporter<Library, DefaultEdge>(libraryIntegerNameProvider, libraryStringNameProvider, null);

        File dotFile = new File(dotFileDirectory.getAbsolutePath() + "/" + filename + ".dot");

        try {
            Writer dotWriter = new BufferedWriter(new FileWriter(dotFile));
            exporter.export(dotWriter, ldg);
            dotWriter.close();
        }
        catch (IOException e) {
            logger.info("Could not write LDG .dot file to " + filename + " - " + e);
        }
    }

    /**
     * @param sourceFilename file name string of file to be processed
     * @param loadStrategy   which strategy to use
     */
    public static void processSourceFile(String sourceFilename, LibraryLoadStrategy loadStrategy) {

        NDC.clear();

        logger.info("Processing source file " + sourceFilename + ", load strategy: " + loadStrategy);

        initialize();

        Library library = new Library(new File(sourceFilename).getAbsoluteFile());

        if (Configuration.generateDotFiles) {
            dotFileDirectory = new File(Configuration.dotPath + "/" + library.name);
            if (!dotFileDirectory.exists() && !dotFileDirectory.mkdirs()) {
                throw new GenericCompilerException("Could not create .dot output directory " + Configuration.dotPath + "/" + library.name);
            }
        }

        library.register(loadStrategy);

        logger.debug("Known functions: " + knownDeclarations.keySet());

        if (Configuration.generateDotFiles) {
            writeLdgDotFile("library_dependencies_all");
        }

        library.compile();

        for (Library someLibrary : knownLibraries.values()) {

            if (someLibrary.state.equals(Library.State.PARSED)) {
                someLibrary.compile();
            }
        }

        if (library.isProgram) {

            File outputFile;

            if (!Configuration.outputFilenameSpecified) {
                outputFile = new File(sourceFilename + ".php");
            }
            else {
                outputFile = new File(Configuration.outputFilename);
            }

            try {

                FileOutputStream fStream = new FileOutputStream(outputFile);
                fStream.write(library.link().getBytes());
                fStream.close();

                logger.info("Wrote to file '" + outputFile.getCanonicalPath() + "'");

            }
            catch (Exception e) {

                logger.fatal(e);

                throw new GenericCompilerException("Could not save result to file " + outputFile);
            }
        }

        if (Configuration.generateDotFiles) {

            forgetKnownLibrary(coreLibrary);
            writeLdgDotFile("library_dependencies_no_core");
        }
    }

    /**
     * @param args command line arguments
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {

        try {
            parseCommandLine(args);
        }
        catch (CommandLineParseException e) {
            System.exit(e.getSuggestedExitCode());
        }

        Configuration.show();

        LibraryLoadStrategy loadStrategy = Configuration.preferSource
            ? LibraryLoadStrategy.PREFER_SOURCE
            : LibraryLoadStrategy.DEFAULT;

        String sourceFilename = (String) Compiler.commandLine.getArgList().get(0);

        if (Compiler.commandLine.hasOption("exportAst")) {
            exportAst(sourceFilename);
            System.exit(0);
        }

        try {
            try {

                processSourceFile(sourceFilename, loadStrategy);
            }
            catch (Library.ImportLoadException e) {

                zzz(loadStrategy, sourceFilename, e);
            }
            catch (Library.ImportLibraryVersionClashException e) {

                zzz(loadStrategy, sourceFilename, e);
            }
        }
        catch (GenericCompilerException e) {

            logger.fatal(e.toString());
            System.exit(-1);
        }

        logger.info("All done.");

        System.exit(0);
    }

    private static void zzz(LibraryLoadStrategy loadStrategy, String sourceFilename, RuntimeException e) {

        if (loadStrategy.equals(LibraryLoadStrategy.PREFER_SOURCE)) {

            throw e;
        }

        NDC.clear();
        logger.debug("============================= SWITCH TO 'PREFER SOURCE' =============================");
        processSourceFile(sourceFilename, LibraryLoadStrategy.PREFER_SOURCE);
    }

    /**
     * @param subject  library from which
     * @param referred library to which
     * @return edge added to dependency graph
     */
    public static DefaultEdge addLibraryDependency(Library subject, Library referred) {

        logger.debug("ADD DEPENDENCY FROM " + subject + " TO " + referred);

        return ldg.addEdge(subject, referred);
    }

    /**
     * @param declaration declaration to register
     * @throws Library.LoadException
     */
    public static void addKnownDeclaration(Declaration declaration) throws Library.LoadException {

        Declaration.Identity identity = declaration.getIdentity();

        if (knownDeclarations.containsKey(identity)) {

            Declaration offendingDeclaration = Compiler.knownDeclarations.get(identity);
            String errorMessage = "'" + declaration.name + "' is already defined in " + offendingDeclaration.library.getLongName();

            if (offendingDeclaration.line != 0) {
                errorMessage = errorMessage + ", line " + offendingDeclaration.line + ":" + offendingDeclaration.position;
            }

            throw new Library.LoadException(errorMessage);
        }

        //logger.debug("ADD KNOWN DECLARATION " + declaration.library + ":" + declaration.name + " / " + Integer.toHexString(System.identityHashCode(declaration.library)));
        logger.debug("ADD KNOWN DECLARATION " + declaration.library + ":" + declaration.name);

        knownDeclarations.put(identity, declaration);
    }

    /**
     * @param library library to register
     * @throws Library.LoadException
     */
    public static void addKnownLibrary(Library library) throws Library.LoadException {

        if (knownLibraries.containsKey(library.name)) {

            Library knownLibrary = knownLibraries.get(library.name);

            if (!knownLibrary.sourceFile.getAbsolutePath().equals(library.sourceFile.getAbsolutePath())) {
                logger.info("Imported library name clash - "
                            + library.getLongName() + " vs. "
                            + knownLibraries.get(library.name).getLongName());

                throw new Library.ImportLibraryNameClashException(knownLibrary, library);
            }

            if (!knownLibrary.compileNanoTime.equals(library.compileNanoTime)) {
                logger.info("Imported library version clash - "
                            + library.getLongName() + " vs. "
                            + knownLibraries.get(library.name).getLongName());

                throw new Library.ImportLibraryVersionClashException(knownLibrary, library);
            }
        }
        else {

            knownLibraries.put(library.name, library);

            knownLibraryOrder.add(library);

            logger.debug("ADD KNOWN LIBRARY " + library + " / " + Integer.toHexString(System.identityHashCode(library)));

            for (Declaration declaration : library.declarations.values()) {
                addKnownDeclaration(declaration);
            }

            if (!ldg.containsVertex(library)) {
                logger.debug("ADD LIBRARY " + library + " / " + Integer.toHexString(System.identityHashCode(library)) + " TO LDG");
                ldg.addVertex(library);
            }
        }
    }

    /**
     * @param knownLibrary library to forget
     */
    static void forgetKnownLibrary(Library knownLibrary) {

        if (knownLibrary == null) {
            return;
        }

        knownLibraries.remove(knownLibrary.name);

        for (Declaration declaration : knownLibrary.declarations.values()) {

            if (knownDeclarations.get(declaration.getIdentity()).library.equals(knownLibrary)) {

                knownDeclarations.remove(declaration.getIdentity());
            }
        }

        ldg.removeVertex(knownLibrary);

        logger.debug("REMOVE KNOWN LIBRARY " + knownLibrary + " / " + Integer.toHexString(System.identityHashCode(knownLibrary)));
    }

    /**
     * @param library library for which to look up who uses it
     * @return list of libraries using given library
     */
    public static List<Library> getImportingLibraries(Library library) {

        ArrayList<Library> importingLibraries = new ArrayList<Library>();

        for (Library knownLibrary : knownLibraries.values()) {

            if (knownLibrary.importNameToDefinitionMap.containsKey(library.name)) {

                importingLibraries.add(knownLibrary);
            }
        }

        return importingLibraries;
    }

    /**
     * @param args command line arguments
     * @return hash with messages
     */
    @SuppressWarnings("unused")
    public static HashMap<String, String> internalMain(String[] args) {

        HashMap<String, String> result = new HashMap<String, String>();

        try {
            parseCommandLine(args);
        }
        catch (CommandLineParseException e) {
            return result;
        }

        Configuration.show();

        LibraryLoadStrategy loadStrategy = Configuration.preferSource
            ? LibraryLoadStrategy.PREFER_SOURCE
            : LibraryLoadStrategy.DEFAULT;

        String sourceFilename = Compiler.commandLine.getArgs()[0];

        try {
            Library library = new Library(new File(sourceFilename).getAbsoluteFile());
            library.register(loadStrategy);

            library.compile();

            for (Library someLibrary : knownLibraries.values()) {
                if (someLibrary.state.equals(Library.State.PARSED)) {
                    someLibrary.compile();
                }
            }
        }
        catch (SourceErrorsException e) {

            for (SourceError sourceError : e.errors) {
                result.put(sourceError.filename, sourceError.message);
            }

        }
        catch (GenericCompilerException e) {

            logger.fatal(e.toString());
            return result;
        }

        return result;
    }

    protected static void exportAst(String sourceFilename) {

        NDC.clear();

        logger.info("Processing source file " + sourceFilename + " for AST export...");

        initialize();

        Library library = new Library(new File(sourceFilename).getAbsoluteFile());

        logger.info("Done");

        library.exportAst();
    }
}
