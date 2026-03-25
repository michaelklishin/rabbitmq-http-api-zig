const std = @import("std");

//
// Pagination
//

pub const PaginationParams = struct {
    page: u32 = 1,
    page_size: u32 = 100,
};

//
// Queue Declaration
//

pub const QueueParams = struct {
    durable: bool = true,
    auto_delete: bool = false,
    arguments: ?std.json.Value = null,
    node: ?[]const u8 = null,
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
};

//
// Virtual Host
//

pub const VirtualHostParams = struct {
    description: ?[]const u8 = null,
    tags: ?std.json.Value = null,
    default_queue_type: ?[]const u8 = null,
    tracing: ?bool = null,
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
};

//
// Permissions
//

pub const PermissionParams = struct {
    configure: []const u8 = "",
    write: []const u8 = "",
    read: []const u8 = "",
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

pub const RuntimeParameterParams = struct {
    vhost: []const u8,
    component: []const u8,
    name: []const u8,
    value: std.json.Value,
};

pub const GlobalParameterParams = struct {
    name: []const u8,
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

//
// Shovel
//

pub const ShovelParams = struct {
    value: std.json.Value,
};

pub const Amqp091ShovelParams = struct {
    src_uri: []const u8,
    src_queue: ?[]const u8 = null,
    src_exchange: ?[]const u8 = null,
    src_exchange_key: ?[]const u8 = null,
    dest_uri: []const u8,
    dest_queue: ?[]const u8 = null,
    dest_exchange: ?[]const u8 = null,
    dest_exchange_key: ?[]const u8 = null,
    ack_mode: []const u8 = "on-confirm",
    prefetch_count: ?u32 = null,
    reconnect_delay: ?u32 = null,
};

pub const Amqp10ShovelParams = struct {
    src_uri: []const u8,
    src_address: []const u8,
    dest_uri: []const u8,
    dest_address: []const u8,
    ack_mode: []const u8 = "on-confirm",
    reconnect_delay: ?u32 = null,
};

//
// Binding Deletion
//

pub const BindingDeletionParams = struct {
    vhost: []const u8,
    source: []const u8,
    destination: []const u8,
    destination_type: @import("commons.zig").BindingDestinationType,
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
