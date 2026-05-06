// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;
const commons = h.api.commons;

fn saltFromInt(seed_bits: i32) [4]u8 {
    const u: u32 = @bitCast(seed_bits);
    return .{
        @truncate(u),
        @truncate(u >> 8),
        @truncate(u >> 16),
        @truncate(u >> 24),
    };
}

fn sha256Deterministic(p: struct { i32, []const u8 }) !void {
    const salt = saltFromInt(p[0]);
    const a = commons.saltedPasswordHashSha256(salt, p[1]);
    const b = commons.saltedPasswordHashSha256(salt, p[1]);
    if (!std.mem.eql(u8, &a, &b)) return error.NotDeterministic;
}

test "saltedPasswordHashSha256 is deterministic across calls" {
    var r = pt.Runner.initFromSeed(.{ .cases = 100, .log_failures = false }, 0xF00D);
    const strat = pt.tuple.t2(pt.num.int(i32), pt.collection.asciiString(0, 32));
    try r.check(testing.allocator, strat, sha256Deterministic);
}

fn sha512Deterministic(p: struct { i32, []const u8 }) !void {
    const salt = saltFromInt(p[0]);
    const a = commons.saltedPasswordHashSha512(salt, p[1]);
    const b = commons.saltedPasswordHashSha512(salt, p[1]);
    if (!std.mem.eql(u8, &a, &b)) return error.NotDeterministic;
}

test "saltedPasswordHashSha512 is deterministic across calls" {
    var r = pt.Runner.initFromSeed(.{ .cases = 100, .log_failures = false }, 0xFADE);
    const strat = pt.tuple.t2(pt.num.int(i32), pt.collection.asciiString(0, 32));
    try r.check(testing.allocator, strat, sha512Deterministic);
}

fn distinctSaltsDistinctHashes(password: []const u8) !void {
    const salt_a: [4]u8 = .{ 1, 2, 3, 4 };
    const salt_b: [4]u8 = .{ 5, 6, 7, 8 };
    const a = commons.saltedPasswordHashSha256(salt_a, password);
    const b = commons.saltedPasswordHashSha256(salt_b, password);
    if (std.mem.eql(u8, &a, &b)) return error.UnexpectedCollision;
}

test "different salts produce different SHA-256 hashes" {
    var r = pt.Runner.initFromSeed(.{ .cases = 100, .log_failures = false }, 0xABCD);
    try r.check(testing.allocator, pt.collection.asciiString(0, 32), distinctSaltsDistinctHashes);
}

fn base64RoundtripsThroughSalt(password: []const u8) !void {
    const salt: [4]u8 = .{ 9, 9, 9, 9 };
    const encoded = commons.base64EncodedSaltedPasswordHashSha256(salt, password);
    var decoded: [36]u8 = undefined;
    try std.base64.standard.Decoder.decode(&decoded, &encoded);
    if (!std.mem.eql(u8, &salt, decoded[0..4])) return error.SaltMissingFromPrefix;
}

test "base64-encoded SHA-256 hash decodes back to salt-prefixed bytes" {
    var r = pt.Runner.initFromSeed(.{ .cases = 50, .log_failures = false }, 0x3330);
    try r.check(testing.allocator, pt.collection.asciiString(0, 64), base64RoundtripsThroughSalt);
}
