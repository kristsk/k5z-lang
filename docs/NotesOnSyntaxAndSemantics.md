# Notes on K5Z Language Syntax and Semantics

I have started to write a document titled "K5Z language specification" for about 3 times now. Did not get very far. So
for now I've decided to dump things that seem important in here.

## Contents

* [Programs and libraries](#programs-and-libraries)
* [Function and variable identifiers](#function-and-variable-identifiers)
* [Curly braces](#curly-braces)
* [Variable scoping](#variable-scoping)
* [Closures and Anonymous Functions](#closures-and-anonymous-functions)
* [Explicit Argument Passing Type Declarations](#explicit-argument-passing-type-declarations)
* [Named Parameters in Function and Closure Calls](#named-parameters-in-function-and-closure-calls)
* [Arrays](#arrays)
* [String Concatenation](#string-concatenation)
* [Threads? In my PHP?](#threads-in-my-php)
* [Where are My Objects and Classes / Exceptions / Constants / "switch" statement?](#where-are-my-objects-and-classes--exceptions--constants--switch-statement)

## Programs and libraries

Code can be organized programs and libraries. On top of each unit-file (library or program) is a section of imports.
Path, relative to compilers include paths can be specified. The alias for library can be set as well.

This is how it looks in simple program file.

    program Guess;
    
    import WebApplication as WA from "SystemLibraries";
    import StandaloneWebApplication from "SystemLibraries";
    import BananaSplit as BS from "Libraries/BananaSplit";

Program unit-file must contain function `Main`.

Functions from libraries are invoked specifying the alias and the function name, like this -
`BS::Input("Enter a number from " .. min .. " to " .. max .. " (inclusive)", "");`

Functions defined in the same unit-file are called without alias, like this - `name = ::AskForName("Jānis Zars");`

The "core" library gets imported implicitly and functions are called without `::`, like this -
`secret_number = Rand(min, max);`

## Function and variable identifiers

Early on I made a decision to have separate rules for identifiers of variables and identifiers for functions. This was
done because I have an opinion that it benefits reading the code.

The rules are:

1. Function (and library) identifiers must begin with capital letter and must not have underscore character in them
    - `function MyFancyFunction() { ... }` or `library MeatPopsicle;`

2. Variable identifiers must begin with lowercase letter and must not have capital letters
    - `default_email_address = "bubba@bubba.com";`

## Curly braces

Most of the languages I knew back then used curly braces - PHP, JavaScript, Java. And I like them curly braces, so
curly. Therefore, it is not surprising curly braces are used in this language as well.

## Variable scoping

Variables are scoped to function they are used in and in any closure introduced in the function, including nested ones.
This means there are no scope resolution rules.

Compiler also enforces variable names to be unique in scope. In case of closures it is not allowed to have an argument
with same name as some variable in scope the closure is defined in. I really did not want to do scope analysis and
checks.

## Closures and Anonymous Functions

By default, variables from defining scope are available inside closure by reference. It is possible to bind variables by
value at the time of defining. Following code snippet illustrates this behaviour:

    function SomeFunction() {
    
        n = 5;
    
        counter = @{ 
            
            n++;
        
            return "Value of 'n' now: " .. n .. ", value at the time of declaration " .. $n .. ".";
        };
        
        @counter(); // --> Value of 'n' now: 6, value at the time of declaration 5.
        @counter(); // --> Value of 'n' now: 7, value at the time of declaration 5.
        
        n = 100;
        @counter(); // --> Value of 'n' now: 101, value at the time of declaration 5.
        @counter(); // --> Value of 'n' now: 102, value at the time of declaration 5.
    
    }

Also, a shorthand for closure-ing over expressions is available - `some_closure = @( a + 100 );` is equivalent
to `some_closure = @{ return a + 100; }`. Saves some precious curly braces.

## Explicit Argument Passing Type Declarations

Arguments to functions can be passed by either value - `val some_argument` or reference - `ref some_argument`. Optional
values are supported - `opt some_optional_argument = "123"`. Optional arguments can be only be scalar value or array
constructions.

## Named Parameters in Function and Closure Calls

It is possible to invoke a K5Z function using either traditional positional parameters, or use names of arguments. Int
later case order is not important.

    function SomeNiceFunction(val name, val email, opt phone_number = FALSE) {
        ...
    }
    
    ...
    
    ::SomeNiceFunction("Bubba", "bubba@bubbamail.com", 123123123);
    
    ::SomeNiceFunction(
        email: "bubba@bubbamail.com", 
        phone_number: 123123123, 
        name: "Bubba"
    );

In case of regular functions argument presence is enforced by compiler. If closure call is missing a parameter, it's
value defaults to `FALSE`.

## Arrays

Arrays in K5Z are backed directly by PHP and behaviour is almost identical. Some additional features are present:

1. Empty arrays are created by `[]`, just like PHP has it now.
1. Accessing items of an array with dot notation - `array_1.hello = array_2.world;` is the same
   as `array_1["hello"] = array_2["world"];`. In this case key has to conform to variable identifier rules (only
   lowercase and underscore).

## String Concatenation

Strings are concatenated two dots - `full_name = "Mr. " .. first_name .. " " .. last_name;`. This two-dot form was
chosen to simplify parser rules, and allow for array dot notation.

## Threads? In my PHP?

Well, not threads per se, more like separate, switchable call stacks. With core API to manage them. There is very little
to provide any safety when working with those. You totally can do crazy recursions, replications, deadlocks and other
fun stuff. However, K5Z's threads are not something that "business" logic should relay on. They are meant mostly for
libraries implementing suspend/resume related functionality.

## Where are My Objects and Classes / Exceptions / Constants / "switch" statement?

* There are no objects / classes. Type systems are tricky thing to do, even more tricky to do them right. Being the
  savage that I am, sometime I have ab-used the associative arrays of PHP to emulate some aspects of OO design.
* There are mo exceptions yet. Exceptions would complicate K5Z's "threads", but I have a vague idea how to implement
  this. But it is not on the top of my list.
* There are no constants. To limit amount of things the parsers and compiler has to deal with I decided to leave them
  out. It turns out to be not a big inconvenience.
* The "switch" statement while common for curly brace languages is not implemented for this language. Reason is because
  I am lazy. And had not really encountered a situation where it would be head and shoulders better than chained "if"s.
  However, I have to admit this to be a little ironic, considering that PHP's "switch" statement is one of main parts in
  functions produced by the compiler.
