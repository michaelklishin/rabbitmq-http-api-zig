// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const regex_mod = b.dependency("regex", .{
        .target = target,
        .optimize = optimize,
    }).module("regex");

    const proptest_mod = b.dependency("proptest", .{
        .target = target,
        .optimize = optimize,
    }).module("proptest");

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
            .{ .name = "proptest", .module = proptest_mod },
        },
    });
    const unit_tests = b.addTest(.{ .root_module = unit_test_mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests and property-based tests (do not require a running RabbitMQ node)");
    test_step.dependOn(&run_unit_tests.step);

    const integration_test_step = b.step("integration-test", "Run integration tests (requires RabbitMQ)");

    // Property tests that don't need a broker. Hooked into both `test` and
    // `integration-test` so they run in either context.
    const pure_prop_test_files = [_][]const u8{
        "tests/percent_encoding_prop_test.zig",
        "tests/password_hashing_prop_test.zig",
        "tests/builders_prop_test.zig",
        "tests/commons_prop_test.zig",
    };

    const broker_test_files = [_][]const u8{
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
        "tests/queues_prop_test.zig",
        "tests/users_prop_test.zig",
        "tests/virtual_hosts_prop_test.zig",
        "tests/bindings_prop_test.zig",
        "tests/exchanges_prop_test.zig",
    };

    for (pure_prop_test_files) |path| {
        const mod = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "rabbitmq_http_api_client", .module = lib_mod },
                .{ .name = "proptest", .module = proptest_mod },
            },
        });
        const t = b.addTest(.{ .root_module = mod });
        const run_t = b.addRunArtifact(t);
        test_step.dependOn(&run_t.step);
        integration_test_step.dependOn(&run_t.step);
    }

    for (broker_test_files) |path| {
        const mod = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "rabbitmq_http_api_client", .module = lib_mod },
                .{ .name = "proptest", .module = proptest_mod },
            },
        });
        const t = b.addTest(.{ .root_module = mod });
        integration_test_step.dependOn(&b.addRunArtifact(t).step);
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
