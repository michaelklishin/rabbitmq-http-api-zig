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
