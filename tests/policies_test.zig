const h = @import("helpers.zig");
const std = @import("std");

test "declare and delete policy" {
    var client = try h.openClient();
    defer client.deinit();

    const policy_name = "zig-test-policy";
    client.deletePolicy("/", policy_name, true) catch {};

    var definition = std.json.ObjectMap.init(h.allocator);
    defer definition.deinit();
    try definition.put("max-length", .{ .integer = 1000 });

    try client.declarePolicy("/", policy_name, .{
        .pattern = "^zig\\.test\\.",
        .definition = .{ .object = definition },
        .priority = 0,
        .@"apply-to" = "queues",
    });

    const policy = try client.getPolicy("/", policy_name);
    defer policy.deinit();
    try h.testing.expectEqualStrings(policy_name, policy.value.name.?);

    try client.deletePolicy("/", policy_name, false);
}

test "declare policy for exchanges" {
    var client = try h.openClient();
    defer client.deinit();

    const policy_name = "zig-test-exchange-policy";
    client.deletePolicy("/", policy_name, true) catch {};

    var definition = std.json.ObjectMap.init(h.allocator);
    defer definition.deinit();
    try definition.put("alternate-exchange", .{ .string = "amq.fanout" });

    try client.declarePolicy("/", policy_name, .{
        .pattern = "^zig\\.test\\.",
        .definition = .{ .object = definition },
        .@"apply-to" = "exchanges",
    });

    const policy = try client.getPolicy("/", policy_name);
    defer policy.deinit();

    client.deletePolicy("/", policy_name, true) catch {};
}

test "delete policy idempotently" {
    var client = try h.openClient();
    defer client.deinit();

    try client.deletePolicy("/", "nonexistent-policy-zig-test", true);
}

test "list policies by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const policies = try client.listPoliciesByVhost("/");
    defer policies.deinit();
}

test "list operator policies" {
    var client = try h.openClient();
    defer client.deinit();

    const policies = try client.listOperatorPolicies();
    defer policies.deinit();
}

test "list operator policies by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const policies = try client.listOperatorPoliciesByVhost("/");
    defer policies.deinit();
}

test "bulk delete policies" {
    var client = try h.openClient();
    defer client.deinit();

    const p1 = "zig-test-bulk-pol-1";
    const p2 = "zig-test-bulk-pol-2";
    client.deletePolicy("/", p1, true) catch {};
    client.deletePolicy("/", p2, true) catch {};

    var def1 = std.json.ObjectMap.init(h.allocator);
    defer def1.deinit();
    try def1.put("max-length", .{ .integer = 100 });

    var def2 = std.json.ObjectMap.init(h.allocator);
    defer def2.deinit();
    try def2.put("max-length", .{ .integer = 200 });

    try client.declarePolicies("/", &.{
        .{ .name = p1, .params = .{ .pattern = "^bulk1\\.", .definition = .{ .object = def1 } } },
        .{ .name = p2, .params = .{ .pattern = "^bulk2\\.", .definition = .{ .object = def2 } } },
    });

    const policies = try client.listPoliciesByVhost("/");
    defer policies.deinit();

    try client.deletePoliciesIn("/", &.{ p1, p2 }, false);
}

test "operator policy lifecycle" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig-test-op-policy";
    client.deleteOperatorPolicy("/", name, true) catch {};

    var def = std.json.ObjectMap.init(h.allocator);
    defer def.deinit();
    try def.put("max-length", .{ .integer = 500 });

    try client.declareOperatorPolicy("/", name, .{
        .pattern = "^zig\\.test\\.",
        .definition = .{ .object = def },
        .@"apply-to" = "queues",
    });

    const policy = try client.getOperatorPolicy("/", name);
    defer policy.deinit();

    try client.deleteOperatorPolicy("/", name, false);
}
