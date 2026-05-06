// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;

fn userLifecycleWithTag(tag: []const u8) !void {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.uprop.scratch";
    client.deleteUser(name, true) catch {};

    try client.createUser(name, .{ .password = "p", .tags = tag });
    defer client.deleteUser(name, true) catch {};

    const u = try client.getUser(name);
    defer u.deinit();
    if (!std.mem.eql(u8, u.value.name, name)) return error.NameMismatch;
}

test "user creation with each non-administrator tag" {
    var r = pt.Runner.initFromSeed(.{ .cases = 8, .log_failures = false }, 0xBEE);
    const tags = pt.oneOf([]const u8, .{
        .{ @as(u32, 1), pt.just(@as([]const u8, "")) },
        .{ @as(u32, 1), pt.just(@as([]const u8, "monitoring")) },
        .{ @as(u32, 1), pt.just(@as([]const u8, "management")) },
        .{ @as(u32, 1), pt.just(@as([]const u8, "policymaker")) },
    });
    try r.check(testing.allocator, tags, userLifecycleWithTag);
}

fn deleteNonexistentUserIsIdempotent(suffix: []const u8) !void {
    var name_buf: [128]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buf, "zig.uprop.never.{s}", .{suffix});

    var client = try h.openClient();
    defer client.deinit();
    try client.deleteUser(name, true);
}

test "deleteUser with idempotent=true succeeds for any non-existent name" {
    var r = pt.Runner.initFromSeed(.{ .cases = 16, .log_failures = false }, 0xCAB);
    const suffix = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 16);
    try r.check(testing.allocator, suffix, deleteNonexistentUserIsIdempotent);
}

fn passwordHashRoundtripsToCreatedUser(password_seed: i32) !void {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.uprop.hashed";
    client.deleteUser(name, true) catch {};

    // Stable password derived from the seed so a failure reproduces deterministically.
    var pw_buf: [16]u8 = undefined;
    const pw = std.fmt.bufPrint(&pw_buf, "p-{x}", .{@as(u32, @bitCast(password_seed))}) catch unreachable;

    const salt: [4]u8 = .{ 1, 2, 3, 4 };
    const encoded = h.api.commons.base64EncodedSaltedPasswordHashSha256(salt, pw);

    try client.createUser(name, .{
        .password_hash = &encoded,
        .hashing_algorithm = h.api.commons.HashingAlgorithm.sha256.toApiString(),
        .tags = "management",
    });
    defer client.deleteUser(name, true) catch {};

    var as_user = try h.api.Client.init(h.allocator, h.SharedIo.get(), .{
        .username = name,
        .password = pw,
    });
    defer as_user.deinit();
    if (!as_user.probeReachability().successful) return error.AuthFailed;
}

test "locally-computed password hash authenticates against the broker" {
    var r = pt.Runner.initFromSeed(.{ .cases = 4, .log_failures = false }, 0xD0D);
    try r.check(testing.allocator, pt.num.int(i32), passwordHashRoundtripsToCreatedUser);
}
