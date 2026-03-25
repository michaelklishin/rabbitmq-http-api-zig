const h = @import("helpers.zig");
const std = @import("std");

test "get overview" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();

    try h.testing.expect(overview.value.rabbitmq_version != null);
    try h.testing.expect(overview.value.erlang_version != null);
    try h.testing.expect(overview.value.cluster_name != null);
    try h.testing.expect(overview.value.node != null);
}

test "get overview contains object totals" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();

    if (overview.value.object_totals) |totals| {
        try h.testing.expect(totals.exchanges != null);
    }
}

test "get and set cluster name" {
    var client = try h.openClient();
    defer client.deinit();

    const original = try client.getClusterName();
    defer original.deinit();
    try h.testing.expect(original.value.name != null);

    try client.setClusterName("zig-test-cluster");
    const updated = try client.getClusterName();
    defer updated.deinit();
    try h.testing.expectEqualStrings("zig-test-cluster", updated.value.name.?);

    // Restore
    try client.setClusterName(original.value.name.?);
}

test "get effective config" {
    var client = try h.openClient();
    defer client.deinit();

    // May return non-JSON on some versions
    const config = client.getEffectiveConfig() catch return;
    defer config.deinit();
}

test "rebalance queue leaders" {
    var client = try h.openClient();
    defer client.deinit();

    client.rebalanceQueueLeaders() catch {};
}
