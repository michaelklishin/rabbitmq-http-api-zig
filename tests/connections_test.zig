const h = @import("helpers.zig");
const std = @import("std");

test "list connections" {
    var client = try h.openClient();
    defer client.deinit();

    const conns = try client.listConnections();
    defer conns.deinit();
}

test "close user connections idempotently" {
    var client = try h.openClient();
    defer client.deinit();

    try client.closeUserConnections("nonexistent-user", "test", true);
}

test "list channels" {
    var client = try h.openClient();
    defer client.deinit();

    const channels = try client.listChannels();
    defer channels.deinit();
}

test "list connections by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const conns = try client.listConnectionsByVhost("/");
    defer conns.deinit();
}

test "list channels by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const channels = try client.listChannelsByVhost("/");
    defer channels.deinit();
}

test "list consumers" {
    var client = try h.openClient();
    defer client.deinit();

    const consumers = try client.listConsumers();
    defer consumers.deinit();
}

test "list consumers by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const consumers = try client.listConsumersByVhost("/");
    defer consumers.deinit();
}
