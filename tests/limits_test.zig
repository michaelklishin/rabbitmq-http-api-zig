// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

const test_vhost = "zig.test.limits.vhost";
const test_user = "zig-test-limits-user";

test "set and clear user limits" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(test_user, true) catch {};
    try client.createUser(test_user, .{ .password = "test123", .tags = "" });

    try client.setUserLimit(test_user, .max_connections, 10);
    try client.setUserLimit(test_user, .max_channels, 100);

    const limits = try client.listUserLimits(test_user);
    defer limits.deinit();
    var found_conn = false;
    var found_chan = false;
    for (limits.value) |l| {
        const v = l.value orelse continue;
        if (v.object.get("max-connections")) |x| {
            try h.testing.expectEqual(@as(i64, 10), x.integer);
            found_conn = true;
        }
        if (v.object.get("max-channels")) |x| {
            try h.testing.expectEqual(@as(i64, 100), x.integer);
            found_chan = true;
        }
    }
    try h.testing.expect(found_conn);
    try h.testing.expect(found_chan);

    try client.clearUserLimit(test_user, .max_connections);
    try client.clearUserLimit(test_user, .max_channels);

    client.deleteUser(test_user, true) catch {};
}

test "list all user limits" {
    var client = try h.openClient();
    defer client.deinit();

    const limits = try client.listAllUserLimits();
    defer limits.deinit();
}

test "set and clear vhost limits" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteVhost(test_vhost, true) catch {};
    try client.createVhost(test_vhost, .{});

    try client.setVhostLimit(test_vhost, .max_connections, 100);
    try client.setVhostLimit(test_vhost, .max_queues, 50);

    const limits = try client.listVhostLimits(test_vhost);
    defer limits.deinit();
    try h.testing.expect(limits.value.len > 0);
    const v = limits.value[0].value.?.object;
    try h.testing.expectEqual(@as(i64, 100), v.get("max-connections").?.integer);
    try h.testing.expectEqual(@as(i64, 50), v.get("max-queues").?.integer);

    try client.clearVhostLimit(test_vhost, .max_connections);
    try client.clearVhostLimit(test_vhost, .max_queues);

    client.deleteVhost(test_vhost, true) catch {};
}

test "list all vhost limits" {
    var client = try h.openClient();
    defer client.deinit();

    const limits = try client.listAllVhostLimits();
    defer limits.deinit();
}
