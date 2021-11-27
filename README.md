# About

K5Z is a research programming language for exploring a somewhat different approach to building web applications.

This repository contains:

* source code for [K5Z compiler](src/java)
* source code for [run-time libraries](src/k5z)
* source code for [user libraries](k5z/Libraries)
* source code for [some application examples](k5z/Applications)

If you are impatient, go to the bottom of this file and see [Using The Compiler](#using-the-compiler).

## Contents of This File

* [Status of Documentation](#status-of-documentation)
* [A Historical Note](#a-historical-note)
* [Implementation](#implementation)
* [Building the Compiler](#building-the-compiler)
* [Using the Compiler](#using-the-compiler)

## Status of Documentation

In short - it is poor. Basically, now it is just this file and some more notes in [docs](docs) directory. One could
argue that one can always go and read the code, but some features and design decisions might not be that easy to
decipher. I have some will to add more documentation for explaining ideas and functionality of run-time and user
libraries, but it is not done yet.

Below are links to what is done so far:

* [Notes On Syntax and Semantics](docs/NotesOnSyntaxAndSemantics.md)
* [How It Works](docs/HowItWorks.md)
* [A Short Rationale](docs/AShortRationale.md)
* [Web Applications And K5Z](docs/WebApplicationsAndK5Z.md)

## A Historical Note

This project was started and most of the work done on it quite a long time ago - starting around 2009, if I am not
mistaken. This is why now some of used tools and libraries are a bit outdated. Also, the PHP has more features now, but
those are not used here (yet).

## Implementation

Source files written in K5Z are "compiled" (transpiled?) to PHP and can be run by either PHP's built-in webserver or any
other PHP-capable web-server.

Compiler is implemented in Java thus a JRE is required to run it.

Syntax of the language belongs to "curly braces" family, with quite straightforward syntax. For notes on semantics and
syntax see [Notes on K5Z Language Syntax and Semantics](docs/NotesOnSyntaxAndSemantics.md).

There is a Jetbrains IDE plugin that provides some basic syntax
highlighting: [krists/k5z-intellij](https://github.com/krists/k5z-intellij)

## Building the Compiler

This project uses Apache Ant (required to be present) as build tool and Apache Ivy for package management.

1. Clone the repo:
   ```
   git clone https://githiub.com/kristsk/k5z-lang.git
   ```
2. Go into it
   ```
   cd k5z-lang
   ```
3. Gather dependencies (will download Apache Ivy)
   ```
   ant bootstrap
   ```
4. Build
   ```
   ant build
   ```

It is safe to ignore warnings about illegal reflective access. After the build is done, a k5z.jar file, containing the
compiler, will be generated in `dist/` directory.

## Using the Compiler

To compile the simple example:

```
java -jar dist/k5z.jar -libraryPath k5z k5z/Applications/Guess/Guess.k5z
```

Again - it is safe to ignore warnings about illegal reflective access.

Then you can start PHP's built in web-server with the result of compilation:

```
php -S 127.0.0.1:8000 k5z/Applications/Guess/Guess.k5z.php
```

And then open http://127.0.0.1:8000 in a browser.

Invoke `java -jar dist/k5z.jar -help` to see command line parameters for the compiler.

There are shorthand commands `this-k5z` (uses class files) and `this-k5z-jar` (uses jar file) to use when compiling code
directly from current repository:

```
this-k5z k5z/Applications/Guess/Guess.k5z
```
