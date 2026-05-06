// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "publish and get message" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.message.queue";
    const exchange_name = "zig.test.message.exchange";
    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareFanoutExchange("/", exchange_name);
    try client.declareClassicQueue("/", queue_name);
    try client.bindQueue("/", exchange_name, queue_name, .{});

    const pub_result = try client.publishMessage("/", exchange_name, .{
        .routing_key = "",
        .payload = "hello from zig",
        .payload_encoding = "string",
    });
    defer pub_result.deinit();
    try h.testing.expect(pub_result.value.routed orelse false);

    const messages = try client.getMessages("/", queue_name, .{
        .count = 1,
        .ackmode = "ack_requeue_false",
        .encoding = "auto",
    });
    defer messages.deinit();
    try h.testing.expect(messages.value.len > 0);
    if (messages.value[0].payload) |payload| {
        try h.testing.expectEqualStrings("hello from zig", payload);
    }

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
}

test "purge queue removes messages" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.purge.message.queue";
    const exchange_name = "zig.test.purge.message.exchange";
    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
    try client.declareFanoutExchange("/", exchange_name);
    try client.declareClassicQueue("/", queue_name);
    try client.bindQueue("/", exchange_name, queue_name, .{});

    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        const r = try client.publishMessage("/", exchange_name, .{
            .payload = "msg",
            .payload_encoding = "string",
        });
        r.deinit();
    }

    try client.purgeQueue("/", queue_name);

    const empty = try client.getMessages("/", queue_name, .{
        .count = 1,
        .ackmode = "ack_requeue_false",
        .encoding = "auto",
    });
    defer empty.deinit();
    try h.testing.expectEqual(@as(usize, 0), empty.value.len);

    client.deleteQueue("/", queue_name, true) catch {};
    client.deleteExchange("/", exchange_name, true) catch {};
}
