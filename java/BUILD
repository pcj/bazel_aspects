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
    name = "annotation_processing",
    deps = ["app"],
    characteristic = 'annotation_processing',
)

java_info(
    name = "compilation_info",
    deps = ["app"],
    characteristic = 'compilation_info',
)
