// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const commons = @import("commons.zig");

//
// Pagination
//

pub const PaginationParams = struct {
    page: u32 = 1,
    page_size: u32 = commons.default_page_size,

    pub fn firstPage() PaginationParams {
        return .{};
    }

    pub fn firstPageOf(page_size: u32) PaginationParams {
        return .{ .page = 1, .page_size = page_size };
    }
};

//
// Queue Declaration
//

// Note: the management HTTP API rejects exclusive queue declarations because
// exclusive queues require an owning connection identity, which HTTP requests
// do not have. Declare them over AMQP instead.
pub const QueueParams = struct {
    durable: bool = true,
    auto_delete: bool = false,
    arguments: ?std.json.Value = null,
    node: ?[]const u8 = null,

    pub fn newDurableClassicQueue() QueueParams {
        return .{ .durable = true, .auto_delete = false };
    }

    pub fn newTransientAutodelete() QueueParams {
        return .{ .durable = false, .auto_delete = true };
    }
};

//
// Exchange Declaration
//

pub const ExchangeParams = struct {
    type: []const u8 = "direct",
    durable: bool = true,
    auto_delete: bool = false,
    internal: bool = false,
    arguments: ?std.json.Value = null,

    pub fn durableDirect() ExchangeParams {
        return .{ .type = "direct" };
    }

    pub fn fanout() ExchangeParams {
        return .{ .type = "fanout", .durable = false };
    }

    pub fn durableFanout() ExchangeParams {
        return .{ .type = "fanout" };
    }

    pub fn topic() ExchangeParams {
        return .{ .type = "topic", .durable = false };
    }

    pub fn durableTopic() ExchangeParams {
        return .{ .type = "topic" };
    }

    pub fn headers() ExchangeParams {
        return .{ .type = "headers", .durable = false };
    }

    pub fn durableHeaders() ExchangeParams {
        return .{ .type = "headers" };
    }

    pub fn ofType(t: commons.ExchangeType) ExchangeParams {
        return .{ .type = t.toApiString() };
    }
};

//
// Virtual Host
//

pub const VirtualHostParams = struct {
    description: ?[]const u8 = null,
    tags: ?std.json.Value = null,
    default_queue_type: ?[]const u8 = null,
    tracing: ?bool = null,

    pub fn withDescription(self: VirtualHostParams, description: []const u8) VirtualHostParams {
        var out = self;
        out.description = description;
        return out;
    }

    pub fn withDefaultQueueType(self: VirtualHostParams, qt: commons.QueueType) VirtualHostParams {
        var out = self;
        out.default_queue_type = qt.toApiString();
        return out;
    }

    pub fn withTracing(self: VirtualHostParams, enabled: bool) VirtualHostParams {
        var out = self;
        out.tracing = enabled;
        return out;
    }
};

//
// User
//

pub const UserParams = struct {
    password: ?[]const u8 = null,
    password_hash: ?[]const u8 = null,
    hashing_algorithm: ?[]const u8 = null,
    tags: []const u8 = "",

    pub fn administrator(password: []const u8) UserParams {
        return .{ .password = password, .tags = "administrator" };
    }

    pub fn monitoring(password: []const u8) UserParams {
        return .{ .password = password, .tags = "monitoring" };
    }

    pub fn management(password: []const u8) UserParams {
        return .{ .password = password, .tags = "management" };
    }

    pub fn policymaker(password: []const u8) UserParams {
        return .{ .password = password, .tags = "policymaker" };
    }

    pub fn withoutTags(password: []const u8) UserParams {
        return .{ .password = password, .tags = "" };
    }
};

//
// Permissions
//

pub const PermissionParams = struct {
    configure: []const u8 = "",
    write: []const u8 = "",
    read: []const u8 = "",

    pub fn fullAccess() PermissionParams {
        return .{ .configure = ".*", .write = ".*", .read = ".*" };
    }

    pub fn readOnly() PermissionParams {
        return .{ .configure = "", .write = "", .read = ".*" };
    }

    pub fn noAccess() PermissionParams {
        return .{};
    }
};

pub const TopicPermissionParams = struct {
    exchange: []const u8 = "",
    write: []const u8 = "",
    read: []const u8 = "",
};

//
// Policies
//

pub const PolicyParams = struct {
    pattern: []const u8,
    definition: std.json.Value,
    priority: i32 = 0,
    @"apply-to": []const u8 = "all",

    pub fn newForQueues(pattern: []const u8, definition: std.json.Value) PolicyParams {
        return .{ .pattern = pattern, .definition = definition, .@"apply-to" = "queues" };
    }

    pub fn newForTarget(pattern: []const u8, definition: std.json.Value, target: commons.PolicyTarget) PolicyParams {
        return .{ .pattern = pattern, .definition = definition, .@"apply-to" = target.toApiString() };
    }
};

pub const NamedPolicyParams = struct {
    name: []const u8,
    params: PolicyParams,
};

//
// Bindings
//

pub const BindingParams = struct {
    routing_key: []const u8 = "",
    arguments: ?std.json.Value = null,
};

//
// Runtime Parameters
//

/// The broker reads the parameter's name, vhost, and component from the URL,
/// not the body, so only the value is required here.
pub const RuntimeParameterParams = struct {
    value: std.json.Value,
};

pub const GlobalParameterParams = struct {
    value: std.json.Value,
};

//
// Limits
//

pub const LimitParams = struct {
    value: i64,
};

//
// Federation Upstream
//

pub const FederationUpstreamParams = struct {
    value: std.json.Value,
};

// Federation runtime parameter values use hyphenated keys on the wire.
pub const TypedFederationUpstreamValue = struct {
    uri: []const u8,
    @"prefetch-count": u32 = 1000,
    @"reconnect-delay": u32 = 5,
    @"trust-user-id": bool = false,
    @"ack-mode": []const u8 = "on-confirm",
    @"bind-nowait": bool = false,
    @"channel-use-mode": []const u8 = "multiple",

    queue: ?[]const u8 = null,
    @"consumer-tag": ?[]const u8 = null,

    exchange: ?[]const u8 = null,
    @"max-hops": ?u8 = null,
    @"queue-type": ?[]const u8 = null,
    expires: ?u32 = null,
    @"message-ttl": ?u32 = null,
    @"resource-cleanup-mode": ?[]const u8 = null,
};

pub const TypedFederationUpstreamParams = struct {
    value: TypedFederationUpstreamValue,
};

//
// Shovel
//

pub const ShovelParams = struct {
    value: std.json.Value,
};

// The shovel runtime parameter uses hyphenated keys (e.g. "src-uri") instead
// of the underscore convention used elsewhere in the management API.
pub const Amqp091ShovelParams = struct {
    @"src-uri": []const u8,
    @"src-queue": ?[]const u8 = null,
    @"src-exchange": ?[]const u8 = null,
    @"src-exchange-key": ?[]const u8 = null,
    @"src-predeclared": ?bool = null,
    @"dest-uri": []const u8,
    @"dest-queue": ?[]const u8 = null,
    @"dest-exchange": ?[]const u8 = null,
    @"dest-exchange-key": ?[]const u8 = null,
    @"dest-predeclared": ?bool = null,
    @"ack-mode": []const u8 = "on-confirm",
    @"prefetch-count": ?u32 = null,
    @"reconnect-delay": ?u32 = null,

    pub fn fromQueueToQueue(src_uri: []const u8, src_queue: []const u8, dest_uri: []const u8, dest_queue: []const u8) Amqp091ShovelParams {
        return .{
            .@"src-uri" = src_uri,
            .@"src-queue" = src_queue,
            .@"dest-uri" = dest_uri,
            .@"dest-queue" = dest_queue,
        };
    }

    pub fn fromExchangeToQueue(src_uri: []const u8, src_exchange: []const u8, src_exchange_key: ?[]const u8, dest_uri: []const u8, dest_queue: []const u8) Amqp091ShovelParams {
        return .{
            .@"src-uri" = src_uri,
            .@"src-exchange" = src_exchange,
            .@"src-exchange-key" = src_exchange_key,
            .@"dest-uri" = dest_uri,
            .@"dest-queue" = dest_queue,
        };
    }
};

pub const Amqp10ShovelParams = struct {
    @"src-uri": []const u8,
    @"src-address": []const u8,
    @"dest-uri": []const u8,
    @"dest-address": []const u8,
    @"ack-mode": []const u8 = "on-confirm",
    @"reconnect-delay": ?u32 = null,
};

//
// Binding Deletion
//

pub const BindingDeletionParams = struct {
    vhost: []const u8,
    source: []const u8,
    destination: []const u8,
    destination_type: commons.BindingDestinationType,
    properties_key: []const u8,
};

//
// Messages
//

pub const PublishMessageParams = struct {
    properties: ?std.json.Value = null,
    routing_key: []const u8 = "",
    payload: []const u8 = "",
    payload_encoding: []const u8 = "string",
};

pub const GetMessagesParams = struct {
    count: u32 = 1,
    ackmode: []const u8 = "ack_requeue_true",
    encoding: []const u8 = "auto",
};

//
// Bulk User Delete
//

pub const BulkUserDeleteParams = struct {
    users: []const []const u8,
};

//
// Cluster Identity
//

pub const ClusterNameParams = struct {
    name: []const u8,
};

//
// Unit Tests
//

const testing = std.testing;

test "QueueParams.newDurableClassicQueue" {
    const p = QueueParams.newDurableClassicQueue();
    try testing.expect(p.durable);
    try testing.expect(!p.auto_delete);
}

test "QueueParams.newTransientAutodelete" {
    const p = QueueParams.newTransientAutodelete();
    try testing.expect(!p.durable);
    try testing.expect(p.auto_delete);
}

test "ExchangeParams.fanout default is non-durable" {
    const p = ExchangeParams.fanout();
    try testing.expectEqualStrings("fanout", p.type);
    try testing.expect(!p.durable);
}

test "ExchangeParams.durableFanout" {
    const p = ExchangeParams.durableFanout();
    try testing.expectEqualStrings("fanout", p.type);
    try testing.expect(p.durable);
}

test "ExchangeParams.ofType maps enum to wire type" {
    try testing.expectEqualStrings("x-consistent-hash", ExchangeParams.ofType(.consistent_hashing).type);
    try testing.expectEqualStrings("x-local-random", ExchangeParams.ofType(.local_random).type);
}

test "PermissionParams.fullAccess uses regex .*" {
    const p = PermissionParams.fullAccess();
    try testing.expectEqualStrings(".*", p.configure);
    try testing.expectEqualStrings(".*", p.write);
    try testing.expectEqualStrings(".*", p.read);
}

test "PermissionParams.readOnly grants read only" {
    const p = PermissionParams.readOnly();
    try testing.expectEqualStrings("", p.configure);
    try testing.expectEqualStrings("", p.write);
    try testing.expectEqualStrings(".*", p.read);
}

test "UserParams role helpers set tags" {
    try testing.expectEqualStrings("administrator", UserParams.administrator("p").tags);
    try testing.expectEqualStrings("monitoring", UserParams.monitoring("p").tags);
    try testing.expectEqualStrings("management", UserParams.management("p").tags);
    try testing.expectEqualStrings("policymaker", UserParams.policymaker("p").tags);
    try testing.expectEqualStrings("", UserParams.withoutTags("p").tags);
}

test "PolicyParams.newForTarget uses target's wire string" {
    const def: std.json.Value = .{ .object = .empty };
    const p = PolicyParams.newForTarget("^z\\.", def, .quorum_queues);
    try testing.expectEqualStrings("quorum_queues", p.@"apply-to");
}

test "PaginationParams.firstPageOf" {
    const p = PaginationParams.firstPageOf(50);
    try testing.expectEqual(@as(u32, 1), p.page);
    try testing.expectEqual(@as(u32, 50), p.page_size);
}

test "Amqp091ShovelParams.fromQueueToQueue" {
    const p = Amqp091ShovelParams.fromQueueToQueue("amqp://a", "src", "amqp://b", "dst");
    try testing.expectEqualStrings("amqp://a", p.@"src-uri");
    try testing.expectEqualStrings("src", p.@"src-queue".?);
    try testing.expectEqualStrings("dst", p.@"dest-queue".?);
    try testing.expectEqualStrings("on-confirm", p.@"ack-mode");
}

test "TypedFederationUpstreamValue serializes hyphenated keys" {
    const v = TypedFederationUpstreamValue{
        .uri = "amqp://upstream",
        .@"prefetch-count" = 256,
        .@"reconnect-delay" = 10,
        .queue = "src-queue",
        .@"consumer-tag" = "tag-1",
    };
    const json = try std.json.Stringify.valueAlloc(testing.allocator, v, .{ .emit_null_optional_fields = false });
    defer testing.allocator.free(json);
    try testing.expect(std.mem.indexOf(u8, json, "\"prefetch-count\":256") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"reconnect-delay\":10") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"consumer-tag\":\"tag-1\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"ack-mode\":\"on-confirm\"") != null);
}

test "Amqp091ShovelParams serializes hyphenated keys" {
    const p = Amqp091ShovelParams.fromQueueToQueue("amqp://a", "src", "amqp://b", "dst");
    const json = try std.json.Stringify.valueAlloc(testing.allocator, p, .{ .emit_null_optional_fields = false });
    defer testing.allocator.free(json);
    try testing.expect(std.mem.indexOf(u8, json, "\"src-uri\":\"amqp://a\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"dest-queue\":\"dst\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"ack-mode\":\"on-confirm\"") != null);
}
