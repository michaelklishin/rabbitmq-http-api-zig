// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "list stream connections" {
    var client = try h.openClient();
    defer client.deinit();

    const conns = try client.listStreamConnections();
    defer conns.deinit();
}

test "list stream publishers" {
    var client = try h.openClient();
    defer client.deinit();

    const pubs = try client.listStreamPublishers();
    defer pubs.deinit();
}

test "list stream consumers" {
    var client = try h.openClient();
    defer client.deinit();

    const consumers = try client.listStreamConsumers();
    defer consumers.deinit();
}

test "list stream publishers by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const pubs = try client.listStreamPublishersByVhost("/");
    defer pubs.deinit();
}

test "list stream consumers by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const consumers = try client.listStreamConsumersByVhost("/");
    defer consumers.deinit();
}

test "declareStreamWithArguments accepts a custom max-length-bytes" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.test.stream.with.args";
    client.deleteQueue("/", name, true) catch {};

    var args: std.json.ObjectMap = .empty;
    defer args.deinit(h.allocator);
    try args.put(h.allocator, "x-queue-type", .{ .string = "stream" });
    try args.put(h.allocator, "x-max-length-bytes", .{ .integer = 10_000_000 });

    try client.declareStreamWithArguments("/", name, .{ .object = args });

    const info = try client.getQueueInfo("/", name);
    defer info.deinit();
    if (info.value.type) |t| try h.testing.expectEqualStrings("stream", t);

    client.deleteStream("/", name, true) catch {};
}

test "list streams paginated" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.listStreamsPaged(.{ .page = 1, .page_size = 50 });
    defer result.deinit();
    for (result.value.items) |q| {
        if (q.type) |t| try h.testing.expectEqualStrings("stream", t);
    }
}

test "list stream publishers of a stream" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.test.stream.publishers.empty";
    client.deleteQueue("/", name, true) catch {};
    try client.declareStream("/", name);
    defer client.deleteStream("/", name, true) catch {};

    const pubs = try client.listStreamPublishersOfStream("/", name);
    defer pubs.deinit();
    try h.testing.expectEqual(@as(usize, 0), pubs.value.len);
}
