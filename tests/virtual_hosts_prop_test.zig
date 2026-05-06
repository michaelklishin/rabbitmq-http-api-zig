// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;

fn vhostDescriptionRoundtrip(description: []const u8) !void {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.vhprop.scratch";
    client.deleteVhost(vh, true) catch {};

    try client.createVhost(vh, .{ .description = description });
    defer client.deleteVhost(vh, true) catch {};

    const v = try client.getVhost(vh);
    defer v.deinit();
    if (!std.mem.eql(u8, v.value.name, vh)) return error.NameMismatch;
    if (v.value.description) |d| {
        if (!std.mem.eql(u8, d, description)) return error.DescriptionMismatch;
    } else if (description.len > 0) {
        return error.DescriptionMissing;
    }
}

test "vhost description round-trips through create/get" {
    var r = pt.Runner.initFromSeed(.{ .cases = 8, .log_failures = false }, 0xACE);
    try r.check(testing.allocator, pt.collection.asciiString(0, 80), vhostDescriptionRoundtrip);
}

fn vhostDefaultQueueTypeRoundtrip(qt: h.api.commons.QueueType) !void {
    var client = try h.openClient();
    defer client.deinit();
    const vh = "zig.vhprop.dqt";
    client.deleteVhost(vh, true) catch {};
    try client.createVhost(vh, .{ .default_queue_type = qt.toApiString() });
    defer client.deleteVhost(vh, true) catch {};

    const v = try client.getVhost(vh);
    defer v.deinit();
    if (v.value.default_queue_type) |got| {
        if (!std.mem.eql(u8, got, qt.toApiString())) return error.DefaultQueueTypeMismatch;
    }
}

test "vhost default_queue_type round-trips through create/get" {
    var r = pt.Runner.initFromSeed(.{ .cases = 6, .log_failures = false }, 0xBED);
    const qt_strategy = pt.oneOf(h.api.commons.QueueType, .{
        .{ @as(u32, 1), pt.just(h.api.commons.QueueType.classic) },
        .{ @as(u32, 1), pt.just(h.api.commons.QueueType.quorum) },
        .{ @as(u32, 1), pt.just(h.api.commons.QueueType.stream) },
    });
    try r.check(testing.allocator, qt_strategy, vhostDefaultQueueTypeRoundtrip);
}

fn deleteNonexistentVhostIsIdempotent(suffix: []const u8) !void {
    var name_buf: [128]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buf, "zig.vhprop.never.{s}", .{suffix});

    var client = try h.openClient();
    defer client.deinit();
    try client.deleteVhost(name, true);
}

test "deleteVhost with idempotent=true succeeds for any non-existent name" {
    var r = pt.Runner.initFromSeed(.{ .cases = 16, .log_failures = false }, 0xFAE);
    const suffix = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 16);
    try r.check(testing.allocator, suffix, deleteNonexistentVhostIsIdempotent);
}
