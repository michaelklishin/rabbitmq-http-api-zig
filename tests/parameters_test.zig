const h = @import("helpers.zig");
const std = @import("std");

test "list runtime parameters" {
    var client = try h.openClient();
    defer client.deinit();

    const params = try client.listRuntimeParameters();
    defer params.deinit();
}

test "list global parameters" {
    var client = try h.openClient();
    defer client.deinit();

    const params = try client.listGlobalParameters();
    defer params.deinit();
}

test "upsert and delete global parameter" {
    var client = try h.openClient();
    defer client.deinit();

    var val = std.json.ObjectMap.init(h.allocator);
    defer val.deinit();
    try val.put("key1", .{ .string = "value1" });

    try client.upsertGlobalParameter("zig-test-global-param", .{
        .name = "zig-test-global-param",
        .value = .{ .object = val },
    });

    const param = try client.getGlobalParameter("zig-test-global-param");
    defer param.deinit();

    try client.deleteGlobalParameter("zig-test-global-param", false);
}

test "upsert and delete runtime parameter" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteVhost(h.test_vhost, true) catch {};
    try client.createVhost(h.test_vhost, .{});

    var val = std.json.ObjectMap.init(h.allocator);
    defer val.deinit();
    try val.put("uri", .{ .string = "amqp://localhost" });

    try client.upsertRuntimeParameter("federation-upstream", h.test_vhost, "zig-test-upstream", .{
        .vhost = h.test_vhost,
        .component = "federation-upstream",
        .name = "zig-test-upstream",
        .value = .{ .object = val },
    });

    const param = try client.getRuntimeParameter("federation-upstream", h.test_vhost, "zig-test-upstream");
    defer param.deinit();

    try client.deleteRuntimeParameter("federation-upstream", h.test_vhost, "zig-test-upstream", false);
    client.deleteVhost(h.test_vhost, true) catch {};
}

test "set and get cluster tags" {
    var client = try h.openClient();
    defer client.deinit();

    // Cluster tags API may not be available on all RabbitMQ versions
    client.setClusterTags("{\"environment\":\"test\"}") catch return;

    const tags = try client.getClusterTags();
    defer tags.deinit();

    try client.clearClusterTags();
}
