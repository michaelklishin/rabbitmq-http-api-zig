// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");

test "declare and delete policy" {
    var client = try h.openClient();
    defer client.deinit();

    const policy_name = "zig-test-policy";
    client.deletePolicy("/", policy_name, true) catch {};

    var definition: std.json.ObjectMap = .empty;
    defer definition.deinit(h.allocator);
    try definition.put(h.allocator, "max-length", .{ .integer = 1000 });

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

    var definition: std.json.ObjectMap = .empty;
    defer definition.deinit(h.allocator);
    try definition.put(h.allocator, "alternate-exchange", .{ .string = "amq.fanout" });

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

    var def1: std.json.ObjectMap = .empty;
    defer def1.deinit(h.allocator);
    try def1.put(h.allocator, "max-length", .{ .integer = 100 });

    var def2: std.json.ObjectMap = .empty;
    defer def2.deinit(h.allocator);
    try def2.put(h.allocator, "max-length", .{ .integer = 200 });

    try client.declarePolicies("/", &.{
        .{ .name = p1, .params = .{ .pattern = "^bulk1\\.", .definition = .{ .object = def1 } } },
        .{ .name = p2, .params = .{ .pattern = "^bulk2\\.", .definition = .{ .object = def2 } } },
    });

    const policies = try client.listPoliciesByVhost("/");
    defer policies.deinit();

    try client.deletePoliciesIn("/", &.{ p1, p2 }, false);
}

test "list policies for target filters by apply-to" {
    var client = try h.openClient();
    defer client.deinit();

    const p_q = "zig-test-target-q";
    const p_e = "zig-test-target-e";
    client.deletePolicy("/", p_q, true) catch {};
    client.deletePolicy("/", p_e, true) catch {};

    var def: std.json.ObjectMap = .empty;
    defer def.deinit(h.allocator);
    try def.put(h.allocator, "max-length", .{ .integer = 100 });

    try client.declarePolicy("/", p_q, .{ .pattern = "^q\\.", .definition = .{ .object = def }, .@"apply-to" = "queues" });
    try client.declarePolicy("/", p_e, .{ .pattern = "^e\\.", .definition = .{ .object = def }, .@"apply-to" = "exchanges" });

    const for_queues = try client.listPoliciesForTarget("/", .queues);
    defer for_queues.deinit();
    var saw_q = false;
    var saw_e = false;
    for (for_queues.value) |p| {
        if (p.name) |n| {
            if (std.mem.eql(u8, n, p_q)) saw_q = true;
            if (std.mem.eql(u8, n, p_e)) saw_e = true;
        }
    }
    try h.testing.expect(saw_q);
    try h.testing.expect(!saw_e);

    client.deletePolicy("/", p_q, true) catch {};
    client.deletePolicy("/", p_e, true) catch {};
}

test "list matching policies uses regex pattern" {
    var client = try h.openClient();
    defer client.deinit();

    const p = "zig-test-matching";
    client.deletePolicy("/", p, true) catch {};

    var def: std.json.ObjectMap = .empty;
    defer def.deinit(h.allocator);
    try def.put(h.allocator, "max-length", .{ .integer = 50 });

    try client.declarePolicy("/", p, .{ .pattern = "^logs\\.", .definition = .{ .object = def }, .@"apply-to" = "queues" });

    const matching = try client.listMatchingPolicies("/", "logs.app", .queues);
    defer matching.deinit();
    var saw_it = false;
    for (matching.value) |x| {
        if (x.name) |n| {
            if (std.mem.eql(u8, n, p)) saw_it = true;
        }
    }
    try h.testing.expect(saw_it);

    client.deletePolicy("/", p, true) catch {};
}

test "operator policy lifecycle" {
    var client = try h.openClient();
    defer client.deinit();

    const name = "zig-test-op-policy";
    client.deleteOperatorPolicy("/", name, true) catch {};

    var def: std.json.ObjectMap = .empty;
    defer def.deinit(h.allocator);
    try def.put(h.allocator, "max-length", .{ .integer = 500 });

    try client.declareOperatorPolicy("/", name, .{
        .pattern = "^zig\\.test\\.",
        .definition = .{ .object = def },
        .@"apply-to" = "queues",
    });

    const policy = try client.getOperatorPolicy("/", name);
    defer policy.deinit();

    try client.deleteOperatorPolicy("/", name, false);
}
