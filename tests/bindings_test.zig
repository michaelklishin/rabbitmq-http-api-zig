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

    // Verify via queue bindings
    const bindings = try client.listQueueBindings("/", queue_name);
    defer bindings.deinit();
    try h.testing.expect(bindings.value.len > 0);

    // Verify via exchange source bindings
    const src_bindings = try client.listExchangeBindingsWithSource("/", exchange_name);
    defer src_bindings.deinit();
    try h.testing.expect(src_bindings.value.len > 0);

    // Verify bindings between
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
