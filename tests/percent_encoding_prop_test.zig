// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;
const api = h.api;

fn isUnreserved(b: u8) bool {
    if (std.ascii.isAlphanumeric(b)) return true;
    return b == '-' or b == '_' or b == '.' or b == '~';
}

fn outputIsValid(input: []const u8) !void {
    const out = try api.percentEncode(testing.allocator, input);
    defer testing.allocator.free(out);

    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        if (out[i] == '%') {
            if (i + 2 >= out.len) return error.TruncatedEscape;
            if (!std.ascii.isHex(out[i + 1]) or !std.ascii.isHex(out[i + 2])) return error.InvalidEscape;
            i += 2;
        } else if (!isUnreserved(out[i])) {
            return error.InvalidByte;
        }
    }
}

test "percentEncode never emits non-unreserved bytes except as %XX" {
    var r = pt.Runner.initFromSeed(.{ .cases = 200, .log_failures = false }, 0xDEAD);
    try r.check(testing.allocator, pt.collection.bytes(0, 64), outputIsValid);
}

fn isDeterministic(input: []const u8) !void {
    const a = try api.percentEncode(testing.allocator, input);
    defer testing.allocator.free(a);
    const b = try api.percentEncode(testing.allocator, input);
    defer testing.allocator.free(b);
    if (!std.mem.eql(u8, a, b)) return error.NotDeterministic;
}

test "percentEncode is deterministic" {
    var r = pt.Runner.initFromSeed(.{ .cases = 100, .log_failures = false }, 0xBEEF);
    try r.check(testing.allocator, pt.collection.bytes(0, 32), isDeterministic);
}

fn roundTripsThroughDecoder(input: []const u8) !void {
    const out = try api.percentEncode(testing.allocator, input);
    defer testing.allocator.free(out);

    const scratch = try testing.allocator.dupe(u8, out);
    defer testing.allocator.free(scratch);

    const decoded = std.Uri.percentDecodeInPlace(scratch);
    if (!std.mem.eql(u8, input, decoded)) return error.RoundtripMismatch;
}

test "percentEncode round-trips through std.Uri.percentDecodeInPlace" {
    var r = pt.Runner.initFromSeed(.{ .cases = 200, .log_failures = false }, 0xCAFE);
    try r.check(testing.allocator, pt.collection.bytes(0, 64), roundTripsThroughDecoder);
}

fn unreservedInputIsUnchanged(input: []const u8) !void {
    const out = try api.percentEncode(testing.allocator, input);
    defer testing.allocator.free(out);
    if (!std.mem.eql(u8, input, out)) return error.UnexpectedlyEncoded;
}

test "percentEncode leaves unreserved-only input unchanged" {
    var r = pt.Runner.initFromSeed(.{ .cases = 200, .log_failures = false }, 0x5005);
    // [a-z] only: ranges like [A-z] sweep in non-unreserved punctuation.
    const alpha = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 0, 32);
    try r.check(testing.allocator, alpha, unreservedInputIsUnchanged);
}
