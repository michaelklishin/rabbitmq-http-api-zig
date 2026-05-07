// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

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
    // Restore the original name even if a later assertion fails.
    defer client.setClusterName(original.value.name.?) catch {};

    const updated = try client.getClusterName();
    defer updated.deinit();
    try h.testing.expectEqualStrings("zig-test-cluster", updated.value.name.?);
}

test "rebalance queue leaders" {
    var client = try h.openClient();
    defer client.deinit();

    client.rebalanceQueueLeaders() catch {};
}

test "server version returns a non-empty string" {
    // /version endpoint requires RabbitMQ 4.x
    if (!try h.rabbitmqVersionIsAtLeast(4, 0, 0)) return;

    var client = try h.openClient();
    defer client.deinit();

    const v = try client.serverVersion();
    defer h.allocator.free(v);
    try h.testing.expect(v.len > 0);
}

test "reachability probe succeeds against a healthy broker" {
    var client = try h.openClient();
    defer client.deinit();

    const outcome = client.probeReachability();
    try h.testing.expect(outcome.successful);
}

test "aliveness test on default vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const ok = try client.alivenessTest("/");
    try h.testing.expect(ok);
}
