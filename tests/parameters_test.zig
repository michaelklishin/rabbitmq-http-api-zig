// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

const test_vhost = "zig.test.parameters.vhost";

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

    var val: std.json.ObjectMap = .empty;
    defer val.deinit(h.allocator);
    try val.put(h.allocator, "key1", .{ .string = "value1" });

    try client.upsertGlobalParameter("zig-test-global-param", .{
        .value = .{ .object = val },
    });

    const param = try client.getGlobalParameter("zig-test-global-param");
    defer param.deinit();

    try client.deleteGlobalParameter("zig-test-global-param", false);
}

test "upsert and delete runtime parameter" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteVhost(test_vhost, true) catch {};
    try client.createVhost(test_vhost, .{});

    var val: std.json.ObjectMap = .empty;
    defer val.deinit(h.allocator);
    try val.put(h.allocator, "uri", .{ .string = "amqp://localhost" });

    try client.upsertRuntimeParameter("federation-upstream", test_vhost, "zig-test-upstream", .{
        .value = .{ .object = val },
    });

    const param = try client.getRuntimeParameter("federation-upstream", test_vhost, "zig-test-upstream");
    defer param.deinit();

    try client.deleteRuntimeParameter("federation-upstream", test_vhost, "zig-test-upstream", false);
    client.deleteVhost(test_vhost, true) catch {};
}

test "clearAllRuntimeParametersIn removes only the matching vhost's parameters" {
    var client = try h.openClient();
    defer client.deinit();

    const a_vhost = "zig.test.clear-a";
    const b_vhost = "zig.test.clear-b";
    client.deleteVhost(a_vhost, true) catch {};
    client.deleteVhost(b_vhost, true) catch {};
    try client.createVhost(a_vhost, .{});
    try client.createVhost(b_vhost, .{});

    var v1: std.json.ObjectMap = .empty;
    defer v1.deinit(h.allocator);
    try v1.put(h.allocator, "uri", .{ .string = "amqp://x" });

    var v2: std.json.ObjectMap = .empty;
    defer v2.deinit(h.allocator);
    try v2.put(h.allocator, "uri", .{ .string = "amqp://y" });

    try client.upsertRuntimeParameter("federation-upstream", a_vhost, "u1", .{ .value = .{ .object = v1 } });
    try client.upsertRuntimeParameter("federation-upstream", b_vhost, "u2", .{ .value = .{ .object = v2 } });

    try client.clearAllRuntimeParametersIn(a_vhost);

    const a_after = try client.listRuntimeParametersByComponentInVhost("federation-upstream", a_vhost);
    defer a_after.deinit();
    try h.testing.expectEqual(@as(usize, 0), a_after.value.len);

    const b_after = try client.listRuntimeParametersByComponentInVhost("federation-upstream", b_vhost);
    defer b_after.deinit();
    try h.testing.expectEqual(@as(usize, 1), b_after.value.len);

    client.deleteVhost(a_vhost, true) catch {};
    client.deleteVhost(b_vhost, true) catch {};
}

test "set and get cluster tags" {
    var client = try h.openClient();
    defer client.deinit();

    var tags_value: std.json.ObjectMap = .empty;
    defer tags_value.deinit(h.allocator);
    try tags_value.put(h.allocator, "environment", .{ .string = "test" });

    try client.setClusterTags(.{ .object = tags_value });

    const tags = try client.getClusterTags();
    defer tags.deinit();
    try h.testing.expectEqualStrings("cluster_tags", tags.value.name.?);

    try client.clearClusterTags();
}
