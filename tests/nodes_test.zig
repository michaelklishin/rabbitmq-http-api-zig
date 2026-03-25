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
