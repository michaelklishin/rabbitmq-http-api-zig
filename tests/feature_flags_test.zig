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

    // May return an error on some RabbitMQ versions where all flags are already enabled
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
