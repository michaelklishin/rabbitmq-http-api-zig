const h = @import("helpers.zig");
const std = @import("std");

test "set and clear user limits" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(h.test_user, true) catch {};
    try client.createUser(h.test_user, .{ .password = "test123", .tags = "" });

    try client.setUserLimit(h.test_user, "max-connections", .{ .value = 10 });
    try client.setUserLimit(h.test_user, "max-channels", .{ .value = 100 });

    const limits = try client.listUserLimits(h.test_user);
    defer limits.deinit();

    try client.clearUserLimit(h.test_user, "max-connections");
    try client.clearUserLimit(h.test_user, "max-channels");

    client.deleteUser(h.test_user, true) catch {};
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

    client.deleteVhost(h.test_vhost, true) catch {};
    try client.createVhost(h.test_vhost, .{});

    try client.setVhostLimit(h.test_vhost, "max-connections", .{ .value = 100 });
    try client.setVhostLimit(h.test_vhost, "max-queues", .{ .value = 50 });

    const limits = try client.listVhostLimits(h.test_vhost);
    defer limits.deinit();

    try client.clearVhostLimit(h.test_vhost, "max-connections");
    try client.clearVhostLimit(h.test_vhost, "max-queues");

    client.deleteVhost(h.test_vhost, true) catch {};
}

test "list all vhost limits" {
    var client = try h.openClient();
    defer client.deinit();

    const limits = try client.listAllVhostLimits();
    defer limits.deinit();
}
