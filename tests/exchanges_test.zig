// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "list exchanges" {
    var client = try h.openClient();
    defer client.deinit();

    const exchanges = try client.listExchanges();
    defer exchanges.deinit();

    try h.testing.expect(exchanges.value.len > 0);
}

test "list exchanges contains defaults" {
    var client = try h.openClient();
    defer client.deinit();

    const exchanges = try client.listExchangesByVhost("/");
    defer exchanges.deinit();

    var found_direct = false;
    var found_fanout = false;
    var found_topic = false;
    for (exchanges.value) |e| {
        if (std.mem.eql(u8, e.name, "amq.direct")) found_direct = true;
        if (std.mem.eql(u8, e.name, "amq.fanout")) found_fanout = true;
        if (std.mem.eql(u8, e.name, "amq.topic")) found_topic = true;
    }
    try h.testing.expect(found_direct);
    try h.testing.expect(found_fanout);
    try h.testing.expect(found_topic);
}

test "declare, get, and delete fanout exchange" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.fanout.exchange";
    client.deleteExchange("/", exchange_name, true) catch {};

    try client.declareFanoutExchange("/", exchange_name);

    const info = try client.getExchangeInfo("/", exchange_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(exchange_name, info.value.name);
    if (info.value.type) |t| {
        try h.testing.expectEqualStrings("fanout", t);
    }

    try client.deleteExchange("/", exchange_name, false);
}

test "declare topic exchange" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.topic.exchange";
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareTopicExchange("/", exchange_name);

    const info = try client.getExchangeInfo("/", exchange_name);
    defer info.deinit();
    if (info.value.type) |t| {
        try h.testing.expectEqualStrings("topic", t);
    }

    client.deleteExchange("/", exchange_name, true) catch {};
}

test "declare direct exchange" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.direct.exchange";
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareDirectExchange("/", exchange_name);

    const info = try client.getExchangeInfo("/", exchange_name);
    defer info.deinit();
    if (info.value.type) |t| {
        try h.testing.expectEqualStrings("direct", t);
    }

    client.deleteExchange("/", exchange_name, true) catch {};
}

test "declare headers exchange" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.headers.exchange";
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareHeadersExchange("/", exchange_name);

    const info = try client.getExchangeInfo("/", exchange_name);
    defer info.deinit();
    if (info.value.type) |t| {
        try h.testing.expectEqualStrings("headers", t);
    }

    client.deleteExchange("/", exchange_name, true) catch {};
}

test "declare exchange with arguments" {
    var client = try h.openClient();
    defer client.deinit();

    const exchange_name = "zig.test.args.exchange";
    client.deleteExchange("/", exchange_name, true) catch {};

    var args: std.json.ObjectMap = .empty;
    defer args.deinit(h.allocator);
    try args.put(h.allocator, "alternate-exchange", .{ .string = "amq.fanout" });

    try client.declareExchange("/", exchange_name, .{
        .type = "direct",
        .arguments = .{ .object = args },
    });

    const info = try client.getExchangeInfo("/", exchange_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(exchange_name, info.value.name);

    client.deleteExchange("/", exchange_name, true) catch {};
}

test "delete exchange idempotently" {
    var client = try h.openClient();
    defer client.deinit();

    try client.deleteExchange("/", "nonexistent-exchange-zig-test", true);
}

test "get nonexistent exchange fails" {
    var client = try h.openClient();
    defer client.deinit();

    const result = client.getExchangeInfo("/", "nonexistent-exchange-zig-test");
    try h.testing.expectError(error.NotFound, result);
}

test "list exchanges by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const exchanges = try client.listExchangesByVhost("/");
    defer exchanges.deinit();
    try h.testing.expect(exchanges.value.len > 0);
}

test "bulk delete exchanges" {
    var client = try h.openClient();
    defer client.deinit();

    const e1 = "zig.test.bulk.e1";
    const e2 = "zig.test.bulk.e2";
    client.deleteExchange("/", e1, true) catch {};
    client.deleteExchange("/", e2, true) catch {};

    try client.declareFanoutExchange("/", e1);
    try client.declareTopicExchange("/", e2);

    try client.deleteExchanges("/", &.{ e1, e2 }, false);

    try h.testing.expectError(error.NotFound, client.getExchangeInfo("/", e1));
    try h.testing.expectError(error.NotFound, client.getExchangeInfo("/", e2));
}

test "list exchanges paginated" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.listExchangesPaged(.{ .page = 1, .page_size = 5 });
    defer result.deinit();
    try h.testing.expect(result.value.items.len > 0);
    try h.testing.expect(result.value.page != null);
    try h.testing.expect(result.value.total_count != null);
}

test "list exchanges by vhost paginated" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.listExchangesByVhostPaged("/", .{ .page = 1, .page_size = 5 });
    defer result.deinit();
    try h.testing.expect(result.value.items.len > 0);
}
