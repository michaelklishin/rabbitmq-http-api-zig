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

    // Get message back
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
