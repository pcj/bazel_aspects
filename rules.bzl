load("//:aspects.bzl", "parameterized_info_aspect")

def _java_info_impl(ctx):
    """Collect deps from our aspect."""
    outputs = depset()

    for dep in ctx.attr.deps:
        info = dep.info
        outputs = depset(transitive=[outputs, info.transitive_jsons, info.transitive_protos])

    return struct(
        files = outputs,
    )

java_info = rule(
    implementation = _java_info_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [parameterized_info_aspect],
            providers = ['java'],
        ),

        # The aspect will be able to see this. This is somewhat like
        # implementing an interface that the aspect requires.
        "characteristic": attr.string(mandatory = True),

    },
)
"""A rule that, when invoked, triggers aspect application down the
deps attribute.  It collects both the json and proto fileset into a
the files output.
"""
