// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

const test_vhost = "zig.test.vhosts.vhost";

test "list vhosts" {
    var client = try h.openClient();
    defer client.deinit();

    const vhosts = try client.listVhosts();
    defer vhosts.deinit();

    try h.testing.expect(vhosts.value.len > 0);
    var found_default = false;
    for (vhosts.value) |v| {
        if (std.mem.eql(u8, v.name, "/")) found_default = true;
    }
    try h.testing.expect(found_default);
}

test "create, get, update, and delete vhost" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteVhost(test_vhost, true) catch {};

    try client.createVhost(test_vhost, .{
        .description = "Zig integration test vhost",
    });

    const vhost = try client.getVhost(test_vhost);
    defer vhost.deinit();
    try h.testing.expectEqualStrings(test_vhost, vhost.value.name);

    try client.createVhost(test_vhost, .{
        .description = "Updated description",
    });

    try client.deleteVhost(test_vhost, false);

    const result = client.getVhost(test_vhost);
    try h.testing.expectError(error.NotFound, result);
}

test "create vhost with default queue type" {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.test.dqt.vhost";
    client.deleteVhost(vh, true) catch {};

    try client.createVhost(vh, .{
        .description = "Test vhost with DQT",
        .default_queue_type = "quorum",
    });

    const vhost = try client.getVhost(vh);
    defer vhost.deinit();
    if (vhost.value.default_queue_type) |dqt| {
        try h.testing.expectEqualStrings("quorum", dqt);
    }

    client.deleteVhost(vh, true) catch {};
}

test "delete vhost idempotently" {
    var client = try h.openClient();
    defer client.deinit();

    try client.deleteVhost("nonexistent-vhost-zig-test", true);
}

test "delete nonexistent vhost fails" {
    var client = try h.openClient();
    defer client.deinit();

    const result = client.deleteVhost("nonexistent-vhost-zig-test", false);
    try h.testing.expectError(error.NotFound, result);
}

test "virtual host deletion protection" {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.test.protected.vhost";
    client.deleteVhost(vh, true) catch {};
    try client.createVhost(vh, .{});

    try client.enableVhostDeletionProtection(vh);

    if (client.deleteVhost(vh, false)) |_| {
        return error.Unexpected;
    } else |_| {}

    try client.disableVhostDeletionProtection(vh);
    try client.deleteVhost(vh, false);
}

test "list vhosts paginated" {
    var client = try h.openClient();
    defer client.deinit();

    // Older RabbitMQ versions don't support /vhosts pagination.
    const result = client.listVhostsPaged(.{ .page = 1, .page_size = 10 }) catch return;
    defer result.deinit();
    try h.testing.expect(result.value.items.len > 0);
}

test "updateVhost is an alias for createVhost (upsert)" {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.test.update.vhost";
    client.deleteVhost(vh, true) catch {};
    try client.createVhost(vh, .{ .description = "initial" });

    try client.updateVhost(vh, .{ .description = "updated" });
    const v = try client.getVhost(vh);
    defer v.deinit();
    if (v.value.description) |d| {
        try h.testing.expectEqualStrings("updated", d);
    }

    client.deleteVhost(vh, true) catch {};
}

test "vhost with non-ASCII name round-trips" {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.test.unicode.café";
    client.deleteVhost(vh, true) catch {};
    try client.createVhost(vh, .{});

    const v = try client.getVhost(vh);
    defer v.deinit();
    try h.testing.expectEqualStrings(vh, v.value.name);

    client.deleteVhost(vh, true) catch {};
}

test "createVhost with default queue type via builder" {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.test.builder.vhost";
    client.deleteVhost(vh, true) catch {};

    const params = (h.api.requests.VirtualHostParams{})
        .withDescription("builder constructed")
        .withDefaultQueueType(.quorum);
    try client.createVhost(vh, params);

    const v = try client.getVhost(vh);
    defer v.deinit();
    if (v.value.default_queue_type) |dqt| {
        try h.testing.expectEqualStrings("quorum", dqt);
    }

    client.deleteVhost(vh, true) catch {};
}
