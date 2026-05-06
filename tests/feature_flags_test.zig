// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "list feature flags" {
    var client = try h.openClient();
    defer client.deinit();

    const flags = try client.listFeatureFlags();
    defer flags.deinit();
    try h.testing.expect(flags.value.len > 0);
}

test "enable all stable feature flags" {
    var client = try h.openClient();
    defer client.deinit();

    client.enableAllStableFeatureFlags() catch {};
}

test "list deprecated features" {
    var client = try h.openClient();
    defer client.deinit();

    const features = try client.listDeprecatedFeatures();
    defer features.deinit();
}

test "list deprecated features in use" {
    var client = try h.openClient();
    defer client.deinit();

    const features = try client.listDeprecatedFeaturesInUse();
    defer features.deinit();
}

test "enable a specific feature flag is idempotent for already-enabled flags" {
    var client = try h.openClient();
    defer client.deinit();

    const flags = try client.listFeatureFlags();
    defer flags.deinit();
    var enabled_name: ?[]const u8 = null;
    for (flags.value) |f| {
        if (f.state) |s| {
            if (std.mem.eql(u8, s, "enabled")) {
                enabled_name = f.name;
                break;
            }
        }
    }
    if (enabled_name) |name| {
        try client.enableFeatureFlag(name);
    }
}
