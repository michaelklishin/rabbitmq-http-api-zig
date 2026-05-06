// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

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

test "declare queue with arguments" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.args.queue";
    client.deleteQueue("/", queue_name, true) catch {};

    var args: std.json.ObjectMap = .empty;
    defer args.deinit(h.allocator);
    try args.put(h.allocator, "x-max-length", .{ .integer = 500 });
    try args.put(h.allocator, "x-message-ttl", .{ .integer = 60000 });

    try client.declareQueue("/", queue_name, .{
        .durable = true,
        .arguments = .{ .object = args },
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

    // The /queues/detailed endpoint requires RabbitMQ 3.13 or later.
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

test "listQueuesOfType filters by enum" {
    var client = try h.openClient();
    defer client.deinit();

    const queues = try client.listQueuesOfType(.classic);
    defer queues.deinit();
    for (queues.value) |q| {
        if (q.type) |t| try h.testing.expectEqualStrings("classic", t);
    }
}

test "quorum queue status returns Raft state" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.test.qq.status";
    client.deleteQueue("/", name, true) catch {};
    try client.declareQuorumQueue("/", name);

    const status = try client.getQuorumQueueStatus("/", name);
    defer status.deinit();
    // The endpoint returns an array of per-replica records; we just verify
    // that something parsable came back.
    try h.testing.expect(status.value == .array);
    try h.testing.expect(status.value.array.items.len > 0);

    client.deleteQueue("/", name, true) catch {};
}

test "getStreamInfo and deleteStream are queue-info aliases" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.test.stream.alias";
    client.deleteStream("/", name, true) catch {};

    try client.declareStream("/", name);
    const info = try client.getStreamInfo("/", name);
    defer info.deinit();
    try h.testing.expectEqualStrings(name, info.value.name);

    try client.deleteStream("/", name, false);
}
