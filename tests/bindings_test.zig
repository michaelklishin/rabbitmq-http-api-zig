// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "list bindings" {
    var client = try h.openClient();
    defer client.deinit();

    const bindings = try client.listBindings();
    defer bindings.deinit();
}

test "bind queue to exchange and list" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.bind.exchange";
    const queue_name = "zig.test.bind.queue";

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareDirectExchange("/", exchange_name);
    try client.declareClassicQueue("/", queue_name);

    try client.bindQueue("/", exchange_name, queue_name, .{
        .routing_key = "test.key",
    });

    const bindings = try client.listQueueBindings("/", queue_name);
    defer bindings.deinit();
    try h.testing.expect(bindings.value.len > 0);

    const src_bindings = try client.listExchangeBindingsWithSource("/", exchange_name);
    defer src_bindings.deinit();
    try h.testing.expect(src_bindings.value.len > 0);

    const between = try client.listBindingsBetweenExchangeAndQueue("/", exchange_name, queue_name);
    defer between.deinit();
    try h.testing.expect(between.value.len > 0);

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
}

test "bind and list exchange-to-exchange bindings" {
    var client = try h.openClient();
    defer client.deinit();

    const src = "zig.test.e2e.source";
    const dst = "zig.test.e2e.dest";

    client.deleteExchange("/", src, true) catch {};
    client.deleteExchange("/", dst, true) catch {};
    try client.declareFanoutExchange("/", src);
    try client.declareFanoutExchange("/", dst);

    try client.bindExchange("/", src, dst, .{ .routing_key = "" });

    const bindings = try client.listExchangeBindingsBetween("/", src, dst);
    defer bindings.deinit();
    try h.testing.expect(bindings.value.len > 0);

    client.deleteExchange("/", dst, true) catch {};
    client.deleteExchange("/", src, true) catch {};
}

test "delete binding via deleteBinding using info from list" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.delbind.exchange";
    const queue_name = "zig.test.delbind.queue";

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareDirectExchange("/", exchange_name);
    try client.declareClassicQueue("/", queue_name);
    try client.bindQueue("/", exchange_name, queue_name, .{ .routing_key = "rk" });

    const before = try client.listQueueBindings("/", queue_name);
    defer before.deinit();
    var props_key: ?[]const u8 = null;
    for (before.value) |b| {
        if (b.routing_key) |rk| {
            if (std.mem.eql(u8, rk, "rk")) props_key = b.properties_key;
        }
    }
    try h.testing.expect(props_key != null);

    try client.deleteBinding(.{
        .vhost = "/",
        .source = exchange_name,
        .destination = queue_name,
        .destination_type = .queue,
        .properties_key = props_key.?,
    });

    const after = try client.listQueueBindings("/", queue_name);
    defer after.deinit();
    var still_there = false;
    for (after.value) |b| {
        if (b.routing_key) |rk| {
            if (std.mem.eql(u8, rk, "rk")) still_there = true;
        }
    }
    try h.testing.expect(!still_there);

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
}

test "recreate binding from BindingInfo" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.recreate.exchange";
    const queue_name = "zig.test.recreate.queue";

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareTopicExchange("/", exchange_name);
    try client.declareClassicQueue("/", queue_name);

    try client.bindQueue("/", exchange_name, queue_name, .{ .routing_key = "first.key" });

    const listing = try client.listQueueBindings("/", queue_name);
    defer listing.deinit();
    var info_to_recreate: ?h.api.responses.BindingInfo = null;
    var props_key: ?[]const u8 = null;
    for (listing.value) |b| {
        if (b.routing_key) |rk| {
            if (std.mem.eql(u8, rk, "first.key")) {
                info_to_recreate = b;
                props_key = b.properties_key;
            }
        }
    }
    try h.testing.expect(info_to_recreate != null);

    try client.deleteQueueBinding("/", exchange_name, queue_name, props_key.?);
    try client.recreateBinding(info_to_recreate.?);

    const after = try client.listQueueBindings("/", queue_name);
    defer after.deinit();
    var found = false;
    for (after.value) |b| {
        if (b.routing_key) |rk| {
            if (std.mem.eql(u8, rk, "first.key")) found = true;
        }
    }
    try h.testing.expect(found);

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
}
