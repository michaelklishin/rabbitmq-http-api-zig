const h = @import("helpers.zig");
const std = @import("std");

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

    client.deleteUser(h.test_user, true) catch {};
    client.deleteVhost(h.test_vhost, true) catch {};
    try client.createUser(h.test_user, .{ .password = "test123", .tags = "" });
    try client.createVhost(h.test_vhost, .{});

    try client.grantFullPermissions(h.test_vhost, h.test_user);

    const perm = try client.getPermissions(h.test_vhost, h.test_user);
    defer perm.deinit();
    try h.testing.expectEqualStrings(".*", perm.value.configure.?);
    try h.testing.expectEqualStrings(".*", perm.value.write.?);
    try h.testing.expectEqualStrings(".*", perm.value.read.?);

    try client.clearPermissions(h.test_vhost, h.test_user, false);

    // Verify in user permissions list
    const user_perms = try client.listPermissionsOf(h.test_user);
    defer user_perms.deinit();

    client.deleteUser(h.test_user, true) catch {};
    client.deleteVhost(h.test_vhost, true) catch {};
}

test "grant permissions with regex patterns" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(h.test_user, true) catch {};
    client.deleteVhost(h.test_vhost, true) catch {};
    try client.createUser(h.test_user, .{ .password = "test123", .tags = "" });
    try client.createVhost(h.test_vhost, .{});

    try client.grantPermissions(h.test_vhost, h.test_user, .{
        .configure = "^zig\\..*",
        .write = "^zig\\..*",
        .read = ".*",
    });

    const perm = try client.getPermissions(h.test_vhost, h.test_user);
    defer perm.deinit();
    try h.testing.expectEqualStrings("^zig\\..*", perm.value.configure.?);

    client.clearPermissions(h.test_vhost, h.test_user, true) catch {};
    client.deleteUser(h.test_user, true) catch {};
    client.deleteVhost(h.test_vhost, true) catch {};
}

test "grant, list, and clear topic permissions" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(h.test_user, true) catch {};
    client.deleteVhost(h.test_vhost, true) catch {};
    try client.createUser(h.test_user, .{ .password = "test123", .tags = "" });
    try client.createVhost(h.test_vhost, .{});
    try client.grantFullPermissions(h.test_vhost, h.test_user);

    try client.grantTopicPermissions(h.test_vhost, h.test_user, .{
        .exchange = "amq.topic",
        .write = "^zig\\.",
        .read = "^zig\\.",
    });

    const perms = try client.listTopicPermissions();
    defer perms.deinit();

    try client.clearTopicPermissions(h.test_vhost, h.test_user, false);

    client.clearPermissions(h.test_vhost, h.test_user, true) catch {};
    client.deleteUser(h.test_user, true) catch {};
    client.deleteVhost(h.test_vhost, true) catch {};
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
