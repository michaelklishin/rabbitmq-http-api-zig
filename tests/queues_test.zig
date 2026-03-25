const h = @import("helpers.zig");
const std = @import("std");

test "declare, get, and delete classic queue" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.classic.queue";
    client.deleteQueue("/", queue_name, true) catch {};

    try client.declareClassicQueue("/", queue_name);

    const info = try client.getQueueInfo("/", queue_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(queue_name, info.value.name);
    try h.testing.expect(info.value.durable orelse false);

    try client.deleteQueue("/", queue_name, false);
}

test "declare and redeclare classic queue" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.redeclare.queue";
    client.deleteQueue("/", queue_name, true) catch {};

    try client.declareClassicQueue("/", queue_name);
    // Redeclare should be idempotent
    try client.declareClassicQueue("/", queue_name);

    client.deleteQueue("/", queue_name, true) catch {};
}

test "declare quorum queue" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.quorum.queue";
    client.deleteQueue("/", queue_name, true) catch {};

    try client.declareQuorumQueue("/", queue_name);

    const info = try client.getQueueInfo("/", queue_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(queue_name, info.value.name);
    if (info.value.type) |t| {
        try h.testing.expectEqualStrings("quorum", t);
    }

    client.deleteQueue("/", queue_name, true) catch {};
}

test "declare stream" {
    var client = try h.openClient();
    defer client.deinit();

    const stream_name = "zig.test.stream";
    client.deleteQueue("/", stream_name, true) catch {};

    try client.declareStream("/", stream_name);

    const info = try client.getQueueInfo("/", stream_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(stream_name, info.value.name);
    if (info.value.type) |t| {
        try h.testing.expectEqualStrings("stream", t);
    }

    client.deleteQueue("/", stream_name, true) catch {};
}

test "declare transient auto-delete queue" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.transient.queue";
    client.deleteQueue("/", queue_name, true) catch {};

    try client.declareQueue("/", queue_name, .{
        .durable = false,
        .auto_delete = true,
    });

    const info = try client.getQueueInfo("/", queue_name);
    defer info.deinit();
    try h.testing.expect(!(info.value.durable orelse true));
    try h.testing.expect(info.value.auto_delete orelse false);

    client.deleteQueue("/", queue_name, true) catch {};
}

test "declare queue with arguments" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.args.queue";
    client.deleteQueue("/", queue_name, true) catch {};

    try client.declareQueue("/", queue_name, .{
        .durable = true,
        .arguments = .{ .object = blk: {
            var map = std.json.ObjectMap.init(h.allocator);
            map.put("x-max-length", .{ .integer = 500 }) catch unreachable;
            map.put("x-message-ttl", .{ .integer = 60000 }) catch unreachable;
            break :blk map;
        } },
    });

    const info = try client.getQueueInfo("/", queue_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(queue_name, info.value.name);

    client.deleteQueue("/", queue_name, true) catch {};
}

test "list queues" {
    var client = try h.openClient();
    defer client.deinit();

    const queues = try client.listQueues();
    defer queues.deinit();
}

test "list queues by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const queues = try client.listQueuesByVhost("/");
    defer queues.deinit();
}

test "purge queue" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.purge.queue";
    client.deleteQueue("/", queue_name, true) catch {};
    try client.declareClassicQueue("/", queue_name);

    try client.purgeQueue("/", queue_name);

    client.deleteQueue("/", queue_name, true) catch {};
}

test "delete queue idempotently" {
    var client = try h.openClient();
    defer client.deinit();

    try client.deleteQueue("/", "nonexistent-queue-zig-test", true);
}

test "delete nonexistent queue fails" {
    var client = try h.openClient();
    defer client.deinit();

    const result = client.deleteQueue("/", "nonexistent-queue-zig-test", false);
    try h.testing.expectError(error.NotFound, result);
}

test "get nonexistent queue fails" {
    var client = try h.openClient();
    defer client.deinit();

    const result = client.getQueueInfo("/", "nonexistent-queue-zig-test");
    try h.testing.expectError(error.NotFound, result);
}

test "bulk delete queues" {
    var client = try h.openClient();
    defer client.deinit();

    const q1 = "zig.test.bulk.q1";
    const q2 = "zig.test.bulk.q2";
    client.deleteQueue("/", q1, true) catch {};
    client.deleteQueue("/", q2, true) catch {};

    try client.declareClassicQueue("/", q1);
    try client.declareClassicQueue("/", q2);

    try client.deleteQueues("/", &.{ q1, q2 }, false);

    try h.testing.expectError(error.NotFound, client.getQueueInfo("/", q1));
    try h.testing.expectError(error.NotFound, client.getQueueInfo("/", q2));
}

test "declare and delete stream via queue API" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.test.stream.lifecycle";
    client.deleteQueue("/", name, true) catch {};

    try client.declareStream("/", name);

    const info = try client.getQueueInfo("/", name);
    defer info.deinit();
    try h.testing.expectEqualStrings(name, info.value.name);

    try client.deleteQueue("/", name, false);
}

test "list queues with details" {
    var client = try h.openClient();
    defer client.deinit();

    // May fail on older RabbitMQ, just verify callable
    _ = client.listQueuesWithDetails() catch |err| switch (err) {
        error.NotFound, error.BadRequest => return,
        else => return err,
    };
}

test "list queues paginated" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.listQueuesPaged(.{ .page = 1, .page_size = 10 });
    defer result.deinit();
    try h.testing.expect(result.value.page != null);
}

test "list classic queues" {
    var client = try h.openClient();
    defer client.deinit();

    const queues = try client.listClassicQueues();
    defer queues.deinit();
}

test "list quorum queues" {
    var client = try h.openClient();
    defer client.deinit();

    const queues = try client.listQuorumQueues();
    defer queues.deinit();
}

test "list streams" {
    var client = try h.openClient();
    defer client.deinit();

    const queues = try client.listStreams();
    defer queues.deinit();
}
