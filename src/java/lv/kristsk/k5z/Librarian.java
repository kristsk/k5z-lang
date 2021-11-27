// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z;

import lv.kristsk.k5z.utilities.Common;
import org.apache.commons.cli.*;
import org.apache.log4j.Level;
import org.apache.log4j.Logger;

import java.io.File;
import java.io.FileInputStream;

public class Librarian {

    static Logger logger = Common.logger;

    public static void main(String[] args) throws Exception {

        Options options = new Options();
        options.addOption("v", "verbose", false, "print some messages along the way");
//		options.addOption("d", "debug", false, "print debug along the way");
        options.addOption("h", "help", false, "print usage (this)");
// 		options.addOption("f", "force", false, "ignore timestamps of .declaration and .php");

        OptionBuilder.withLongOpt("show");
        OptionBuilder.hasArg();
        OptionBuilder.withArgName("library_filename");
        OptionBuilder.withDescription("show contents of the compiled library file");
        options.addOption(OptionBuilder.create());

//		OptionBuilder.withLongOpt("declaration");
//		OptionBuilder.hasArg();
//		OptionBuilder.withArgName("declaration_filename");
//		OptionBuilder.withDescription("declaration file name");
//		options.addOption(OptionBuilder.create());
//
//		OptionBuilder.withLongOpt("output");
//		OptionBuilder.hasArg();
//		OptionBuilder.withArgName("output_filename");
//		OptionBuilder.withDescription("output file name");
//		options.addOption(OptionBuilder.create());
//
        HelpFormatter formatter = new HelpFormatter();

        CommandLineParser parser = new PosixParser();
        CommandLine line = null;

        try {
            line = parser.parse(options, args);
        }
        catch (UnrecognizedOptionException e) {
            formatter.printHelp(Librarian.class + " [options] <declaration_filename>", options);
            System.exit(-1);
        }

        //if(line.hasOption("verbose")) {
        //	logger.setLevel(Level.TRACE);
        //}

        if (line.hasOption("h")) {
            formatter.printHelp(Librarian.class + " [options] <declaration_filename>", options);
            System.exit(0);
        }

        if (line.hasOption("show")) {

            showLibraryContents(line.getOptionValue("show"));
            System.exit(0);
        }
    }

    private static void showLibraryContents(String libraryFilename) {

        File libraryCompiledFile = new File(libraryFilename);

        try {

            Library.logger.setLevel(Level.TRACE);

            Library library = Library.readCompiledFromStream(new FileInputStream(libraryCompiledFile));

            if (library.importNameToDefinitionMap.size() != 0) {

                logger.info("Imports (" + library.importNameToDefinitionMap.size() + ") :");
                for (Library.ImportDefinition importDefinitionItem : library.importNameToDefinitionMap.values()) {

                    logger.info("  Name: " + importDefinitionItem.name);
                    logger.info("    path: " + importDefinitionItem.path);
                    logger.info("    compile nano time: " + importDefinitionItem.compileNanoTime);

                    logger.info("");
                }
            }
            else {
                logger.info("No imports.");
            }

            logger.info("");

            if (library.includes.size() != 0) {
                logger.info("Includes  (" + library.includes.size() + "):");

                for (Library.Include include : library.includes.values()) {

                    logger.info("  Path: " + include.relativeFilename);

                    if (include instanceof Library.IncludeWithFunctions) {
                        logger.info("  with functions");
                    }

                    logger.info("  modification nano time: " + include.modificationNanoTime);

                    logger.info("");
                }
            }
            else {
                logger.info("No includes.");
            }

            logger.info("");

            if (library.declarations.size() != 0) {
                logger.info("Declarations (" + library.declarations.size() + "): ");

                for (Declaration declaration : library.declarations.values()) {

                    if (declaration.type.equals(Declaration.Type.FUNCTION)) {
                        logger.info("  FUNCTION: " + declaration.name + " - mode: " + declaration.readMode() + ", phpName: " + declaration.getPhpName());
                    }
                    else if (declaration.type.equals(Declaration.Type.PHP_INCLUDE)) {
                        logger.info("  PHP_INCLUDE: " + declaration.name + " - mode: " + declaration.readMode() + ", phpName: " + declaration.getPhpName() + ", includeFilename: " + declaration.include.relativeFilename);
                    }
                    else if (declaration.type.equals(Declaration.Type.PHTML_INCLUDE)) {
                        logger.info("  PHTML_INCLUDE: " + declaration.name + " - mode: " + declaration.readMode() + ", phpName: " + declaration.getPhpName() + ", includeFilename: " + declaration.include.relativeFilename);
                    }
                }
            }
            else {
                logger.info("No declarations.");
            }
        }
        catch (Exception e) {
            logger.info("Could not load compiled library - " + e.getMessage());
        }
    }
}
