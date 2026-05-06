// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "list nodes" {
    var client = try h.openClient();
    defer client.deinit();

    const nodes = try client.listNodes();
    defer nodes.deinit();

    try h.testing.expect(nodes.value.len > 0);
    try h.testing.expect(nodes.value[0].name != null);
    try h.testing.expect(nodes.value[0].running orelse false);
}

test "get node info" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    const node_name = overview.value.node.?;

    const node = try client.getNodeInfo(node_name);
    defer node.deinit();
    try h.testing.expect(node.value.running orelse false);
    try h.testing.expect(node.value.uptime != null);
    try h.testing.expect(node.value.processors != null);
}

test "get node memory footprint" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    const node_name = overview.value.node.?;

    const mem = try client.getNodeMemoryFootprint(node_name);
    defer mem.deinit();
    try h.testing.expect(mem.value.memory != null);
    // The broker reports either a breakdown object or a sentinel string
    // (e.g. "not_available") when stats are still being collected.
    switch (mem.value.memory.?) {
        .breakdown => {},
        .sentinel => {},
    }
}

test "node info includes enabled plugins" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    const node_name = overview.value.node.?;

    const node = try client.getNodeInfo(node_name);
    defer node.deinit();
    try h.testing.expect(node.value.enabled_plugins != null);
    try h.testing.expect(node.value.enabled_plugins.?.len > 0);
}

test "list plugins for one node" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    const node_name = overview.value.node.?;

    const plugins = try client.listNodePlugins(node_name);
    defer plugins.deinit();
    try h.testing.expect(plugins.value.len > 0);
}

test "get node memory footprint relative" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    const node_name = overview.value.node.?;

    const mem = try client.getNodeMemoryFootprintRelative(node_name);
    defer mem.deinit();
    try h.testing.expect(mem.value == .object);
}

test "get authentication attempts" {
    var client = try h.openClient();
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    const node_name = overview.value.node.?;

    const attempts = try client.getAuthAttempts(node_name);
    defer attempts.deinit();
    var found_protocol = false;
    for (attempts.value) |a| {
        if (a.protocol != null) found_protocol = true;
    }
    try h.testing.expect(found_protocol);
}

test "list all cluster plugins is sorted and deduplicated" {
    var client = try h.openClient();
    defer client.deinit();

    const plugins = try client.listAllClusterPlugins();
    defer plugins.deinit();
    try h.testing.expect(plugins.value.len > 0);

    var prev: ?[]const u8 = null;
    for (plugins.value) |p| {
        if (prev) |pv| try h.testing.expect(std.mem.lessThan(u8, pv, p));
        prev = p;
    }
}
