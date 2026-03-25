const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const regex_mod = b.dependency("regex", .{
        .target = target,
        .optimize = optimize,
    }).module("regex");

    const lib_mod = b.addModule("rabbitmq_http_api_client", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "regex", .module = regex_mod },
        },
    });

    const lib = b.addLibrary(.{
        .name = "rabbitmq_http_api_client",
        .root_module = lib_mod,
    });

    const unit_test_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "regex", .module = regex_mod },
        },
    });
    const unit_tests = b.addTest(.{ .root_module = unit_test_mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const integration_test_step = b.step("integration-test", "Run integration tests (requires RabbitMQ)");

    const test_files = [_][]const u8{
        "tests/overview_test.zig",
        "tests/nodes_test.zig",
        "tests/virtual_hosts_test.zig",
        "tests/users_test.zig",
        "tests/connections_test.zig",
        "tests/queues_test.zig",
        "tests/exchanges_test.zig",
        "tests/bindings_test.zig",
        "tests/permissions_test.zig",
        "tests/policies_test.zig",
        "tests/health_checks_test.zig",
        "tests/feature_flags_test.zig",
        "tests/definitions_test.zig",
        "tests/limits_test.zig",
        "tests/parameters_test.zig",
        "tests/federation_test.zig",
        "tests/streams_test.zig",
        "tests/messages_test.zig",
    };

    for (test_files) |test_file| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "rabbitmq_http_api_client", .module = lib_mod },
            },
        });
        const test_artifact = b.addTest(.{ .root_module = test_mod });
        const run_test = b.addRunArtifact(test_artifact);
        integration_test_step.dependOn(&run_test.step);
    }

    const tls_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/tls_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "rabbitmq_http_api_client", .module = lib_mod },
        },
    });
    const tls_tests = b.addTest(.{ .root_module = tls_test_mod });
    const tls_test_step = b.step("tls-test", "Run TLS integration tests (requires RabbitMQ with TLS)");
    tls_test_step.dependOn(&b.addRunArtifact(tls_tests).step);

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    }).step);
}
