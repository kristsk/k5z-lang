# How It Works

## Contents of This File

* [The General Idea](#the-general-idea)
* [So How Does It Work?](#so-how-does-it-work-a-short-answer)
* [How K5Z Does What It Does](#how-k5z-does-what-it-does)

## The General Idea

The hypothesis is that implementing some arbitrary business logic using shared-nothing web-application model by adding
in "housekeeping" logic (either a framework or ad-hoc) makes resulting control flow of program very different compared
to the expected solution for the business problem. I argue that this makes this kind of implementation harder both to
write and reason about.

K5Z is an attempt to solve this problem by keeping business logic away from "housekeeping" logic. When a business
process involves multiple requests having some common state, most of the "housekeeping" is related to setting up this
common state, and then handing it off to the next step in business process. My approach is to analyze the business logic
and at compile time deduce where "housekeeping" will happen, and then generate code that knows how to suspend and resume
the business process. It sounds complicated, but it really is not that bad.

To better illustrate the approach lets look at a simple game of "Guess the Number" as our "business logic". Pseudo-code
for program implementing the game could be something like this:

```    
secret_number = RandomNumber(1, 100)
min_guess = 1
max_guess = 100
guess_count = 0
 
loop
   guess = ReadNumber("Enter number from " min_guess " to "  max_guess)
   guess_count = guess_count + 1
     
   if guess > max_guess or guess < min_guess then
      ShowMessage "Bad guess."
   else if guess > secret_number then
      ShowMessage "Too big"
      max_guess = guess - 1
   else if guess < secret_number then
      ShowMessage "Too small"
      min_guess = guess + 1
 
until guess == secret_number

ShowMessage("Number guessed in " guess_count " attempts.")
```

This is pretty straight-forward - a single loop with exit condition and some checks inside.

Now consider how would one go about and implement this on server side, with PHP. If done ad-hoc, it would be one file,
with one big switch and some query parameter parsing determine correct state. The actual control flow will be quite different
from what is shown in the pseudo-code above. Tha argument a-la "oh, this should not be done in server side at all" for now is not
considered to be relevant.

Now, if we go and see file [`k5z/Applications/Guess/Guess.k5z`](./k5z/Applications/Guess/Guess.k5z), and compare that to
how that would be done in PHP, and how similar it is to the pseudo-code above:

    ... 
    while(TRUE) {

        guess = BS::Input("Enter a number from " .. min .. " to " .. max .. " (inclusive)", "");

        guesses = guesses + 1;

        if(guess == secret_number) {

            BS::Okay("Congratulations, " .. name .. ", You did it! It took You " .. guesses .. " guesses!");

            if(BS::YesNo("Would you like to restart?")) {
                WA::Restart();
            }
            else {
                WA::Output("Bye-bye!");
            }
        }

        if((guess > max) or (guess < min)) {

            BS::Okay("Huh?");
        }
        else if(guess > secret_number) {

            BS::Okay("Too big!");
            max = guess - 1;
        }
        else if(guess < secret_number) {

            BS::Okay("Too small!");
            min = guess + 1;
        }
    }
    ...

There is a little more going on in the actual source file, but general shape of control flow is the very similar to the
pseudo-code. And when compiled and executed (from a web-server), it behaves exactly as one would expect.

## So How Does It Work (A Short Answer)?

In short - by determining which functions and calls to them will likely result in interruption of the execution of program to do output. This
knowledge then gets used by compiler to add, where necessary, execution context tracing, results of which get used for storing the call stacks when the program execution is interrupted. 

Internally, compiler classifies functions in K5Z to be one of two kinds - "clean" and "dirty". "Clean" functions are those where compiler is
sure that no interruption of execution will happen, and therefore it does not do anything very special for those. Otherwise,
the if function is deemed "dirty", its control flow is transformed to so that it can be suspended and resumed. In our
example above the functions `BS::Input`, `BS::Okay`, `BS:YesNo` and `WA::Output` are "dirty" and invoking them causes
storing of execution state of the program. This state is later restored and program execution resumed. For now, to have
some insight in how it is done, compile the program, and have a look at generated code. Look for file `Guess.k5z.php`.
See [Using the Compiler] section below for command to compile the example.

## How K5Z Does What It Does

This is somewhat hand-wavy explanation, but I hope it is better than nothing.

Now, as mentioned before, by magic of call tree analysis compiler can distinguish two types of functions in K5Z:

1. Regular, boring functions - nothing interesting in context of program control flow happens. These are **clean**
   functions.
1. Functions that may either suspend program execution themselves, or have calls to functions that do. Those functions
   are **dirty** functions. Closures are in this category.

It is possible to explicitly say that some function is **dirty** (but you probably do not want to do that, just let the
compiler sort it out). When a PHP file is included in library, a list of declared functions is specified and in special
cases you might want to mark some functions as dirty. See
files [`src/k5z/SystemLibraries/WebApplication.k5z`](../src/k5z/SystemLibraries/WebApplication.k5z) and the included PHP
file [`SystemLibraries/WebApplication.php`](../src/k5z/SystemLibraries/WebApplication.php).

When a regular K5Z source file is compiled, it is parsed, and along with all necessary imported files, and resulting AST
is analysed to identify dirtied functions. Then the AST is transformed like this:

1. Closure declarations are moved out from defining function declarations.
2. If a value from dirty call is used in some expression or statement, the dirty call itself is moved "up" and a
   replacement variable is used instead and each case of dirty call is marked.

After that the transformed AST is parsed once more to construct CFGs of declaration with K5Z bodies. These CFGs in turn
allows data flow analysis step to compute variable liveness, which then is used to minimize suspend context size.

Finally, transformed AST is parsed for last time and PHP code is emitted:

* For clean function declarations the result is exactly the same as if function would've been written in PHP.
* In case of dirty function a special wrapper which is needed to make function "resumable". A `switch` statement, a
  bunch of `goto` statements and labels for them are used. A K5Z stack frame is used for variables. All control
  statements in K5Z also are transformed to be "resumable".

Also, special treatment is given to dirty function calls:

1. Current stack frame is pushed - this includes all variables, and *next* jump label.
2. Control is transferred to PHP function of compiled K5Z function.
3. Additionally, the results of data flow analysis (variable liveness) is used to mark variables in current stack frame
   that will not be used anymore. This allows to minimise program state size.
4. If call returns (it can happen!), last pushed stack frame is tossed out and execution goes on.

In case the call to dirty function caused program to suspend it's state, stack contains all the necessary data to safely
restore program state and return to function that was interrupted.

The stack frame handling and suspending/resuming operations are done by K5Z Core library. This library implicitly gets
imported into every K5Z source file. See files [`src/k5z/SystemLibraries/Core.k5z`](../src/k5z/SystemLibraries/Core.k5z)
and [`src/k5z/SystemLibraries/Core.php`](../src/k5z/SystemLibraries/Core.php).

Theoretically the output is not very hard-tied to PHP (only some keywords). Given some effort, other backend language
could be implemented without any (or much) changes to the compiler code.