load("//:rules.bzl", "java_info")

java_binary(
    name = "app",
    srcs = ["App.java"],
    main_class = "App",
    deps = ["//java/foo", "//java/bar"],
)

java_library(
    name = "foo",
    srcs = ["Foo.java"],
)

java_library(
    name = "bar",
    srcs = ["Bar.java"],
)

java_info(
    name = "info",
    deps = ["app"],
    #java_provider_property = 'compilation_info',
    java_provider_property = 'annotation_processing',
)
