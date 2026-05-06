// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

const test_vhost = "zig.test.permissions.vhost";
const test_user = "zig-test-permissions-user";

test "list permissions" {
    var client = try h.openClient();
    defer client.deinit();

    const perms = try client.listPermissions();
    defer perms.deinit();
    try h.testing.expect(perms.value.len > 0);
}

test "grant and clear permissions" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
    try client.createUser(test_user, .{ .password = "test123", .tags = "" });
    try client.createVhost(test_vhost, .{});

    try client.grantFullPermissions(test_vhost, test_user);

    const perm = try client.getPermissions(test_vhost, test_user);
    defer perm.deinit();
    try h.testing.expectEqualStrings(".*", perm.value.configure.?);
    try h.testing.expectEqualStrings(".*", perm.value.write.?);
    try h.testing.expectEqualStrings(".*", perm.value.read.?);

    try client.clearPermissions(test_vhost, test_user, false);

    const user_perms = try client.listPermissionsOf(test_user);
    defer user_perms.deinit();

    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
}

test "grant permissions with regex patterns" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
    try client.createUser(test_user, .{ .password = "test123", .tags = "" });
    try client.createVhost(test_vhost, .{});

    try client.grantPermissions(test_vhost, test_user, .{
        .configure = "^zig\\..*",
        .write = "^zig\\..*",
        .read = ".*",
    });

    const perm = try client.getPermissions(test_vhost, test_user);
    defer perm.deinit();
    try h.testing.expectEqualStrings("^zig\\..*", perm.value.configure.?);

    client.clearPermissions(test_vhost, test_user, true) catch {};
    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
}

test "grant, list, and clear topic permissions" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
    try client.createUser(test_user, .{ .password = "test123", .tags = "" });
    try client.createVhost(test_vhost, .{});
    try client.grantFullPermissions(test_vhost, test_user);

    try client.grantTopicPermissions(test_vhost, test_user, .{
        .exchange = "amq.topic",
        .write = "^zig\\.",
        .read = "^zig\\.",
    });

    const perms = try client.listTopicPermissions();
    defer perms.deinit();

    try client.clearTopicPermissions(test_vhost, test_user, false);

    client.clearPermissions(test_vhost, test_user, true) catch {};
    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
}

test "list topic permissions" {
    var client = try h.openClient();
    defer client.deinit();

    const perms = try client.listTopicPermissions();
    defer perms.deinit();
}

test "list permissions by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const perms = try client.listPermissionsByVhost("/");
    defer perms.deinit();
}

test "PermissionParams.readOnly grants read but not write" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
    try client.createUser(test_user, .{ .password = "p", .tags = "" });
    try client.createVhost(test_vhost, .{});

    try client.grantPermissions(test_vhost, test_user, h.api.requests.PermissionParams.readOnly());

    const perm = try client.getPermissions(test_vhost, test_user);
    defer perm.deinit();
    try h.testing.expectEqualStrings("", perm.value.configure.?);
    try h.testing.expectEqualStrings("", perm.value.write.?);
    try h.testing.expectEqualStrings(".*", perm.value.read.?);

    client.clearPermissions(test_vhost, test_user, true) catch {};
    client.deleteUser(test_user, true) catch {};
    client.deleteVhost(test_vhost, true) catch {};
}

test "list user queues" {
    var admin = try h.openClient();
    defer admin.deinit();

    const queue_name = "zig.test.user.queue";
    admin.deleteUser(test_user, true) catch {};
    admin.deleteVhost(test_vhost, true) catch {};
    try admin.createUser(test_user, h.api.requests.UserParams.management("p"));
    try admin.createVhost(test_vhost, .{});
    try admin.grantFullPermissions(test_vhost, test_user);

    // The /users/:user/queues endpoint filters by the queue's owning user,
    // which is set to the user that declared the queue. Declare it via a
    // client authenticated as `test_user` so the queue carries that user's
    // ownership; the user needs the `management` tag to access the HTTP API.
    var as_user = try h.api.Client.init(h.allocator, h.SharedIo.get(), .{
        .username = test_user,
        .password = "p",
    });
    defer as_user.deinit();
    try as_user.declareClassicQueue(test_vhost, queue_name);

    const queues = try admin.listUserQueues(test_user);
    defer queues.deinit();

    var found = false;
    for (queues.value) |q| {
        if (std.mem.eql(u8, q.name, queue_name)) found = true;
    }
    try h.testing.expect(found);

    admin.deleteQueue(test_vhost, queue_name, true) catch {};
    admin.clearPermissions(test_vhost, test_user, true) catch {};
    admin.deleteUser(test_user, true) catch {};
    admin.deleteVhost(test_vhost, true) catch {};
}
