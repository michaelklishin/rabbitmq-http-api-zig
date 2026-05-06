// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;

fn routingKeyRoundtrips(rk: []const u8) !void {
    var client = try h.openClient();
    defer client.deinit();

    const ex = "zig.bprop.exchange";
    const q = "zig.bprop.queue";
    client.deleteQueue("/", q, true) catch {};
    client.deleteExchange("/", ex, true) catch {};
    try client.declareTopicExchange("/", ex);
    defer client.deleteExchange("/", ex, true) catch {};
    try client.declareClassicQueue("/", q);
    defer client.deleteQueue("/", q, true) catch {};

    try client.bindQueue("/", ex, q, .{ .routing_key = rk });

    const bindings = try client.listQueueBindings("/", q);
    defer bindings.deinit();
    var found = false;
    for (bindings.value) |b| {
        if (b.routing_key) |got| {
            if (std.mem.eql(u8, got, rk)) found = true;
        }
    }
    if (!found) return error.RoutingKeyMissing;
}

test "binding routing keys round-trip through list" {
    var r = pt.Runner.initFromSeed(.{ .cases = 8, .log_failures = false }, 0xB1A1);
    // Lowercase only: this exercises the client, not the broker's routing-key validator.
    const rk = pt.collection.slice(pt.num.intInRange(u8, 'a', 'z'), 1, 40);
    try r.check(testing.allocator, rk, routingKeyRoundtrips);
}
