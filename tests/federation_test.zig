// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "list federation links" {
    var client = try h.openClient();
    defer client.deinit();

    const links = try client.listFederationLinks();
    defer links.deinit();
}

test "list federation links by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const links = try client.listFederationLinksByVhost("/");
    defer links.deinit();
}

test "list shovels" {
    var client = try h.openClient();
    defer client.deinit();

    const shovels = try client.listShovels();
    defer shovels.deinit();
}

test "list shovels by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const shovels = try client.listShovelsByVhost("/");
    defer shovels.deinit();
}

test "declare and delete typed queue federation upstream" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.test.federation.upstream";
    client.deleteFederationUpstream("/", name, true) catch {};

    try client.declareFederationUpstreamTyped("/", name, .{
        .value = .{
            .uri = "amqp://localhost",
            .@"prefetch-count" = 64,
            .queue = "src",
            .@"consumer-tag" = "tag",
        },
    });

    const upstream = try client.getFederationUpstream("/", name);
    defer upstream.deinit();
    try h.testing.expectEqualStrings(name, upstream.value.name.?);
    const value = upstream.value.value.?.object;
    try h.testing.expectEqualStrings("amqp://localhost", value.get("uri").?.string);
    try h.testing.expectEqual(@as(i64, 64), value.get("prefetch-count").?.integer);
    try h.testing.expectEqualStrings("src", value.get("queue").?.string);
    try h.testing.expectEqualStrings("tag", value.get("consumer-tag").?.string);

    try client.deleteFederationUpstream("/", name, false);
}

test "list down federation links" {
    var client = try h.openClient();
    defer client.deinit();

    const links = try client.listDownFederationLinks();
    defer links.deinit();
}

test "declare and delete amqp091 shovel via typed params" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig.test.shovel";
    client.deleteShovel("/", name, true) catch {};

    try client.declareAmqp091Shovel("/", name, h.api.requests.Amqp091ShovelParams.fromQueueToQueue(
        "amqp://localhost",
        "src.queue",
        "amqp://localhost",
        "dest.queue",
    ));

    // The runtime parameter is the source of truth for the configured URIs;
    // /shovels reflects only the running shovel which may not have started
    // (or fully reported) by the time the test runs.
    const param = try client.getRuntimeParameter("shovel", "/", name);
    defer param.deinit();
    const value = param.value.value.?.object;
    try h.testing.expectEqualStrings("amqp://localhost", value.get("src-uri").?.string);
    try h.testing.expectEqualStrings("src.queue", value.get("src-queue").?.string);
    try h.testing.expectEqualStrings("dest.queue", value.get("dest-queue").?.string);
    try h.testing.expectEqualStrings("on-confirm", value.get("ack-mode").?.string);

    try client.deleteShovel("/", name, false);
}
