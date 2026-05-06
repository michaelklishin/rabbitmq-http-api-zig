// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;
const builders = h.api.builders;

fn xArgsMaxLengthRoundtrips(value: i64) !void {
    var b = builders.XArgumentsBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.maxLength(value);
    const v = try b.build();
    const stored = v.object.get("x-max-length") orelse return error.KeyMissing;
    if (stored.integer != value) return error.WrongValue;
}

test "XArgumentsBuilder.maxLength stores its argument verbatim" {
    var r = pt.Runner.initFromSeed(.{ .cases = 200, .log_failures = false }, 0x5555);
    try r.check(testing.allocator, pt.num.int(i64), xArgsMaxLengthRoundtrips);
}

fn xArgsMessageTtlRoundtrips(value: i64) !void {
    var b = builders.XArgumentsBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.messageTtl(value);
    const v = try b.build();
    const stored = v.object.get("x-message-ttl") orelse return error.KeyMissing;
    if (stored.integer != value) return error.WrongValue;
}

test "XArgumentsBuilder.messageTtl stores its argument verbatim" {
    var r = pt.Runner.initFromSeed(.{ .cases = 200, .log_failures = false }, 0x6666);
    try r.check(testing.allocator, pt.num.int(i64), xArgsMessageTtlRoundtrips);
}

fn xArgsTwoCallsTwoEntries(p: struct { i64, i64 }) !void {
    var b = builders.XArgumentsBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.maxLength(p[0]).messageTtl(p[1]);
    const v = try b.build();
    if (v.object.count() != 2) return error.WrongEntryCount;
}

test "XArgumentsBuilder records each chained call as a distinct entry" {
    var r = pt.Runner.initFromSeed(.{ .cases = 100, .log_failures = false }, 0x7777);
    try r.check(testing.allocator, pt.tuple.t2(pt.num.int(i64), pt.num.int(i64)), xArgsTwoCallsTwoEntries);
}

fn xArgsLastWriteWins(p: struct { i64, i64 }) !void {
    var b = builders.XArgumentsBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.maxLength(p[0]).maxLength(p[1]);
    const v = try b.build();
    const stored = v.object.get("x-max-length") orelse return error.KeyMissing;
    if (stored.integer != p[1]) return error.LastWriteIgnored;
}

test "XArgumentsBuilder later calls overwrite earlier same-key calls" {
    var r = pt.Runner.initFromSeed(.{ .cases = 100, .log_failures = false }, 0x8888);
    try r.check(testing.allocator, pt.tuple.t2(pt.num.int(i64), pt.num.int(i64)), xArgsLastWriteWins);
}

fn policyDefMaxLengthRoundtrips(value: i64) !void {
    var b = builders.PolicyDefinitionBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.maxLength(value);
    const v = try b.build();
    const stored = v.object.get("max-length") orelse return error.KeyMissing;
    if (stored.integer != value) return error.WrongValue;
}

test "PolicyDefinitionBuilder.maxLength uses the unprefixed key" {
    var r = pt.Runner.initFromSeed(.{ .cases = 100, .log_failures = false }, 0x9999);
    try r.check(testing.allocator, pt.num.int(i64), policyDefMaxLengthRoundtrips);
}
