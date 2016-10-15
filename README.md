Bazel Aspects
================

> Some people, when confronted with a problem, think "I know, I'll use
> bazel aspects."  Now they have a set of problems (defined by the
> transitive closure reachable from P over K).

Bazel aspects are a seemingly obscure and poorly understood feature
for many people (including me!).  When would you use one?  What are
they?  How to they work?  How do you implement one?  I wrote this up
to improve my understanding of aspects; hopefully it will help others
better understand this powerful feature.  If you do learn something
here, please star the repo.

## What is it?

A kind of
[visitor pattern](https://en.wikipedia.org/wiki/Visitor_pattern) over
the bazel dependency tree.

## Why would you want one?

An aspect may be useful to generate some type of artifact parallel to
the kind normally produced by a rule.  The primary use case has
initially been IDE support wherein metadata files are generated that
an IDE requires (see
https://github.com/bazelbuild/e4b/tree/ae17bdebcb1733ff1cb9172043652668fd85725c/com.google.devtools.bazel.e4b/resources/tools/must/be/unique).

## How do they work?

When a rule declares an attribute that uses an aspect such as
`attr.label(aspects = ['foo_aspect']`, bazel looks at the definition
of the aspect to see what attributes it propogates down.  For example,
it might say `attr_aspects = ['deps]`.

When that rule is invoked, bazel will:

1. Traverse down the dependency graph from the originating rule in
   depth-first fashion, following edges named 'deps'.

1. Apply the aspect rule to each matched rule (in this example
   `java_library` and `java_binary`).

As an aspect implementor, your job is to:

1. Get oriented to the kind of rule you are visiting via
`aspect_ctx.rule.kind` property.

2. Do something (`ctx.file_action`, `ctx.action`, etc..).

3. Collect a transitive set of generated output files and pass them
   off somewhere to be consumed (either from the command line or a
   another rule).

## How are they invoked?

1. From the command line with the `--aspects` flag (see Makefile),
   probably in conjunction with `--output_groups`.

2. From a rule attribute that declares an aspect (see `java_info`
   rule).

## How to you implement one?

Writing an aspect rule is similar to writing a normal rule.  There are
some differences in the types of attributes allowed (labels must be
private for example), but the biggest hurdle is understanding the
function signature for the aspect implementation, which looks like:

```python
def _info_aspect_impl(target, aspect_ctx):
  ...
```

Let's look at these in greater detail.  To do that, we'll write a
function to print out the properties of the object using `dir`.  We
need special logic to exclude function names:

```python
def _describe(name, obj, exclude):
    """Print the properties of the given struct obj
    Args:
      name: the name of the struct we are introspecting.
      obj: the struct to introspect
      exclude: a list of names *not* to print (function names)
    """
    for k in dir(obj):
        if hasattr(obj, k) and k not in exclude:
            v = getattr(obj, k)
            t = type(v)
            print("%s.%s<%r> = %s" % (name, k, t, v))
```

### The `target` argument

Let's look at the first argument, `target`.

```python
type(target)
RuleConfiguredTarget
```

```python
dir(target)
["data_runfiles", "default_runfiles", "files", "files_to_run", "java", "label", "output_group"]
```

```python
_describe("target", target, exclude = ["output_group"])
target.data_runfiles<"runfiles"> = com.google.devtools.build.lib.analysis.Runfiles@2c9a0ae4.
target.default_runfiles<"runfiles"> = com.google.devtools.build.lib.analysis.Runfiles@2c9a0ae4.
target.files<"set"> = set([.../java/foo/libfoo.jar]).
target.files_to_run<"FilesToRunProvider"> = com.google.devtools.build.lib.analysis.FilesToRunProvider@7d624a49.
target.java<"JavaSkylarkApiProvider"> = com.google.devtools.build.lib.rules.java.JavaSkylarkApiProvider@5eda3c20.
target.label<"Label"> = //java/foo:foo.
```

`output_group` is actually a function (which we can't introspect with
our describe function, so we exclude it).  This function takes a
single string argument and returns a set,
(`target.output_group(string: name) --> set()`), probably for
accessing output groups from the target if they exist.  Not exactly
sure what this accomplishes.

### The `aspect_ctx` argument

Now let's look at the second argument, `aspect_ctx`.

```python
type(aspect_ctx)
ctx
```

```python
dir(aspect_ctx)
["action", "attr", "build_file_path", "check_placeholders", "configuration", "empty_action",
"executable", "expand", "expand_location", "expand_make_variables", "features", "file",
"file_action", "files", "fragments", "host_configuration", "host_fragments", "info_file",
"label", "middle_man", "new_file", "outputs", "resolve_command", "rule", "runfiles",
"template_action", "tokenize", "var", "version_file", "workspace_name"]
```

```python
function_names = [
    "action",
    "empty_action",
    "expand",
    "expand_location",
    "expand_make_variables",
    "middle_man",
    "file_action",
    "resolve_command",
    "runfiles",
    "template_action",
    "tokenize",
    "new_file",
    "outputs",
    "check_placeholders",
]
_describe("aspect_ctx", aspect_ctx, exclude = function_names)
Visiting //java:app.
aspect_ctx.attr<"struct"> = struct(characteristic = "annotation_processing").
aspect_ctx.build_file_path<"string"> = java/BUILD.
aspect_ctx.configuration<"configuration"> = 2ee5f82d2d3d3e70e95ce1225caf8843.
aspect_ctx.executable<"struct"> = struct().
aspect_ctx.features<"list"> = [].
aspect_ctx.file<"struct"> = struct().
aspect_ctx.files<"struct"> = struct().
aspect_ctx.fragments<"fragments"> = target: [ 'apple', 'cpp', 'java', 'jvm', 'objc'].
aspect_ctx.host_configuration<"configuration"> = 81922d9f706df1c33dcfdcc51fce58b3.
aspect_ctx.host_fragments<"fragments"> = host: [ 'apple', 'cpp', 'java', 'jvm', 'objc'].
aspect_ctx.info_file<"File"> = Artifact:[[.../stable-status.txt.
aspect_ctx.label<"Label"> = //java:app.
aspect_ctx.rule<"rule_attributes"> = com.google.devtools.build.lib.rules.SkylarkRuleContext$SkylarkRuleAttributesCollection@c53c138.
aspect_ctx.var<"dict"> = {"ABI": "local", "ABI_GLIBC_VERSION": "local", "ANDROID_CPU": "armeabi", "AR": "/usr/bin/libtool", "BINDIR": "bazel-out/local-fastbuild/bin", "CC": "external/local_config_cc/cc_wrapper.sh", "CC_FLAGS": "", "COMPILATION_MODE": "fastbuild", "CROSSTOOLTOP": "external/local_config_cc", "C_COMPILER": "compiler", "GENDIR": "bazel-out/local-fastbuild/genfiles", "GLIBC_VERSION": "macosx", "JAVA": "external/local_jdk/bin/java", "JAVABASE": "external/local_jdk", "JAVA_TRANSLATIONS": "0", "NM": "/usr/bin/nm", "OBJCOPY": "/usr/bin/objcopy", "STACK_FRAME_UNLIMITED": "", "STRIP": "/usr/bin/strip", "TARGET_CPU": "darwin"}.
aspect_ctx.version_file<"SpecialArtifact"> = Artifact:[[.../volatile-status.txt.
aspect_ctx.workspace_name<"string"> = com_github_pcj_bazel_aspect_example.
```

The functions are mostly familiar with the exception of `middle_man`, `tokenize`, and `check_placeholders`.
These don't appear to be for general use.

* `ctx.middle_man(label) -> set(artifact)`: No idea what this is for.  For example `aspect_ctx.middle_man(":host_jdk")` returns `set([Artifact:[[/...]bazel-out/host/internal]_middlemen/external_Slocal_Ujdk_Cjdk-default])`

* `ctx.tokenize(string) -> list<string>`: utility function that takes a
  string and returns a string list, split on ?spaces.

* `ctx.check_placeholders(string, list<string>) -> bool`: utility function
  that takes an input string with replacement strings like `%{name}`
  and a list of placeholder names `['name']`, and returns `True` if
  all the placeholder names are found in the input string.

## What can an aspect see?

An aspect implementation can only inspect the information provided by
the `ctx.rule` object: its attributes, dependencies (and their
providers), etc.

However, a *parameterized aspect* can get information about the
originating rule, and do different control flow based on that value.
See the examples for the difference.

# GOTCHAS

1. It's critical to propogate the transitive outputs generated by an
   aspect back up the shadow graph.  If you don't do this, you'll can
   spend a fair amount of time scratching your head about why a
   file_action in an aspect is not being actually produced (ask me how
   I know).  Recall that bazel is very lazy so if you don't keep that
   transitive chain going, bazel will prune it away.

2. To be callable from the command line, it appears necessary to
   implement 'output_groups' in your aspect.  For example
   `--output_groups=jsons` or `--output_groups=+jsons`, it will generate
   outputs specified in that output group.  You can supress outputs
   that would otherwise be generated by the rule (for java, this is a
   jar file) via `--output_groups=+jsons,-default`.

# More Information

* [Documentation about aspects](https://www.bazel.io/versions/master/docs/skylark/aspects.html).

* [Parameterized aspect design document](https://www.bazel.io/designs/skylark/parameterized-aspects.html).

* [e4b](https://github.com/bazelbuild/e4b): eclipse for bazel uses an aspect implementation.

* [Tulsi](https://github.com/bazelbuild/tulsi/blob/a7ff813b1a0c5368fd38552cb1afa1354c297c42/src/TulsiGenerator/Bazel/tulsi/tulsi_aspects.bzl). As does Tulsi.

* [intellij](https://github.com/bazelbuild/intellij): uses an aspect,
but this one implemented in Java, not Skylark.

* [AspectDescriptor.java](https://github.com/bazelbuild/bazel/blob/c484f19a2cf7427887d6e4c71c8534806e1ba83e/src/main/java/com/google/devtools/build/lib/analysis/AspectDescriptor.java).

* [Aspect.java](https://github.com/bazelbuild/bazel/blob/c484f19a2cf7427887d6e4c71c8534806e1ba83e/src/main/java/com/google/devtools/build/lib/packages/Aspect.java).

* [AspectFunction.java](https://github.com/bazelbuild/bazel/blob/bb5901ba0474eb2ddd035502663026bcb0c05b7c/src/main/java/com/google/devtools/build/lib/skyframe/AspectFunction.java).

* [SkylarkAspect.java](https://github.com/bazelbuild/bazel/blob/25b952b8fec4a3e514b4f91fbbd5e5133fcab4b7/src/main/java/com/google/devtools/build/lib/packages/SkylarkAspect.java).

* [AspectClass.java](https://github.com/bazelbuild/bazel/blob/c484f19a2cf7427887d6e4c71c8534806e1ba83e/src/main/java/com/google/devtools/build/lib/packages/AspectClass.java).  Probably the best explanation of aspects right here in the javadoc comment.

* [Undocumented flags?](https://github.com/bazelbuild/bazel/blob/c484f19a2cf7427887d6e4c71c8534806e1ba83e/scripts/release/relnotes_test.sh).
