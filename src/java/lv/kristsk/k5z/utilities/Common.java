// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z.utilities;

import com.esotericsoftware.kryo.Kryo;
import lv.kristsk.k5z.Compiler;
import lv.kristsk.k5z.*;
import org.antlr.stringtemplate.StringTemplateGroup;
import org.apache.log4j.ConsoleAppender;
import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.apache.log4j.PatternLayout;
import org.objenesis.strategy.StdInstantiatorStrategy;

import java.io.*;

public class Common {

    public static Logger logger = Common.getLogger();

    public static Kryo kryo;

    public static StringTemplateGroup templates = null;

    static {
        kryo = new Kryo();

        kryo.setInstantiatorStrategy(new StdInstantiatorStrategy());

        kryo.register(java.util.HashMap.class);
        kryo.register(java.util.ArrayList.class);
        kryo.register(java.util.LinkedHashSet.class);

        kryo.register(Library.class);
        kryo.register(Library.Include.class);
        kryo.register(Library.IncludeWithFunctions.class);
        kryo.register(Library.ImportDefinition.class);
        kryo.register(Library.State.class);
        kryo.register(Library.Type.class);

        kryo.register(Variable.class);
        kryo.register(Variable.AccessMode.class);

        kryo.register(Declaration.class);
        kryo.register(Declaration.Parameter.class);
        kryo.register(Declaration.Parameter.Mode.class);
        kryo.register(Declaration.CalleeIdentity.class);
        kryo.register(Declaration.Identity.class);
        kryo.register(Declaration.Type.class);
        kryo.register(Declaration.Mode.class);

//		kryo.register(org.antlr.stringtemplate.StringTemplate.class);
//		kryo.register(org.antlr.stringtemplate.StringTemplateGroup.class);
//		kryo.register(org.antlr.stringtemplate.language.StringTemplateAST.class);

        kryo.setReferences(true);
    }

    public static Logger getLogger() {

        Logger logger = Logger.getLogger("org.k.kristsk.k5z");
        PatternLayout layout = new PatternLayout("[%r] %-5p%x %m%n");
        ConsoleAppender appender = new ConsoleAppender(layout);
        logger.addAppender(appender);
        logger.setLevel(Level.DEBUG);

        return logger;
    }

    public static String getOrdinal(Integer i) {

        int test = i % 100;

        if (test > 3 && test < 21) {
            return (i + "th");
        }

        switch (test % 10) {
            case 1:
                return (i + "st");
            case 2:
                return (i + "nd");
            case 3:
                return (i + "rd");
            default:
                return (i + "th");
        }
    }

    public static InputStream getResource(String name) {

        return Compiler.class.getResourceAsStream("/Resources/" + name);
    }

    public static InputStream getK5zCoreResourceStream() {

        return Common.getResource("Core.k5z.lib");
    }

    public static InputStream getK5zPhpStgResourceStream() throws FileNotFoundException {

        InputStream stgStream = Common.getResource("k5z-php.stg");

        if (Configuration.customStg) {
            stgStream = new FileInputStream(Configuration.customStgFilename);
        }

        return stgStream;
    }

    public static String readPhpFromFilenameAsString(String filename) throws java.io.IOException {

        String fileContents = readFromFilenameAsString(filename);

        if (fileContents.startsWith("<?php") || (fileContents.startsWith("<?"))) {

            if (fileContents.startsWith("<?php")) {
                fileContents = fileContents.substring(5); // <?php
            }
            else {
                fileContents = fileContents.substring(2); // <?
            }

            if (fileContents.trim().endsWith("?>")) {
                fileContents = fileContents.substring(0, fileContents.length() - 2);
            }
        }
        else {
            logger.fatal("File '" + filename + "' does not begin with '<?php' or <?'!");
            System.exit(-1);
        }

        return fileContents.trim();
    }

    public static String readFromFilenameAsString(String filename) throws java.io.IOException {

        StringBuilder fileData = new StringBuilder();
        BufferedReader reader = new BufferedReader(new FileReader(filename));
        char[] buf = new char[1024];
        int numRead;

        while ((numRead = reader.read(buf)) != -1) {
            fileData.append(buf, 0, numRead);
        }

        reader.close();

        return fileData.toString();
    }

    public static StringTemplateGroup getK5zPhpStgTemplateGroup() {

        if (templates == null) {

            logger.debug("Loading k5z-php.stg...");

            try {
                InputStream in = Common.getK5zPhpStgResourceStream();
                templates = new StringTemplateGroup(new InputStreamReader(in));
                in.close();
            }
            catch (IOException e) {
                throw new GenericCompilerException("Could not load translation template");
            }

            logger.debug("Done");
        }

        return templates;
    }
}
