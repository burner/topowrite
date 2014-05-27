// Written in the D programming language.

/**
Processing of command line options.

The getopt module implements a $(D getopt) function, which adheres to
the POSIX syntax for command line options. GNU extensions are
supported in the form of long options introduced by a double dash
("--"). Support for bundling of command line options, as was the case
with the more traditional single-letter approach, is provided but not
enabled by default.

Macros:

WIKI = Phobos/StdGetopt

Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
Credits:   This module and its documentation are inspired by Perl's $(WEB
           perldoc.perl.org/Getopt/Long.html, Getopt::Long) module. The syntax of
           D's $(D getopt) is simpler than its Perl counterpart because $(D
           getopt) infers the expected parameter types from the static types of
           the passed-in pointers.
Source:    $(PHOBOSSRC std/_getopt.d)
*/
/*
         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module stdx.getopt;

private import std.array, std.string, std.conv, std.traits, std.bitmanip,
    std.algorithm, std.ascii, std.exception, std.typetuple, std.typecons;

version (unittest)
{
    import std.stdio; // for testing only
}

/**
 * Thrown on one of the following conditions:
 * - An unrecognized command-line argument is passed
 *   and $(D stdx.getopt.config.passThrough) was not present.
 */
class GetOptException : Exception
{
    @safe pure nothrow
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/**
   Parse and remove command line options from an string array.

   Synopsis:

---------
import stdx.getopt;

string data = "file.dat";
int length = 24;
bool verbose;
enum Color { no, yes };
Color color;

void main(string[] args)
{
  getopt(
    args,
    "length",  &length,    // numeric
    "file",    &data,      // string
    "verbose", &verbose,   // flag
    "color",   &color);    // enum
  ...
}
---------

 The $(D getopt) function takes a reference to the command line
 (as received by $(D main)) as its first argument, and an
 unbounded number of pairs of strings and pointers. Each string is an
 option meant to "fill" the value pointed-to by the pointer to its
 right (the "bound" pointer). The option string in the call to
 $(D getopt) should not start with a dash.

 In all cases, the command-line options that were parsed and used by
 $(D getopt) are removed from $(D args). Whatever in the
 arguments did not look like an option is left in $(D args) for
 further processing by the program. Values that were unaffected by the
 options are not touched, so a common idiom is to initialize options
 to their defaults and then invoke $(D getopt). If a
 command-line argument is recognized as an option with a parameter and
 the parameter cannot be parsed properly (e.g. a number is expected
 but not present), a $(D ConvException) exception is thrown.
 If $(D stdx.getopt.config.passThrough) was not passed to getopt
 and an unrecognized command-line argument is found, a $(D GetOptException)
 is thrown.

 Depending on the type of the pointer being bound, $(D getopt)
 recognizes the following kinds of options:

 $(OL $(LI $(I Boolean options). A lone argument sets the option to $(D true).
 Additionally $(B true) or $(B false) can be set within the option separated with
 an "=" sign:

---------
  bool verbose = false, debugging = true;
  getopt(args, "verbose", &verbose, "debug", &debugging);
---------

 To set $(D verbose) to $(D true), invoke the program with either $(D
 --verbose) or $(D --verbose=true).

 To set $(D debugging) to $(D false), invoke the program with $(D --debugging=false).

 )$(LI $(I Numeric options.) If an option is bound to a numeric type, a
 number is expected as the next option, or right within the option
 separated with an "=" sign:

---------
  uint timeout;
  getopt(args, "timeout", &timeout);
---------

To set $(D timeout) to $(D 5), invoke the program with either $(D
--timeout=5) or $(D --timeout 5).

 $(UL $(LI $(I Incremental options.) If an option name has a "+" suffix and
 is bound to a numeric type, then the option's value tracks the number
 of times the option occurred on the command line:

---------
  uint paranoid;
  getopt(args, "paranoid+", &paranoid);
---------

 Invoking the program with "--paranoid --paranoid --paranoid" will set
 $(D paranoid) to 3. Note that an incremental option never
 expects a parameter, e.g. in the command line "--paranoid 42
 --paranoid", the "42" does not set $(D paranoid) to 42;
 instead, $(D paranoid) is set to 2 and "42" is not considered
 as part of the normal program arguments.)))

 $(LI $(I Enum options.) If an option is bound to an enum, an enum symbol as a
 string is expected as the next option, or right within the option separated
 with an "=" sign:

---------
  enum Color { no, yes };
  Color color; // default initialized to Color.no
  getopt(args, "color", &color);
---------

To set $(D color) to $(D Color.yes), invoke the program with either $(D
--color=yes) or $(D --color yes).)

 $(LI $(I String options.) If an option is bound to a string, a string
 is expected as the next option, or right within the option separated
 with an "=" sign:

---------
string outputFile;
getopt(args, "output", &outputFile);
---------

 Invoking the program with "--output=myfile.txt" or "--output
 myfile.txt" will set $(D outputFile) to "myfile.txt". If you want to
 pass a string containing spaces, you need to use the quoting that is
 appropriate to your shell, e.g. --output='my file.txt'.)

 $(LI $(I Array options.) If an option is bound to an array, a new
 element is appended to the array each time the option occurs:

---------
string[] outputFiles;
getopt(args, "output", &outputFiles);
---------

 Invoking the program with "--output=myfile.txt --output=yourfile.txt"
 or "--output myfile.txt --output yourfile.txt" will set $(D
 outputFiles) to [ "myfile.txt", "yourfile.txt" ].

 Alternatively you can set $(LREF arraySep) as the element separator:

---------
string[] outputFiles;
arraySep = ",";  // defaults to "", separation by whitespace
getopt(args, "output", &outputFiles);
---------

 With the above code you can invoke the program with
 "--output=myfile.txt,yourfile.txt", or "--output myfile.txt,yourfile.txt".)

 $(LI $(I Hash options.) If an option is bound to an associative
 array, a string of the form "name=value" is expected as the next
 option, or right within the option separated with an "=" sign:

---------
double[string] tuningParms;
getopt(args, "tune", &tuningParms);
---------

Invoking the program with e.g. "--tune=alpha=0.5 --tune beta=0.6" will
set $(D tuningParms) to [ "alpha" : 0.5, "beta" : 0.6 ].

Alternatively you can set $(LREF arraySep) as the element separator:

---------
double[string] tuningParms;
arraySep = ",";  // defaults to "", separation by whitespace
getopt(args, "tune", &tuningParms);
---------

With the above code you can invoke the program with
"--tune=alpha=0.5,beta=0.6", or "--tune alpha=0.5,beta=0.6".

In general, the keys and values can be of any parsable types.

$(LI $(I Callback options.) An option can be bound to a function or
delegate with the signature $(D void function()), $(D void function(string option)),
$(D void function(string option, string value)), or their delegate equivalents.

$(UL $(LI If the callback doesn't take any arguments, the callback is invoked
whenever the option is seen.) $(LI If the callback takes one string argument,
the option string (without the leading dash(es)) is passed to the callback.
After that, the option string is considered handled and removed from the
options array.

---------
void main(string[] args)
{
  uint verbosityLevel = 1;
  void myHandler(string option)
  {
    if (option == "quiet")
    {
      verbosityLevel = 0;
    }
    else
    {
      assert(option == "verbose");
      verbosityLevel = 2;
    }
  }
  getopt(args, "verbose", &myHandler, "quiet", &myHandler);
}
---------

)$(LI If the callback takes two string arguments, the
option string is handled as an option with one argument, and parsed
accordingly. The option and its value are passed to the
callback. After that, whatever was passed to the callback is
considered handled and removed from the list.

---------
void main(string[] args)
{
  uint verbosityLevel = 1;
  void myHandler(string option, string value)
  {
    switch (value)
    {
      case "quiet": verbosityLevel = 0; break;
      case "verbose": verbosityLevel = 2; break;
      case "shouting": verbosityLevel = verbosityLevel.max; break;
      default :
        stderr.writeln("Dunno how verbose you want me to be by saying ",
          value);
        exit(1);
    }
  }
  getopt(args, "verbosity", &myHandler);
}
---------
))))

$(B Options with multiple names)

Sometimes option synonyms are desirable, e.g. "--verbose",
"--loquacious", and "--garrulous" should have the same effect. Such
alternate option names can be included in the option specification,
using "|" as a separator:

---------
bool verbose;
getopt(args, "verbose|loquacious|garrulous", &verbose);
---------

$(B Case)

By default options are case-insensitive. You can change that behavior
by passing $(D getopt) the $(D caseSensitive) directive like this:

---------
bool foo, bar;
getopt(args,
    stdx.getopt.config.caseSensitive,
    "foo", &foo,
    "bar", &bar);
---------

In the example above, "--foo", "--bar", "--FOo", "--bAr" etc. are recognized.
The directive is active til the end of $(D getopt), or until the
converse directive $(D caseInsensitive) is encountered:

---------
bool foo, bar;
getopt(args,
    stdx.getopt.config.caseSensitive,
    "foo", &foo,
    stdx.getopt.config.caseInsensitive,
    "bar", &bar);
---------

The option "--Foo" is rejected due to $(D
stdx.getopt.config.caseSensitive), but not "--Bar", "--bAr"
etc. because the directive $(D
stdx.getopt.config.caseInsensitive) turned sensitivity off before
option "bar" was parsed.

$(B "Short" versus "long" options)

Traditionally, programs accepted single-letter options preceded by
only one dash (e.g. $(D -t)). $(D getopt) accepts such parameters
seamlessly. When used with a double-dash (e.g. $(D --t)), a
single-letter option behaves the same as a multi-letter option. When
used with a single dash, a single-letter option is accepted. If the
option has a parameter, that must be "stuck" to the option without
any intervening space or "=":

---------
uint timeout;
getopt(args, "timeout|t", &timeout);
---------

To set $(D timeout) to $(D 5), use either of the following: $(D --timeout=5),
$(D --timeout 5), $(D --t=5), $(D --t 5), or $(D -t5). Forms such as $(D -t 5)
and $(D -timeout=5) will be not accepted.

For more details about short options, refer also to the next section.

$(B Bundling)

Single-letter options can be bundled together, i.e. "-abc" is the same as
$(D "-a -b -c"). By default, this confusing option is turned off. You can
turn it on with the $(D stdx.getopt.config.bundling) directive:

---------
bool foo, bar;
getopt(args,
    stdx.getopt.config.bundling,
    "foo|f", &foo,
    "bar|b", &bar);
---------

In case you want to only enable bundling for some of the parameters,
bundling can be turned off with $(D stdx.getopt.config.noBundling).

$(B Passing unrecognized options through)

If an application needs to do its own processing of whichever arguments
$(D getopt) did not understand, it can pass the
$(D stdx.getopt.config.passThrough) directive to $(D getopt):

---------
bool foo, bar;
getopt(args,
    stdx.getopt.config.passThrough,
    "foo", &foo,
    "bar", &bar);
---------

An unrecognized option such as "--baz" will be found untouched in
$(D args) after $(D getopt) returns.

$(B Options Terminator)

A lonesome double-dash terminates $(D getopt) gathering. It is used to
separate program options from other parameters (e.g. options to be passed
to another program). Invoking the example above with $(D "--foo -- --bar")
parses foo but leaves "--bar" in $(D args). The double-dash itself is
removed from the argument array.
*/
void getopt(T...)(ref string[] args, T opts) {
    enforce(args.length,
            "Invalid arguments string passed: program name missing");
    configuration cfg;
    return getoptImpl(args, cfg, opts);
}

/**
   Configuration options for $(D getopt).

   You can pass them to $(D getopt) in any position, except in between an option
   string and its bound pointer.
*/
enum config {
    /// Turns case sensitivity on
    caseSensitive,
    /// Turns case sensitivity off
    caseInsensitive,
    /// Turns bundling on
    bundling,
    /// Turns bundling off
    noBundling,
    /// Pass unrecognized arguments through
    passThrough,
    /// Signal unrecognized arguments as errors
    noPassThrough,
    /// Stop at first argument that does not look like an option
    stopOnFirstNonOption,
}

private void getoptImpl(T...)(ref string[] args,
    ref configuration cfg, T opts)
{
    static if (opts.length)
    {
        static if (is(typeof(opts[0]) : config))
        {
            // it's a configuration flag, act on it
            setConfig(cfg, opts[0]);
            return getoptImpl(args, cfg, opts[1 .. $]);
        }
        else
        {
            // it's an option string
            auto option = to!string(opts[0]);
            auto receiver = opts[1];
            bool incremental;
            // Handle options of the form --blah+
            if (option.length && option[$ - 1] == autoIncrementChar)
            {
                option = option[0 .. $ - 1];
                incremental = true;
            }
            handleOption(option, receiver, args, cfg, incremental);
            return getoptImpl(args, cfg, opts[2 .. $]);
        }
    }
    else
    {
        // no more options to look for, potentially some arguments left
        foreach (i, a ; args[1 .. $]) {
            if (!a.length || a[0] != optionChar)
            {
                // not an option
                if (cfg.stopOnFirstNonOption) break;
                continue;
            }
            if (endOfOptions.length && a == endOfOptions)
            {
                // Consume the "--"
                args = args.remove(i + 1);
                break;
            }
            if (!cfg.passThrough)
            {
                throw new GetOptException("Unrecognized option "~a);
            }
        }
    }
}

void handleOption(R)(string option, R receiver, ref string[] args,
        ref configuration cfg, bool incremental)
{
    // Scan arguments looking for a match for this option
    for (size_t i = 1; i < args.length; ) {
        auto a = args[i];
        if (endOfOptions.length && a == endOfOptions) break;
        if (cfg.stopOnFirstNonOption && (!a.length || a[0] != optionChar))
        {
            // first non-option is end of options
            break;
        }
        // Unbundle bundled arguments if necessary
        if (cfg.bundling && a.length > 2 && a[0] == optionChar &&
                a[1] != optionChar)
        {
            string[] expanded;
            foreach (j, dchar c; a[1 .. $])
            {
                // If the character is not alpha, stop right there. This allows
                // e.g. -j100 to work as "pass argument 100 to option -j".
                if (!isAlpha(c))
                {
                    expanded ~= a[j + 1 .. $];
                    break;
                }
                expanded ~= text(optionChar, c);
            }
            args = args[0 .. i] ~ expanded ~ args[i + 1 .. $];
            continue;
        }

        string val;
        if (!optMatch(a, option, val, cfg))
        {
            ++i;
            continue;
        }
        // found it
        // from here on, commit to eat args[i]
        // (and potentially args[i + 1] too, but that comes later)
        args = args[0 .. i] ~ args[i + 1 .. $];

        static if (is(typeof(*receiver) == bool))
        {
            // parse '--b=true/false'
            if (val.length)
            {
                *receiver = to!(typeof(*receiver))(val);
                break;
            }

            // no argument means set it to true
            *receiver = true;
            break;
        }
        else
        {
            // non-boolean option, which might include an argument
            //enum isCallbackWithOneParameter = is(typeof(receiver("")) : void);
            enum isCallbackWithLessThanTwoParameters =
                (is(typeof(receiver) == delegate) || is(typeof(*receiver) == function)) &&
                !is(typeof(receiver("", "")));
            if (!isCallbackWithLessThanTwoParameters && !(val.length) && !incremental) {
                // Eat the next argument too.  Check to make sure there's one
                // to be eaten first, though.
                enforce(i < args.length,
                    "Missing value for argument " ~ a ~ ".");
                val = args[i];
                args = args[0 .. i] ~ args[i + 1 .. $];
            }
            static if (is(typeof(*receiver) == enum))
            {
                *receiver = to!(typeof(*receiver))(val);
            }
            else static if (is(typeof(*receiver) : real))
            {
                // numeric receiver
                if (incremental) ++*receiver;
                else *receiver = to!(typeof(*receiver))(val);
            }
            else static if (is(typeof(*receiver) == string))
            {
                // string receiver
                *receiver = to!(typeof(*receiver))(val);
            }
            else static if (is(typeof(receiver) == delegate) ||
                            is(typeof(*receiver) == function))
            {
                static if (is(typeof(receiver("", "")) : void))
                {
                    // option with argument
                    receiver(option, val);
                }
                else static if (is(typeof(receiver("")) : void))
                {
                    static assert(is(typeof(receiver("")) : void));
                    // boolean-style receiver
                    receiver(option);
                }
                else
                {
                    static assert(is(typeof(receiver()) : void));
                    // boolean-style receiver without argument
                    receiver();
                }
            }
            else static if (isArray!(typeof(*receiver)))
            {
                // array receiver
                import std.range : ElementEncodingType;
                alias E = ElementEncodingType!(typeof(*receiver));

                if (arraySep == "")
                {
                    *receiver ~= to!E(val);
                }
                else
                {
                    foreach (elem; val.splitter(arraySep).map!(a => to!E(a)))
                        *receiver ~= elem;
                }
            }
            else static if (isAssociativeArray!(typeof(*receiver)))
            {
                // hash receiver
                alias K = typeof(receiver.keys[0]);
                alias V = typeof(receiver.values[0]);

                import std.range : only;
                import std.typecons : Tuple, tuple;

                static Tuple!(K, V) getter(string input)
                {
                    auto j = std.string.indexOf(input, assignChar);
                    auto key = input[0 .. j];
                    auto value = input[j + 1 .. $];
                    return tuple(to!K(key), to!V(value));
                }

                static void setHash(Range)(R receiver, Range range)
                {
                    foreach (k, v; range.map!getter)
                        (*receiver)[k] = v;
                }

                if (arraySep == "")
                    setHash(receiver, val.only);
                else
                    setHash(receiver, val.splitter(arraySep));
            }
            else
            {
                static assert(false, "Dunno how to deal with type " ~
                        typeof(receiver).stringof);
            }
        }
    }
}

// 5316 - arrays with arraySep
unittest
{
    arraySep = ",";
    scope (exit) arraySep = "";

    string[] names;
    auto args = ["program.name", "-nfoo,bar,baz"];
    getopt(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));

    names = names.init;
    args = ["program.name", "-n" "foo,bar,baz"].dup;
    getopt(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));

    names = names.init;
    args = ["program.name", "--name=foo,bar,baz"].dup;
    getopt(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));

    names = names.init;
    args = ["program.name", "--name", "foo,bar,baz"].dup;
    getopt(args, "name|n", &names);
    assert(names == ["foo", "bar", "baz"], to!string(names));
}

// 5316 - associative arrays with arraySep
unittest
{
    arraySep = ",";
    scope (exit) arraySep = "";

    int[string] values;
    values = values.init;
    auto args = ["program.name", "-vfoo=0,bar=1,baz=2"].dup;
    getopt(args, "values|v", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));

    values = values.init;
    args = ["program.name", "-v", "foo=0,bar=1,baz=2"].dup;
    getopt(args, "values|v", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));

    values = values.init;
    args = ["program.name", "--values=foo=0,bar=1,baz=2"];
    getopt(args, "values|t", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));

    values = values.init;
    args = ["program.name", "--values", "foo=0,bar=1,baz=2"].dup;
    getopt(args, "values|v", &values);
    assert(values == ["foo":0, "bar":1, "baz":2], to!string(values));
}

/**
   The option character (default '-').

   Defaults to '-' but it can be assigned to prior to calling $(D getopt).
 */
dchar optionChar = '-';

/**
   The string that conventionally marks the end of all options (default '--').

   Defaults to "--" but can be assigned to prior to calling $(D getopt). Assigning an
   empty string to $(D endOfOptions) effectively disables it.
 */
string endOfOptions = "--";

/**
   The assignment character used in options with parameters (default '=').

   Defaults to '=' but can be assigned to prior to calling $(D getopt).
 */
dchar assignChar = '=';

/**
   The string used to separate the elements of an array or associative array
   (default is "" which means the elements are separated by whitespace).

   Defaults to "" but can be assigned to prior to calling $(D getopt).
 */
string arraySep = "";

enum autoIncrementChar = '+';

private struct configuration
{
    mixin(bitfields!(
                bool, "caseSensitive",  1,
                bool, "bundling", 1,
                bool, "passThrough", 1,
                bool, "stopOnFirstNonOption", 1,
                ubyte, "", 4));
}

private bool optMatch(string arg, string optPattern, ref string value,
    configuration cfg)
{
    //writeln("optMatch:\n  ", arg, "\n  ", optPattern, "\n  ", value);
    //scope(success) writeln("optMatch result: ", value);
    if (!arg.length || arg[0] != optionChar) return false;
    // yank the leading '-'
    arg = arg[1 .. $];
    immutable isLong = arg.length > 1 && arg[0] == optionChar;
    //writeln("isLong: ", isLong);
    // yank the second '-' if present
    if (isLong) arg = arg[1 .. $];
    immutable eqPos = std.string.indexOf(arg, assignChar);
    if (isLong && eqPos >= 0)
    {
        // argument looks like --opt=value
        value = arg[eqPos + 1 .. $];
        arg = arg[0 .. eqPos];
    }
    else
    {
        if (!isLong && !cfg.bundling)
        {
            // argument looks like -ovalue and there's no bundling
            value = arg[1 .. $];
            arg = arg[0 .. 1];
        }
        else
        {
            // argument looks like --opt, or -oxyz with bundling
            value = null;
        }
    }
    //writeln("Arg: ", arg, " pattern: ", optPattern, " value: ", value);
    // Split the option
    const variants = split(optPattern, "|");
    foreach (v ; variants)
    {
        //writeln("Trying variant: ", v, " against ", arg);
        if (arg == v || !cfg.caseSensitive && toUpper(arg) == toUpper(v))
            return true;
        if (cfg.bundling && !isLong && v.length == 1
                && std.string.indexOf(arg, v) >= 0)
        {
            //writeln("success");
            return true;
        }
    }
    return false;
}

private void setConfig(ref configuration cfg, config option)
{
    switch (option)
    {
    case config.caseSensitive: cfg.caseSensitive = true; break;
    case config.caseInsensitive: cfg.caseSensitive = false; break;
    case config.bundling: cfg.bundling = true; break;
    case config.noBundling: cfg.bundling = false; break;
    case config.passThrough: cfg.passThrough = true; break;
    case config.noPassThrough: cfg.passThrough = false; break;
    case config.stopOnFirstNonOption:
        cfg.stopOnFirstNonOption = true; break;
    default: assert(false);
    }
}

unittest
{
    import std.math;
    uint paranoid = 2;
    string[] args = (["program.name",
                      "--paranoid", "--paranoid", "--paranoid"]).dup;
    getopt(args, "paranoid+", &paranoid);
    assert(paranoid == 5, to!(string)(paranoid));

    enum Color { no, yes }
    Color color;
    args = (["program.name", "--color=yes",]).dup;
    getopt(args, "color", &color);
    assert(color, to!(string)(color));

    color = Color.no;
    args = (["program.name", "--color", "yes",]).dup;
    getopt(args, "color", &color);
    assert(color, to!(string)(color));

    string data = "file.dat";
    int length = 24;
    bool verbose = false;
    args = (["program.name", "--length=5",
                      "--file", "dat.file", "--verbose"]).dup;
    getopt(
        args,
        "length",  &length,
        "file",    &data,
        "verbose", &verbose);
    assert(args.length == 1);
    assert(data == "dat.file");
    assert(length == 5);
    assert(verbose);

    //
    string[] outputFiles;
    args = (["program.name", "--output=myfile.txt",
             "--output", "yourfile.txt"]).dup;
    getopt(args, "output", &outputFiles);
    assert(outputFiles.length == 2
           && outputFiles[0] == "myfile.txt" && outputFiles[1] == "yourfile.txt");

    outputFiles = [];
    arraySep = ",";
    args = (["program.name", "--output", "myfile.txt,yourfile.txt"]).dup;
    getopt(args, "output", &outputFiles);
    assert(outputFiles.length == 2
           && outputFiles[0] == "myfile.txt" && outputFiles[1] == "yourfile.txt");
    arraySep = "";

    foreach (testArgs;
        [["program.name", "--tune=alpha=0.5", "--tune", "beta=0.6"],
         ["program.name", "--tune=alpha=0.5,beta=0.6"],
         ["program.name", "--tune", "alpha=0.5,beta=0.6"]])
    {
        arraySep = ",";
        double[string] tuningParms;
        getopt(testArgs, "tune", &tuningParms);
        assert(testArgs.length == 1);
        assert(tuningParms.length == 2);
        assert(approxEqual(tuningParms["alpha"], 0.5));
        assert(approxEqual(tuningParms["beta"], 0.6));
        arraySep = "";
    }

    uint verbosityLevel = 1;
    void myHandler(string option)
    {
        if (option == "quiet")
        {
            verbosityLevel = 0;
        }
        else
        {
            assert(option == "verbose");
            verbosityLevel = 2;
        }
    }
    args = (["program.name", "--quiet"]).dup;
    getopt(args, "verbose", &myHandler, "quiet", &myHandler);
    assert(verbosityLevel == 0);
    args = (["program.name", "--verbose"]).dup;
    getopt(args, "verbose", &myHandler, "quiet", &myHandler);
    assert(verbosityLevel == 2);

    verbosityLevel = 1;
    void myHandler2(string option, string value)
    {
        assert(option == "verbose");
        verbosityLevel = 2;
    }
    args = (["program.name", "--verbose", "2"]).dup;
    getopt(args, "verbose", &myHandler2);
    assert(verbosityLevel == 2);

    verbosityLevel = 1;
    void myHandler3()
    {
        verbosityLevel = 2;
    }
    args = (["program.name", "--verbose"]).dup;
    getopt(args, "verbose", &myHandler3);
    assert(verbosityLevel == 2);

    bool foo, bar;
    args = (["program.name", "--foo", "--bAr"]).dup;
    getopt(args,
        stdx.getopt.config.caseSensitive,
        stdx.getopt.config.passThrough,
        "foo", &foo,
        "bar", &bar);
    assert(args[1] == "--bAr");

    // test stopOnFirstNonOption

    args = (["program.name", "--foo", "nonoption", "--bar"]).dup;
    foo = bar = false;
    getopt(args,
        stdx.getopt.config.stopOnFirstNonOption,
        "foo", &foo,
        "bar", &bar);
    assert(foo && !bar && args[1] == "nonoption" && args[2] == "--bar");

    args = (["program.name", "--foo", "nonoption", "--zab"]).dup;
    foo = bar = false;
    getopt(args,
        stdx.getopt.config.stopOnFirstNonOption,
        "foo", &foo,
        "bar", &bar);
    assert(foo && !bar && args[1] == "nonoption" && args[2] == "--zab");

    args = (["program.name", "--fb1", "--fb2=true", "--tb1=false"]).dup;
    bool fb1, fb2;
    bool tb1 = true;
    getopt(args, "fb1", &fb1, "fb2", &fb2, "tb1", &tb1);
    assert(fb1 && fb2 && !tb1);

    // test function callbacks

    static class MyEx : Exception
    {
        this() { super(""); }
        this(string option) { this(); this.option = option; }
        this(string option, string value) { this(option); this.value = value; }

        string option;
        string value;
    }

    static void myStaticHandler1() { throw new MyEx(); }
    args = (["program.name", "--verbose"]).dup;
    try { getopt(args, "verbose", &myStaticHandler1); assert(0); }
    catch (MyEx ex) { assert(ex.option is null && ex.value is null); }

    static void myStaticHandler2(string option) { throw new MyEx(option); }
    args = (["program.name", "--verbose"]).dup;
    try { getopt(args, "verbose", &myStaticHandler2); assert(0); }
    catch (MyEx ex) { assert(ex.option == "verbose" && ex.value is null); }

    static void myStaticHandler3(string option, string value) { throw new MyEx(option, value); }
    args = (["program.name", "--verbose", "2"]).dup;
    try { getopt(args, "verbose", &myStaticHandler3); assert(0); }
    catch (MyEx ex) { assert(ex.option == "verbose" && ex.value == "2"); }
}

unittest
{
    // From bugzilla 2142
    bool f_linenum, f_filename;
    string[] args = [ "", "-nl" ];
    getopt
        (
            args,
            stdx.getopt.config.bundling,
            //stdx.getopt.config.caseSensitive,
            "linenum|l", &f_linenum,
            "filename|n", &f_filename
        );
    assert(f_linenum);
    assert(f_filename);
}

unittest
{
    // From bugzilla 6887
    string[] p;
    string[] args = ["", "-pa"];
    getopt(args, "p", &p);
    assert(p.length == 1);
    assert(p[0] == "a");
}

unittest
{
    // From bugzilla 6888
    int[string] foo;
    auto args = ["", "-t", "a=1"];
    getopt(args, "t", &foo);
    assert(foo == ["a":1]);
}

unittest
{
    // From bugzilla 9583
    int opt;
    auto args = ["prog", "--opt=123", "--", "--a", "--b", "--c"];
    getopt(args, "opt", &opt);
    assert(args == ["prog", "--a", "--b", "--c"]);
}

unittest
{
    string foo, bar;
    auto args = ["prog", "-thello", "-dbar=baz"];
    getopt(args, "t", &foo, "d", &bar);
    assert(foo == "hello");
    assert(bar == "bar=baz");
    // From bugzilla 5762
    string a;
    args = ["prog", "-a-0x12"];
    getopt(args, config.bundling, "a|addr", &a);
    assert(a == "-0x12", a);
    args = ["prog", "--addr=-0x12"];
    getopt(args, config.bundling, "a|addr", &a);
    assert(a == "-0x12");
    // From https://d.puremagic.com/issues/show_bug.cgi?id=11764
    args = ["main", "-test"];
    bool opt;
    args.getopt(config.passThrough, "opt", &opt);
    assert(args == ["main", "-test"]);
}

unittest // 5228
{
    auto args = ["prog", "--foo=bar"];
    int abc;
    assertThrown!GetOptException(getopt(args, "abc", &abc));

    args = ["prog", "--abc=string"];
    assertThrown!ConvException(getopt(args, "abc", &abc));
}

unittest // From bugzilla 7693
{
    enum Foo {
        bar,
        baz
    }

    auto args = ["prog", "--foo=barZZZ"];
    Foo foo;
    assertThrown(getopt(args, "foo", &foo));
    args = ["prog", "--foo=bar"];
    assertNotThrown(getopt(args, "foo", &foo));
    args = ["prog", "--foo", "barZZZ"];
    assertThrown(getopt(args, "foo", &foo));
    args = ["prog", "--foo", "baz"];
    assertNotThrown(getopt(args, "foo", &foo));
}

unittest // same bug as 7693 only for bool
{
    auto args = ["prog", "--foo=truefoobar"];
    bool foo;
    assertThrown(getopt(args, "foo", &foo));
    args = ["prog", "--foo"];
    getopt(args, "foo", &foo);
    assert(foo);
}

/** The result of the $(D getoptEx) function.

The $(D GetOptDRslt) contains two members. The first member is a boolean with
the name $(D help). The second member is an array of $(D Option). The array is
accessable by the name $(D options).
*/
struct GetoptExRslt {
    bool help; /// Flag indicating if help was requested
    Option[] options; /// All possible options
}

/** The result of the $(D getoptExHelp) function.
*/
struct Option {
    string optShort; /// The short symbol for this option
    string optLong; /// The long symbol for this option
    string help; /// The description of this option
}

/** The function getoptEx allows to associated $(D getopt) options will help
messages.

A $(D getoptEx) argument consists of one of the following argument sequences.

$(TABLE
$(TR $(TD argument:) $(TD $(DDOC_KEYWORD string), $(D T*)))
$(TR $(TD argument:) $(TD $(DDOC_KEYWORD string),  $(DDOC_KEYWORD string), $(D T*)))
)
If the second $(DDOC_KEYWORD string) is given the resulting $(D Option) will
contain the string as a help message. If no second $(DDOC_KEYWORD string) is
passed, the resulting $(D Option) has no help message.

Returns: The function returns an $(D GetoptExRslt) tuple. The tuple
contains a $(D bool) indicating if the help information where required. It also
contains an array of $(D Object)s that encompass the available options and 
there associated help messages.
*/
GetoptExRslt getoptEx(T...)(ref string[] args, T opts)
{
    Option[] helpMsg = getoptExHelp(opts); // extract all help strings

    // we need passThrough as we handle the option one by one
    configuration cfg; 
    setConfig(cfg, stdx.getopt.config.passThrough);

    bool help = false; // state tells if called with "--help"

    getoptExImpl(args, cfg, &help, opts);

    GetoptExRslt rslt;
    rslt.help = help;
    rslt.options = helpMsg;

    return rslt;
}

///
unittest
{
    auto args = ["prog", "--foo", "-b"];

    bool foo;
    bool bar;
    auto rslt = getoptEx(args, "foo|f" "Some information about foo.", &foo, "bar|b", 
        "Some help message about bar.", &bar);

    if (rslt.help) 
    {
        defaultGetoptXPrinter("Some information about the program.",
            rslt.options);
    }
}

private void getoptExImpl(T...)(ref string[] args, ref configuration cfg, 
        bool* help, T opts)
{
    static if (T.length && is(typeof(opts[0]) : config))
    {
        setConfig(cfg, opts[0]);
        getoptExImpl(args, cfg, help, opts[1 .. $]);
    }
    else static if (T.length == 2)
    {
        static assert(is(typeof(opts[0]) : string), 
            "An option, in form of a string must come first.");

        getoptImpl(args, cfg, opts[0], opts[1], "help|h", help);
    }
    else static if (T.length > 2 && is(typeof(opts[1]) : string))
    {
        static assert(is(typeof(opts[0]) : string), 
            "An option, in form of a string must come first.");

        getoptImpl(args, cfg, opts[0], opts[2], "help|h", help);
        getoptExImpl(args, cfg, help, opts[3 .. $]);
    }
    else static if (T.length > 2 && !is(typeof(opts[1]) : string))
    {
        static assert(is(typeof(opts[0]) : string), 
            "An option, in form of a string must come first.");

        getoptImpl(args, cfg, opts[0], opts[1], "help|h", help);
        getoptExImpl(args, cfg, help, opts[2 .. $]);
    }
}

unittest 
{
    bool foo;
    auto args = ["prog", "--foo"];
    getoptEx(args, "foo", &foo);
    assert(foo);
}

unittest
{
    bool foo;
    bool bar;
    auto args = ["prog", "--foo", "-b"];
    getoptEx(args, config.caseInsensitive,"foo|f" "Some foo", &foo,
        config.caseSensitive, "bar|b", "Some bar", &bar);
    assert(foo);
    assert(bar);
}

unittest
{
    bool foo;
    bool bar;
    auto args = ["prog", "-b", "--foo", "-z"];
    getoptEx(args, config.caseInsensitive,"foo|f" "Some foo", &foo,
        config.caseSensitive, "bar|b", "Some bar", &bar);
    assert(foo);
    assert(bar);
}

/** This function extracts the options and there help information from an
given option sequence.

As described earlier, a help message can be associated with a option. This
function transforms these pairs into an array of $(D Option). Additionally,
the description of the help option is appended to the array.

Returns: An array of $(D Option) describing all passed options.
*/
private pure Option[] getoptExHelp(T...)(T opts) @trusted nothrow
{
    static pure Option splitAndGet(string opt) @trusted nothrow
    {
        auto sp = split(opt, "|");
        Option ret;
        if (sp.length > 1) 
        {
            ret.optShort = "-" ~ (sp[0].length < sp[1].length ? 
                sp[0] : sp[1]);
            ret.optLong = "--" ~ (sp[0].length > sp[1].length ? 
                sp[0] : sp[1]);
        } 
        else 
        {
            ret.optLong = "--" ~ sp[0];
        }

        return ret;
    }

    static if (T.length && is(typeof(opts[0]) : config))
    {
        return getoptExHelp(opts[1 .. $]);
    }
    else static if (T.length == 2)
    {
        static assert(is(typeof(opts[0]) : string), 
            "An option, in form of a string must come first.");

        Option ret = splitAndGet(opts[0]);
        return [ret] ~ getoptExHelp(opts[2 ..$]);
    }
    else static if (T.length > 2 && is(typeof(opts[1]) : string))
    {
        static assert(is(typeof(opts[0]) : string), 
            "An option, in form of a string must come first.");

        Option ret = splitAndGet(opts[0]);
        ret.help = opts[1];
        return [ret] ~ getoptExHelp(opts[3 ..$]);
    }
    else static if (T.length > 2 && !is(typeof(opts[1]) : string))
    {
        static assert(is(typeof(opts[0]) : string), 
            "An option, in form of a string must come first.");

        Option ret = splitAndGet(opts[0]);
        return [ret] ~ getoptExHelp(opts[2 ..$]);
    }
    else
    {
        Option help;
        help.optShort = "-h";
        help.optLong = "--help";
        help.help = "This help.";
        return [help];
    }
}

unittest
{
    int a,b,c;
    auto t = getoptExHelp("hello|z", "Help", &a);
    assert(t.length == 2);
    assert(t[0].optShort == "-z", t[0].optShort);
    assert(t[0].optLong == "--hello");

    auto t2 = getoptExHelp("hello|z", &a);
    assert(t2.length == 2);
    assert(t2[0].optShort == "-z");
    assert(t2[0].optLong == "--hello");

    auto t3 = getoptExHelp("hello|z", "some info", &a, "foo|f", &b);
    assert(t3.length == 3, to!string(t3.length));
    assert(t3[0].optShort == "-z");
    assert(t3[0].optLong == "--hello");
    assert(t3[0].help == "some info");
    assert(t3[1].optShort == "-f", t3[1].optShort);
    assert(t3[1].optLong == "--foo");
    assert(t3[1].help.length == 0);

    auto t4 = getoptExHelp("hello|z", &a, "foo|f", "some info", &b, "b", &c);
    assert(t4.length == 4);
    assert(t4[0].optShort == "-z");
    assert(t4[0].optLong == "--hello");
    assert(t4[0].help.length == 0);
    assert(t4[1].optShort == "-f", t4[1].optShort);
    assert(t4[1].optLong == "--foo");
    assert(t4[1].help == "some info");
    assert(t4[2].optLong == "--b", t4[2].optShort);
    assert(t4[2].optShort.length == 0);
    assert(t4[2].help.length == 0);
}

unittest
{
    int a,b,c;
    auto zzz = stdx.getopt.config.caseSensitive;
    auto t = getoptExHelp(zzz, "hello|z", "Help", &a);
    assert(t.length == 2);
    assert(t[0].optShort == "-z", t[0].optShort);
    assert(t[0].optLong == "--hello");

    auto t2 = getoptExHelp(zzz, "hello|z", &a);
    assert(t2.length == 2);
    assert(t2[0].optShort == "-z");
    assert(t2[0].optLong == "--hello");

    auto t3 = getoptExHelp(zzz, "hello|z", "some info", &a, "foo|f", &b);
    assert(t3.length == 3, to!string(t3.length));
    assert(t3[0].optShort == "-z");
    assert(t3[0].optLong == "--hello");
    assert(t3[0].help == "some info");
    assert(t3[1].optShort == "-f", t3[1].optShort);
    assert(t3[1].optLong == "--foo");
    assert(t3[1].help.length == 0);

    auto t4 = getoptExHelp(zzz, "hello|z", &a, "foo|f", "some info", &b, "b", &c);
    assert(t4.length == 4);
    assert(t4[0].optShort == "-z");
    assert(t4[0].optLong == "--hello");
    assert(t4[0].help.length == 0);
    assert(t4[1].optShort == "-f", t4[1].optShort);
    assert(t4[1].optLong == "--foo");
    assert(t4[1].help == "some info");
    assert(t4[2].optLong == "--b", t4[2].optShort);
    assert(t4[2].optShort.length == 0);
    assert(t4[2].help.length == 0);
}

/** This function prints the passed $(D Option) and text in an aligned manner. 

The passed text will be printed first, followed by a newline. Than the short
and long version of every option will be printed. The short and long version
will be aligned to the longest option of every $(D Option) passed. If a help
message is present it will be printed after the long version of the 
$(D Option).

------------
foreach(it; opt) {
    writefln("%*s %*s %s", lengthOfLongestShortOption, it.optShort,
        lengthOfLongestLongOption, it.optLong, it.help);
}
------------

Params:
    text = The text to printed at the beginning of the help output.
    opt = The $(D Option) extracted from the $(D getoptEx) parameter.
*/
void defaultGetoptXPrinter(string text, Option[] opt) 
{
    import std.stdio : stdout;

    defaultGetoptXFormatter(stdout.lockingTextWriter(), text, opt);
}

/** This function writes the passed text and $(D Option) into an output range
in the manner, described in the documentation of function 
$(D defaultGetoptXPrinter).

Params:
    output = The output range used to write the help information.
    text = The text to printed at the beginning of the help output.
    opt = The $(D Option) extracted from the $(D getoptEx) parameter.
*/
void defaultGetoptXFormatter(Output)(Output output, string text, Option[] opt) {
    import std.format : formattedWrite;

    output.formattedWrite("%s\n", text);

    size_t ls, ll;
    foreach (it; opt) 
    {
        ls = max(ls, it.optShort.length);    
        ll = max(ll, it.optLong.length);    
    }

    size_t argLength = ls + ll + 2;

    foreach (it; opt) 
    {
        output.formattedWrite("%*s %*s %s\n", ls, it.optShort, ll, it.optLong,
            it.help);
    }
}

unittest
{
    bool a;
    auto args = ["prog", "--foo"];
    auto t = getoptEx(args, "foo|f", "Help", &a);
    string s;
    auto app = appender!string();
    defaultGetoptXFormatter(app, "Some Text", t.options);

    string helpMsg = app.data();
    assert(helpMsg.length);
    assert(helpMsg.count("\n") == 3, to!string(helpMsg.count("\n")));
    assert(helpMsg.indexOf("--foo") != -1);
    assert(helpMsg.indexOf("-f") != -1);
    assert(helpMsg.indexOf("-h") != -1);
    assert(helpMsg.indexOf("--help") != -1);
    assert(helpMsg.indexOf("Help") != -1);
    
    string wanted = "Some Text\n-f  --foo Help\n-h --help This help.\n";
    assert(wanted == helpMsg);
}
