// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

package lv.kristsk.k5z;

import lv.kristsk.k5z.utilities.Common;
import org.apache.log4j.Logger;
import org.apache.log4j.NDC;

import java.util.ArrayList;
import java.util.Collection;

public class Configuration {

    public static Logger logger = Common.logger;
    public static Collection<String> libraryPaths = new ArrayList<String>();
    public static Boolean withoutCore = false;
    public static Boolean customCore = false;
    public static String customCoreFilename = "";
    public static Boolean generateDotFiles = false;
    public static String dotPath = "";
    public static Boolean outputFilenameSpecified = false;
    public static String outputFilename = "";
    public static Boolean preferSource = false;
    public static Boolean printAsts = false;
    public static Boolean withoutDebug = false;
    public static Boolean customStg = false;
    public static String customStgFilename = "";
    public static Boolean readOnly = false;

    public static void show() {

        NDC.push("CONFIGURATION");

        for (String someLibraryPath : libraryPaths) {
            logger.info("libraryPath: " + someLibraryPath);
        }

        logger.info("withoutCore: " + withoutCore);

        logger.info("customCore: " + customCore);
        if (customCore) {
            logger.info("customCoreFilename: " + customCoreFilename);
        }

        logger.info("customStg: " + customStg);
        if (customStg) {
            logger.info("customStgFilename: " + customStgFilename);
        }

        if (outputFilenameSpecified) {
            logger.info("outputFilename: " + outputFilename);
        }
        else {
            logger.info("outputFilename: <default>");
        }

        logger.info("generateDotFiles: " + generateDotFiles);
        if (generateDotFiles) {
            logger.info("dotPath: " + dotPath);
        }

        logger.info("prefer source: " + preferSource);

        logger.info("print AST(s): " + printAsts);

        logger.info("withoutDebug: " + withoutDebug);

        NDC.pop();

    }

    static {
        String libraryPathFromEnv = System.getenv("K5Z_REPOSITORY_PATH");

        if (libraryPathFromEnv != null) {
            libraryPaths.add(libraryPathFromEnv);
        }
        else {
            libraryPaths.add(System.getProperty("user.dir") + "/k5z-repository");
        }
    }
}
