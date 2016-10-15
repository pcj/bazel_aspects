app:
	bazel build java:app

app_all:
	bazel build \
	--aspects=aspects.bzl%info_aspect \
	--experimental_show_artifacts \
	--experimental_check_output_files \
	--output_groups=+default,+jsons,+protos \
	//java:app

app_jsons:
	bazel build \
	--aspects=aspects.bzl%info_aspect \
	--experimental_show_artifacts \
	--experimental_check_output_files \
	--output_groups=-default,+jsons,-protos \
	//java:app

app_protos:
	bazel build \
	--aspects=aspects.bzl%info_aspect \
	--experimental_show_artifacts \
	--output_groups=-default,-jsons,+protos \
	//java:app

java_info:
	bazel build //java:info
