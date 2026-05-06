// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;

fn exchangeRoundtripByType(p: struct { []const u8, h.api.commons.ExchangeType }) !void {
    const suffix = p[0];
    const type_enum = p[1];

    var name_buf: [128]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buf, "zig.exprop.{s}", .{suffix});

    var client = try h.openClient();
    defer client.deinit();

    client.deleteExchange("/", name, true) catch {};
    try client.declareExchange("/", name, .{ .type = type_enum.toApiString() });
    defer client.deleteExchange("/", name, true) catch {};

    const info = try client.getExchangeInfo("/", name);
    defer info.deinit();
    if (!std.mem.eql(u8, info.value.name, name)) return error.NameMismatch;
    if (info.value.type) |t| {
        if (!std.mem.eql(u8, t, type_enum.toApiString())) return error.TypeMismatch;
    }
}

test "exchange declare/get round-trips name and type for all built-in types" {
    var r = pt.Runner.initFromSeed(.{ .cases = 12, .log_failures = false }, 0xEE00);
    const types = pt.oneOf(h.api.commons.ExchangeType, .{
        .{ @as(u32, 1), pt.just(h.api.commons.ExchangeType.direct) },
        .{ @as(u32, 1), pt.just(h.api.commons.ExchangeType.fanout) },
        .{ @as(u32, 1), pt.just(h.api.commons.ExchangeType.topic) },
        .{ @as(u32, 1), pt.just(h.api.commons.ExchangeType.headers) },
    });
    const suffix = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 12);
    try r.check(testing.allocator, pt.tuple.t2(suffix, types), exchangeRoundtripByType);
}

fn deletingNonExistentExchangeIsIdempotent(suffix: []const u8) !void {
    var name_buf: [128]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buf, "zig.exprop.never.{s}", .{suffix});

    var client = try h.openClient();
    defer client.deinit();
    try client.deleteExchange("/", name, true);
}

test "deleteExchange with idempotent=true succeeds for any non-existent name" {
    var r = pt.Runner.initFromSeed(.{ .cases = 16, .log_failures = false }, 0xEE01);
    const suffix = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 16);
    try r.check(testing.allocator, suffix, deletingNonExistentExchangeIsIdempotent);
}
