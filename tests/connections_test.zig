// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

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

test "list connections paged" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.listConnectionsPaged(.{ .page = 1, .page_size = 10 });
    defer result.deinit();
}

test "list channels paged" {
    var client = try h.openClient();
    defer client.deinit();

    const result = try client.listChannelsPaged(.{ .page = 1, .page_size = 10 });
    defer result.deinit();
}

test "list user connections returns empty for unknown user" {
    var client = try h.openClient();
    defer client.deinit();

    const conns = try client.listUserConnections("unknown-user-zig-test");
    defer conns.deinit();
    try h.testing.expect(conns.value.len == 0);
}
