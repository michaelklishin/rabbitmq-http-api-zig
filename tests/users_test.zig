const h = @import("helpers.zig");
const std = @import("std");

test "list users" {
    var client = try h.openClient();
    defer client.deinit();

    const users = try client.listUsers();
    defer users.deinit();

    try h.testing.expect(users.value.len > 0);
    var found_guest = false;
    for (users.value) |u| {
        if (std.mem.eql(u8, u.name, "guest")) found_guest = true;
    }
    try h.testing.expect(found_guest);
}

test "create, get, and delete user" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(h.test_user, true) catch {};

    try client.createUser(h.test_user, .{
        .password = "test-password-123",
        .tags = "management",
    });

    const user = try client.getUser(h.test_user);
    defer user.deinit();
    try h.testing.expectEqualStrings(h.test_user, user.value.name);

    try client.deleteUser(h.test_user, false);
}

test "create user with administrator tag" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig-test-admin-user";
    client.deleteUser(name, true) catch {};

    try client.createUser(name, .{
        .password = "admin-pass-123",
        .tags = "administrator",
    });

    const user = try client.getUser(name);
    defer user.deinit();
    try h.testing.expectEqualStrings(name, user.value.name);

    client.deleteUser(name, true) catch {};
}

test "delete user idempotently" {
    var client = try h.openClient();
    defer client.deinit();

    try client.deleteUser("nonexistent-user-zig-test", true);
}

test "get nonexistent user fails" {
    var client = try h.openClient();
    defer client.deinit();

    const result = client.getUser("nonexistent-user-zig-test");
    try h.testing.expectError(error.NotFound, result);
}

test "list users without permissions" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteUser(h.test_user, true) catch {};
    try client.createUser(h.test_user, .{ .password = "test123", .tags = "" });

    const users = try client.listUsersWithoutPermissions();
    defer users.deinit();

    var found = false;
    for (users.value) |u| {
        if (std.mem.eql(u8, u.name, h.test_user)) found = true;
    }
    try h.testing.expect(found);

    client.deleteUser(h.test_user, true) catch {};
}

test "bulk delete users" {
    var client = try h.openClient();
    defer client.deinit();

    const name1 = "zig-bulk-del-1";
    const name2 = "zig-bulk-del-2";
    client.deleteUser(name1, true) catch {};
    client.deleteUser(name2, true) catch {};

    try client.createUser(name1, .{ .password = "pass1", .tags = "" });
    try client.createUser(name2, .{ .password = "pass2", .tags = "" });

    try client.deleteUsers(.{ .users = &.{ name1, name2 } });

    try h.testing.expectError(error.NotFound, client.getUser(name1));
    try h.testing.expectError(error.NotFound, client.getUser(name2));
}

test "who am i" {
    var client = try h.openClient();
    defer client.deinit();

    const me = try client.whoAmI();
    defer me.deinit();
    try h.testing.expectEqualStrings("guest", me.value.name.?);
}

test "list users paginated" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.listUsersPaged(.{ .page = 1, .page_size = 10 });
    defer result.deinit();
    try h.testing.expect(result.value.page != null);
    try h.testing.expect(result.value.items.len > 0);
}
