def _visit_java_provider(target, aspect_ctx):

    """Dump selective info about a visited java_library or java_binary rule into a file"""
    java_provider = target.java

    param = getattr(aspect_ctx.attr, "java_provider_property", "compilation_info")
    if "compilation_info" == param:
        prop = java_provider.compilation_info
        data = struct(
            boot_classpath = [file.path for file in prop.boot_classpath],
            compilation_classpath = [file.path for file in prop.compilation_classpath],
            javac_options = prop.javac_options,
            originating_rule = aspect_ctx.label.name,
        )
    elif "annotation_processing" == param:
        prop = java_provider.annotation_processing
        data = struct(
            enabled = prop.enabled,
            processor_classnames = prop.processor_classnames,
            originating_rule = aspect_ctx.label.name,
        )

    json_file = aspect_ctx.new_file('%s.%s.json' % (target.label.name, param))
    proto_file = aspect_ctx.new_file('%s.%s.proto' % (target.label.name, param))

    aspect_ctx.file_action(json_file, data.to_json())
    aspect_ctx.file_action(proto_file, data.to_proto())

    return [json_file, proto_file]


def _info_aspect_impl(target, aspect_ctx):
    """
    Visit nodes in a shadow graph reachable by 'deps'.

    Args:
      target (struct): the target rule.
      aspect_ctx (struct): the aspect context.
    Returns:
      (struct):
        .info (struct): info provider
        .output_groups (dict{}): file outputs, partitioned by filetype.
"""
    print("Visiting %s" % target.label)

    jsons = []
    protos = []

    kind = aspect_ctx.rule.kind
    if kind == 'java_library' or kind == 'java_binary':
        json, proto = _visit_java_provider(target, aspect_ctx)
        jsons.append(json)
        protos.append(proto)
    else:
        fail("I don't know how to interpret this kind of rule: " + kind, "deps")

    # This is critically important to propogate outputs back up the
    # shadow graph!
    transitive_jsons = set(jsons)
    transitive_protos = set(protos)

    for dep in aspect_ctx.rule.attr.deps:
        info = dep.info
        transitive_jsons = transitive_jsons | info.transitive_jsons
        transitive_protos = transitive_protos | info.transitive_protos

    return struct(
        info = struct(
            jsons = jsons,
            transitive_jsons = transitive_jsons,
            transitive_protos = transitive_protos,
        ),
        output_groups = {
            "jsons": transitive_jsons,
            "protos": transitive_protos,
        },
    )

info_aspect = aspect(
    implementation = _info_aspect_impl,
    attr_aspects = ["deps"],
)
"""Defines an aspect that propogates down the dependency tree along
edges named 'deps'. This can be called on the command line or from
java_info rule.
"""

parameterized_info_aspect = aspect(
    implementation = _info_aspect_impl,
    attr_aspects = ["deps"],
    # Attributes that the originating rule *MUST* have (see java_info.bzl).
    attrs = {
        # MUST be a string and MUST have a predefined set of values.
        "java_provider_property": attr.string(
            values = ["compilation_info", "annotation_processing"],
        ),
    }
)
"""Defines an aspect that propogates down the dependency tree along
edges named 'deps' and requires the calling rule to have a
'java_proovider_property'.  This cannot be called on the command line
because java_binary does not have this attribute.
"""
