// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;

fn classicQueueRoundtrip(suffix: []const u8) !void {
    var name_buf: [128]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buf, "zig.qprop.{s}", .{suffix});

    var client = try h.openClient();
    defer client.deinit();

    client.deleteQueue("/", name, true) catch {};
    try client.declareClassicQueue("/", name);
    defer client.deleteQueue("/", name, true) catch {};

    const info = try client.getQueueInfo("/", name);
    defer info.deinit();
    if (!std.mem.eql(u8, info.value.name, name)) return error.NameMismatch;
    if (!(info.value.durable orelse false)) return error.NotDurable;
}

test "classic queue lifecycle preserves the name" {
    // Each case is a network round-trip so we keep the count modest.
    var r = pt.Runner.initFromSeed(.{ .cases = 12, .log_failures = false }, 0x9999);
    const suffix = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 12);
    try r.check(testing.allocator, suffix, classicQueueRoundtrip);
}

fn quorumQueueIsAlwaysDurable(suffix: []const u8) !void {
    var name_buf: [128]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buf, "zig.qqprop.{s}", .{suffix});

    var client = try h.openClient();
    defer client.deinit();

    client.deleteQueue("/", name, true) catch {};
    try client.declareQuorumQueue("/", name);
    defer client.deleteQueue("/", name, true) catch {};

    const info = try client.getQueueInfo("/", name);
    defer info.deinit();
    if (!(info.value.durable orelse false)) return error.NotDurable;
    if (info.value.type) |t| {
        if (!std.mem.eql(u8, t, "quorum")) return error.WrongType;
    }
}

test "quorum queue is always durable, type=quorum" {
    var r = pt.Runner.initFromSeed(.{ .cases = 8, .log_failures = false }, 0xAAAA);
    const suffix = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 10);
    try r.check(testing.allocator, suffix, quorumQueueIsAlwaysDurable);
}

fn deletingNonExistentQueueIsIdempotent(suffix: []const u8) !void {
    var name_buf: [128]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buf, "zig.qprop.never.{s}", .{suffix});

    var client = try h.openClient();
    defer client.deinit();
    try client.deleteQueue("/", name, true);
}

test "deleteQueue with idempotent=true succeeds on any non-existent name" {
    var r = pt.Runner.initFromSeed(.{ .cases = 16, .log_failures = false }, 0xBBBB);
    const suffix = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 16);
    try r.check(testing.allocator, suffix, deletingNonExistentQueueIsIdempotent);
}
