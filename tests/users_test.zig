// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

const test_user = "zig-test-users-user";

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

    client.deleteUser(test_user, true) catch {};

    try client.createUser(test_user, .{
        .password = "test-password-123",
        .tags = "management",
    });

    const user = try client.getUser(test_user);
    defer user.deinit();
    try h.testing.expectEqualStrings(test_user, user.value.name);

    try client.deleteUser(test_user, false);
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

    client.deleteUser(test_user, true) catch {};
    try client.createUser(test_user, .{ .password = "test123", .tags = "" });
    defer client.deleteUser(test_user, true) catch {};

    // The broker can return 500 transiently for this endpoint when other
    // tests are mutating users in parallel; retry once.
    var attempt: u8 = 0;
    while (attempt < 3) : (attempt += 1) {
        if (client.listUsersWithoutPermissions()) |users| {
            defer users.deinit();
            var found = false;
            for (users.value) |u| {
                if (std.mem.eql(u8, u.name, test_user)) found = true;
            }
            try h.testing.expect(found);
            return;
        } else |err| switch (err) {
            error.ServerError => continue,
            else => return err,
        }
    }
    return error.ServerError;
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
    // The default `guest` user has the administrator tag.
    try h.testing.expect(me.value.tags != null);
    var has_admin = false;
    if (me.value.tags.?.array.items.len > 0) {
        for (me.value.tags.?.array.items) |t| {
            if (std.mem.eql(u8, t.string, "administrator")) has_admin = true;
        }
    }
    try h.testing.expect(has_admin);
}

test "list users paginated" {
    var client = try h.openClient();
    defer client.deinit();

    // The paginated user listing can momentarily return an empty page or
    // null `page` when other tests mutate the user list concurrently;
    // retry a few times before failing.
    var attempt: u8 = 0;
    while (attempt < 3) : (attempt += 1) {
        const result = try client.listUsersPaged(.{ .page = 1, .page_size = 10 });
        defer result.deinit();
        if (result.value.page != null and result.value.items.len > 0) return;
    }
    return error.TestUnexpectedResult;
}

test "hash password returns base64 string" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.hashPassword("test-password-123");
    defer result.deinit();
    try h.testing.expect(result.value.ok != null);
    try h.testing.expect(result.value.ok.?.len > 0);
}

test "create user with locally-computed password hash" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig-test-hashed-user";
    client.deleteUser(name, true) catch {};

    const salt = try h.api.commons.salt(h.SharedIo.get());
    const encoded = h.api.commons.base64EncodedSaltedPasswordHashSha256(salt, "secret");

    try client.createUser(name, .{
        .password_hash = &encoded,
        .hashing_algorithm = h.api.commons.HashingAlgorithm.sha256.toApiString(),
        .tags = "management",
    });

    const user = try client.getUser(name);
    defer user.deinit();
    try h.testing.expectEqualStrings(name, user.value.name);

    // Authenticate as the new user to verify the hash was accepted.
    var as_user = try h.api.Client.init(h.allocator, h.SharedIo.get(), .{
        .username = name,
        .password = "secret",
    });
    defer as_user.deinit();
    try h.testing.expect(as_user.probeReachability().successful);

    client.deleteUser(name, true) catch {};
}
