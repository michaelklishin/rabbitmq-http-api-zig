// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");

// Handle cases where empty proplists are serialized by the HTTP API as an empty array instead of an empty object.
fn parseObjectToleratingTransientEmptyProplists(comptime T: type, allocator: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) !T {
    return switch (value) {
        .array, .null => T{},
        .object => |obj| blk: {
            var result: T = .{};
            inline for (std.meta.fields(T)) |field| {
                if (obj.get(field.name)) |v| {
                    @field(result, field.name) = try std.json.parseFromValueLeaky(field.type, allocator, v, options);
                }
            }
            break :blk result;
        },
        else => error.UnexpectedToken,
    };
}

//
// Generic Pagination
//

pub fn PaginatedResponse(comptime T: type) type {
    return struct {
        items: []T = &.{},
        page: ?u32 = null,
        page_count: ?u32 = null,
        page_size: ?u32 = null,
        total_count: ?u32 = null,
        filtered_count: ?u32 = null,
        item_count: ?u32 = null,
    };
}

//
// Rate Details
//

pub const RateDetails = struct {
    rate: ?f64 = null,
};

//
// Message Statistics
//

pub const MessageStats = struct {
    publish: ?u64 = null,
    publish_details: ?RateDetails = null,
    confirm: ?u64 = null,
    confirm_details: ?RateDetails = null,
    deliver: ?u64 = null,
    deliver_details: ?RateDetails = null,
    deliver_get: ?u64 = null,
    deliver_get_details: ?RateDetails = null,
    deliver_no_ack: ?u64 = null,
    deliver_no_ack_details: ?RateDetails = null,
    ack: ?u64 = null,
    ack_details: ?RateDetails = null,
    get: ?u64 = null,
    get_details: ?RateDetails = null,
    get_no_ack: ?u64 = null,
    get_empty: ?u64 = null,
    redeliver: ?u64 = null,
    redeliver_details: ?RateDetails = null,
    return_unroutable: ?u64 = null,
    return_unroutable_details: ?RateDetails = null,
    drop_unroutable: ?u64 = null,
    drop_unroutable_details: ?RateDetails = null,
    disk_reads: ?u64 = null,
    disk_writes: ?u64 = null,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        const value = try std.json.Value.jsonParse(allocator, source, options);
        return parseObjectToleratingTransientEmptyProplists(@This(), allocator, value, options);
    }

    pub fn jsonParseFromValue(allocator: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) !@This() {
        return parseObjectToleratingTransientEmptyProplists(@This(), allocator, value, options);
    }
};

//
// Overview
//

pub const ObjectTotals = struct {
    connections: ?u32 = null,
    channels: ?u32 = null,
    queues: ?u32 = null,
    exchanges: ?u32 = null,
    consumers: ?u32 = null,
};

pub const QueueTotals = struct {
    messages: ?u64 = null,
    messages_ready: ?u64 = null,
    messages_unacknowledged: ?u64 = null,
    messages_details: ?RateDetails = null,
    messages_ready_details: ?RateDetails = null,
    messages_unacknowledged_details: ?RateDetails = null,
};

pub const ChurnRates = struct {
    channel_closed: ?u64 = null,
    channel_closed_details: ?RateDetails = null,
    channel_created: ?u64 = null,
    channel_created_details: ?RateDetails = null,
    connection_closed: ?u64 = null,
    connection_closed_details: ?RateDetails = null,
    connection_created: ?u64 = null,
    connection_created_details: ?RateDetails = null,
    queue_created: ?u64 = null,
    queue_created_details: ?RateDetails = null,
    queue_declared: ?u64 = null,
    queue_declared_details: ?RateDetails = null,
    queue_deleted: ?u64 = null,
    queue_deleted_details: ?RateDetails = null,
};

pub const Listener = struct {
    node: ?[]const u8 = null,
    protocol: ?[]const u8 = null,
    ip_address: ?[]const u8 = null,
    port: ?u16 = null,
    socket_opts: ?std.json.Value = null,
    tls: ?bool = null,
};

pub const Overview = struct {
    management_version: ?[]const u8 = null,
    rates_mode: ?[]const u8 = null,
    rabbitmq_version: ?[]const u8 = null,
    product_name: ?[]const u8 = null,
    product_version: ?[]const u8 = null,
    erlang_version: ?[]const u8 = null,
    erlang_full_version: ?[]const u8 = null,
    crypto_lib_version: ?[]const u8 = null,
    cluster_name: ?[]const u8 = null,
    cluster_tags: ?std.json.Value = null,
    node: ?[]const u8 = null,
    node_tags: ?std.json.Value = null,
    disable_stats: ?bool = null,
    enable_queue_totals: ?bool = null,
    is_op_policy_updating_enabled: ?bool = null,
    default_queue_type: ?[]const u8 = null,
    statistics_db_event_queue: ?u64 = null,
    message_stats: ?MessageStats = null,
    object_totals: ?ObjectTotals = null,
    queue_totals: ?QueueTotals = null,
    churn_rates: ?ChurnRates = null,
    listeners: ?[]Listener = null,
    contexts: ?std.json.Value = null,
    exchange_types: ?std.json.Value = null,
    sample_retention_policies: ?std.json.Value = null,
};

//
// Cluster Identity
//

pub const ClusterIdentity = struct {
    name: ?[]const u8 = null,
};

//
// Nodes
//

pub const ClusterNode = struct {
    name: ?[]const u8 = null,
    type: ?[]const u8 = null,
    running: ?bool = null,
    os_pid: ?[]const u8 = null,
    mem_used: ?u64 = null,
    mem_limit: ?u64 = null,
    mem_alarm: ?bool = null,
    disk_free: ?u64 = null,
    disk_free_limit: ?u64 = null,
    disk_free_alarm: ?bool = null,
    fd_used: ?u32 = null,
    fd_total: ?u32 = null,
    sockets_used: ?u32 = null,
    sockets_total: ?u32 = null,
    proc_used: ?u32 = null,
    proc_total: ?u32 = null,
    uptime: ?u64 = null,
    run_queue: ?u32 = null,
    processors: ?u32 = null,
    io_read_count: ?u64 = null,
    io_read_bytes: ?u64 = null,
    io_write_count: ?u64 = null,
    io_write_bytes: ?u64 = null,
    rates_mode: ?[]const u8 = null,
    enabled_plugins: ?[][]const u8 = null,
    cluster_links: ?std.json.Value = null,
    db_dir: ?[]const u8 = null,
    config_files: ?std.json.Value = null,
    log_files: ?std.json.Value = null,
};

pub const NodeMemoryFootprint = struct {
    memory: ?MemoryFootprintField = null,
};

/// The /nodes/:name/memory endpoint normally returns an object, but the
/// broker occasionally returns a sentinel string (e.g. `"not_available"`)
/// when memory stats are still being collected.
pub const MemoryFootprintField = union(enum) {
    breakdown: MemoryBreakdown,
    sentinel: []const u8,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !MemoryFootprintField {
        switch (try source.peekNextTokenType()) {
            .string => {
                const tok = try source.nextAllocMax(allocator, .alloc_always, options.max_value_len.?);
                const text = switch (tok) {
                    .string, .allocated_string => |s| s,
                    else => return error.UnexpectedToken,
                };
                return .{ .sentinel = text };
            },
            .object_begin => {
                const inner = try std.json.innerParse(MemoryBreakdown, allocator, source, options);
                return .{ .breakdown = inner };
            },
            else => return error.UnexpectedToken,
        }
    }

    pub fn breakdownOrNull(self: MemoryFootprintField) ?MemoryBreakdown {
        return switch (self) {
            .breakdown => |b| b,
            .sentinel => null,
        };
    }
};

pub const MemoryBreakdown = struct {
    connection_readers: ?u64 = null,
    connection_writers: ?u64 = null,
    connection_channels: ?u64 = null,
    connection_other: ?u64 = null,
    queue_procs: ?u64 = null,
    queue_slave_procs: ?u64 = null,
    quorum_queue_procs: ?u64 = null,
    quorum_queue_dlx_procs: ?u64 = null,
    stream_queue_procs: ?u64 = null,
    stream_queue_replica_reader_procs: ?u64 = null,
    stream_queue_coordinator_procs: ?u64 = null,
    plugins: ?u64 = null,
    other_proc: ?u64 = null,
    metrics: ?u64 = null,
    mgmt_db: ?u64 = null,
    mnesia: ?u64 = null,
    quorum_ets: ?u64 = null,
    other_ets: ?u64 = null,
    binary: ?u64 = null,
    msg_index: ?u64 = null,
    code: ?u64 = null,
    atom: ?u64 = null,
    other_system: ?u64 = null,
    allocated_unused: ?u64 = null,
    reserved_unallocated: ?u64 = null,
    total: ?std.json.Value = null,
    strategy: ?[]const u8 = null,
};

//
// Connections
//

pub const ClientCapabilities = struct {
    authentication_failure_close: ?bool = null,
    @"basic.nack": ?bool = null,
    @"connection.blocked": ?bool = null,
    consumer_cancel_notify: ?bool = null,
    exchange_exchange_bindings: ?bool = null,
    publisher_confirms: ?bool = null,
};

pub const ClientProperties = struct {
    connection_name: ?[]const u8 = null,
    product: ?[]const u8 = null,
    version: ?[]const u8 = null,
    platform: ?[]const u8 = null,
    information: ?[]const u8 = null,
    capabilities: ?std.json.Value = null,
};

pub const ConnectionInfo = struct {
    name: []const u8 = "",
    node: ?[]const u8 = null,
    state: ?[]const u8 = null,
    protocol: ?[]const u8 = null,
    user: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    connected_at: ?u64 = null,
    channels: ?u16 = null,
    channel_max: ?u32 = null,
    frame_max: ?u32 = null,
    timeout: ?u32 = null,
    auth_mechanism: ?[]const u8 = null,
    host: ?[]const u8 = null,
    port: ?u16 = null,
    peer_host: ?[]const u8 = null,
    peer_port: ?u16 = null,
    ssl: ?bool = null,
    ssl_protocol: ?[]const u8 = null,
    ssl_hash: ?[]const u8 = null,
    ssl_cipher: ?[]const u8 = null,
    ssl_key_exchange: ?[]const u8 = null,
    peer_cert_subject: ?[]const u8 = null,
    peer_cert_issuer: ?[]const u8 = null,
    peer_cert_validity: ?[]const u8 = null,
    recv_oct: ?u64 = null,
    recv_cnt: ?u64 = null,
    send_oct: ?u64 = null,
    send_cnt: ?u64 = null,
    send_pend: ?u64 = null,
    client_properties: ?ClientProperties = null,
};

pub const UserConnectionInfo = struct {
    name: ?[]const u8 = null,
    user: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    node: ?[]const u8 = null,
};

pub const ConnectionDetails = struct {
    name: ?[]const u8 = null,
    peer_host: ?[]const u8 = null,
    peer_port: ?u16 = null,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        const value = try std.json.Value.jsonParse(allocator, source, options);
        return parseObjectToleratingTransientEmptyProplists(@This(), allocator, value, options);
    }

    pub fn jsonParseFromValue(allocator: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) !@This() {
        return parseObjectToleratingTransientEmptyProplists(@This(), allocator, value, options);
    }
};

//
// Channels
//

pub const ChannelInfo = struct {
    name: ?[]const u8 = null,
    node: ?[]const u8 = null,
    number: ?u32 = null,
    connection_details: ?ConnectionDetails = null,
    vhost: ?[]const u8 = null,
    user: ?[]const u8 = null,
    state: ?[]const u8 = null,
    consumer_count: ?u32 = null,
    prefetch_count: ?u32 = null,
    global_prefetch_count: ?u32 = null,
    confirm: ?bool = null,
    transactional: ?bool = null,
    messages_unacknowledged: ?u32 = null,
    messages_unconfirmed: ?u32 = null,
    messages_uncommitted: ?u32 = null,
    acks_uncommitted: ?u32 = null,
    message_stats: ?MessageStats = null,
};

//
// Consumers
//

pub const ConsumerInfo = struct {
    consumer_tag: ?[]const u8 = null,
    channel_details: ?std.json.Value = null,
    queue: ?ConsumerQueue = null,
    ack_required: ?bool = null,
    exclusive: ?bool = null,
    active: ?bool = null,
    activity_status: ?[]const u8 = null,
    prefetch_count: ?u32 = null,
    consumer_timeout: ?u64 = null,
    arguments: ?std.json.Value = null,
};

pub const ConsumerQueue = struct {
    name: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
};

//
// Queues
//

pub const QueueInfo = struct {
    name: []const u8 = "",
    vhost: ?[]const u8 = null,
    node: ?[]const u8 = null,
    durable: ?bool = null,
    exclusive: ?bool = null,
    auto_delete: ?bool = null,
    internal: ?bool = null,
    internal_owner: ?bool = null,
    messages: ?u64 = null,
    messages_ready: ?u64 = null,
    messages_unacknowledged: ?u64 = null,
    messages_details: ?RateDetails = null,
    messages_ready_details: ?RateDetails = null,
    messages_unacknowledged_details: ?RateDetails = null,
    messages_persistent: ?u64 = null,
    messages_ram: ?u64 = null,
    consumers: ?u32 = null,
    consumer_utilisation: ?f32 = null,
    consumer_capacity: ?f32 = null,
    state: ?[]const u8 = null,
    type: ?[]const u8 = null,
    policy: ?[]const u8 = null,
    operator_policy: ?[]const u8 = null,
    effective_policy_definition: ?std.json.Value = null,
    arguments: ?std.json.Value = null,
    memory: ?u64 = null,
    message_bytes: ?u64 = null,
    message_bytes_ready: ?u64 = null,
    message_bytes_unacknowledged: ?u64 = null,
    message_bytes_persistent: ?u64 = null,
    message_bytes_ram: ?u64 = null,
    message_stats: ?MessageStats = null,
    leader: ?[]const u8 = null,
    members: ?[][]const u8 = null,
    online: ?[][]const u8 = null,
    exclusive_consumer_tag: ?[]const u8 = null,
};

//
// Exchanges
//

pub const ExchangeInfo = struct {
    name: []const u8 = "",
    vhost: ?[]const u8 = null,
    type: ?[]const u8 = null,
    durable: ?bool = null,
    auto_delete: ?bool = null,
    internal: ?bool = null,
    arguments: ?std.json.Value = null,
    message_stats: ?MessageStats = null,
    policy: ?[]const u8 = null,
    user_who_performed_action: ?[]const u8 = null,
    /// Lists of bindings used by `/exchanges/:vhost/:exchange` for stats views.
    incoming: ?std.json.Value = null,
    outgoing: ?std.json.Value = null,
};

//
// Bindings
//

pub const BindingInfo = struct {
    source: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    destination: ?[]const u8 = null,
    destination_type: ?[]const u8 = null,
    routing_key: ?[]const u8 = null,
    arguments: ?std.json.Value = null,
    properties_key: ?[]const u8 = null,
};

//
// Virtual Hosts
//

pub const VhostInfo = struct {
    name: []const u8 = "",
    description: ?[]const u8 = null,
    tags: ?std.json.Value = null,
    default_queue_type: ?[]const u8 = null,
    tracing: ?bool = null,
    cluster_state: ?std.json.Value = null,
    messages: ?u64 = null,
    messages_ready: ?u64 = null,
    messages_unacknowledged: ?u64 = null,
    messages_details: ?RateDetails = null,
    messages_ready_details: ?RateDetails = null,
    messages_unacknowledged_details: ?RateDetails = null,
    recv_oct: ?u64 = null,
    recv_oct_details: ?RateDetails = null,
    send_oct: ?u64 = null,
    send_oct_details: ?RateDetails = null,
    message_stats: ?MessageStats = null,
    metadata: ?std.json.Value = null,
    protected_from_deletion: ?bool = null,
};

//
// Users
//

pub const UserInfo = struct {
    name: []const u8 = "",
    tags: ?std.json.Value = null,
    password_hash: ?[]const u8 = null,
    hashing_algorithm: ?[]const u8 = null,
    limits: ?std.json.Value = null,
};

pub const CurrentUser = struct {
    name: ?[]const u8 = null,
    tags: ?std.json.Value = null,
    is_internal_user: ?bool = null,
    auth_backend: ?[]const u8 = null,
};

//
// Permissions
//

pub const PermissionInfo = struct {
    user: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    configure: ?[]const u8 = null,
    write: ?[]const u8 = null,
    read: ?[]const u8 = null,
};

pub const TopicPermissionInfo = struct {
    user: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    exchange: ?[]const u8 = null,
    write: ?[]const u8 = null,
    read: ?[]const u8 = null,
};

//
// Policies
//

pub const PolicyInfo = struct {
    name: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    pattern: ?[]const u8 = null,
    definition: ?std.json.Value = null,
    priority: ?i32 = null,
    @"apply-to": ?[]const u8 = null,
};

//
// Feature Flags
//

pub const FeatureFlagInfo = struct {
    name: ?[]const u8 = null,
    desc: ?[]const u8 = null,
    doc_url: ?[]const u8 = null,
    state: ?[]const u8 = null,
    stability: ?[]const u8 = null,
    require_level: ?[]const u8 = null,
    experiment_level: ?[]const u8 = null,
    provided_by: ?[]const u8 = null,
};

//
// Deprecated Features
//

pub const DeprecatedFeatureInfo = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    desc: ?[]const u8 = null,
    state: ?[]const u8 = null,
    deprecation_phase: ?[]const u8 = null,
    provided_by: ?[]const u8 = null,
    doc_url: ?[]const u8 = null,
};

//
// Health Checks
//

pub const HealthCheckResult = struct {
    status: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    node: ?[]const u8 = null,
};

//
// Definitions
//

pub const DefinitionSet = struct {
    rabbit_version: ?[]const u8 = null,
    rabbitmq_version: ?[]const u8 = null,
    rabbitmq_definition_format: ?[]const u8 = null,
    original_vhost_name: ?[]const u8 = null,
    product_name: ?[]const u8 = null,
    product_version: ?[]const u8 = null,
    explanation: ?[]const u8 = null,
    description: ?[]const u8 = null,
    metadata: ?std.json.Value = null,
    users: ?std.json.Value = null,
    vhosts: ?std.json.Value = null,
    permissions: ?std.json.Value = null,
    topic_permissions: ?std.json.Value = null,
    parameters: ?std.json.Value = null,
    global_parameters: ?std.json.Value = null,
    policies: ?std.json.Value = null,
    limits: ?std.json.Value = null,
    queues: ?std.json.Value = null,
    exchanges: ?std.json.Value = null,
    bindings: ?std.json.Value = null,
};

//
// Runtime Parameters
//

pub const RuntimeParameter = struct {
    component: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    name: ?[]const u8 = null,
    value: ?std.json.Value = null,
};

pub const GlobalParameter = struct {
    name: ?[]const u8 = null,
    value: ?std.json.Value = null,
};

//
// User Limits
//

pub const UserLimitInfo = struct {
    user: ?[]const u8 = null,
    value: ?std.json.Value = null,
};

//
// Virtual Host Limits
//

pub const VhostLimitInfo = struct {
    vhost: ?[]const u8 = null,
    value: ?std.json.Value = null,
};

//
// Federation
//

pub const FederationUpstream = struct {
    component: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    name: ?[]const u8 = null,
    value: ?std.json.Value = null,
};

pub const FederationLink = struct {
    node: ?[]const u8 = null,
    queue: ?[]const u8 = null,
    exchange: ?[]const u8 = null,
    upstream: ?[]const u8 = null,
    upstream_queue: ?[]const u8 = null,
    upstream_exchange: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    type: ?[]const u8 = null,
    status: ?[]const u8 = null,
    local_connection: ?[]const u8 = null,
    uri: ?[]const u8 = null,
    timestamp: ?[]const u8 = null,
    id: ?[]const u8 = null,
    @"error": ?[]const u8 = null,
    consumer_tag: ?[]const u8 = null,
};

//
// Shovels
//

pub const ShovelStatus = struct {
    name: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    type: ?[]const u8 = null,
    state: ?[]const u8 = null,
    publishing_state: ?[]const u8 = null,
    blocked_status: ?[]const u8 = null,
    node: ?[]const u8 = null,
    timestamp: ?[]const u8 = null,
    src_uri: ?[]const u8 = null,
    src_protocol: ?[]const u8 = null,
    src_queue: ?[]const u8 = null,
    src_exchange: ?[]const u8 = null,
    src_exchange_key: ?[]const u8 = null,
    dest_uri: ?[]const u8 = null,
    dest_protocol: ?[]const u8 = null,
    dest_queue: ?[]const u8 = null,
    dest_exchange: ?[]const u8 = null,
    dest_exchange_key: ?[]const u8 = null,
    pending: ?u64 = null,
    forwarded: ?u64 = null,
    // `remaining` and `remaining_unacked` are either integers or the string
    // "unlimited", so they are typed as Value to accept both.
    remaining: ?std.json.Value = null,
    remaining_unacked: ?std.json.Value = null,
};

//
// Stream Protocol
//

pub const StreamConnectionInfo = struct {
    name: ?[]const u8 = null,
    node: ?[]const u8 = null,
    state: ?[]const u8 = null,
    user: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    host: ?[]const u8 = null,
    port: ?u16 = null,
    peer_host: ?[]const u8 = null,
    peer_port: ?u16 = null,
    connected_at: ?u64 = null,
    ssl: ?bool = null,
    frame_max: ?u32 = null,
    heartbeat: ?u32 = null,
    auth_mechanism: ?[]const u8 = null,
    client_properties: ?std.json.Value = null,
};

pub const StreamPublisherInfo = struct {
    reference: ?[]const u8 = null,
    publisher_id: ?u32 = null,
    stream: ?[]const u8 = null,
    queue: ?ConsumerQueue = null,
    connection_details: ?ConnectionDetails = null,
    node: ?[]const u8 = null,
    messages_published: ?u64 = null,
    published: ?u64 = null,
    confirmed: ?u64 = null,
    errored: ?u64 = null,
};

pub const StreamConsumerInfo = struct {
    stream: ?[]const u8 = null,
    queue: ?ConsumerQueue = null,
    subscription_id: ?u32 = null,
    credits: ?u64 = null,
    connection_details: ?ConnectionDetails = null,
    node: ?[]const u8 = null,
    messages_consumed: ?u64 = null,
    consumed: ?u64 = null,
    offset: ?u64 = null,
    offset_lag: ?u64 = null,
    active: ?bool = null,
    activity_status: ?[]const u8 = null,
    properties: ?std.json.Value = null,
};

//
// Auth Attempts
//

/// /auth/attempts/:node returns per-protocol auth statistics, not individual
/// attempt records.
pub const AuthAttemptInfo = struct {
    protocol: ?[]const u8 = null,
    auth_attempts: ?u64 = null,
    auth_attempts_failed: ?u64 = null,
    auth_attempts_succeeded: ?u64 = null,
    /// Populated only by the by-source variant.
    remote_address: ?[]const u8 = null,
    /// Populated only by the by-source variant.
    username: ?[]const u8 = null,
};

//
// Messages
//

pub const MessageInfo = struct {
    payload: ?[]const u8 = null,
    payload_bytes: ?u64 = null,
    payload_encoding: ?[]const u8 = null,
    redelivered: ?bool = null,
    exchange: ?[]const u8 = null,
    routing_key: ?[]const u8 = null,
    message_count: ?u64 = null,
    properties: ?std.json.Value = null,
};

pub const PublishResult = struct {
    routed: ?bool = null,
};

//
// Schema Replication
//

pub const SchemaReplicationStatus = struct {
    status: ?[]const u8 = null,
};

//
// Hash Password
//

pub const HashPasswordResult = struct {
    ok: ?[]const u8 = null,
};

//
// Reachability Probe
//

pub const ReachabilityProbeOutcome = struct {
    successful: bool,
};

//
// Error Details
//

/// The HTTP API returns {"error":"...", "reason":"..."} on most error responses.
pub const ErrorDetails = struct {
    @"error": ?[]const u8 = null,
    reason: ?[]const u8 = null,

    pub fn message(self: ErrorDetails) ?[]const u8 {
        return self.reason orelse self.@"error";
    }
};

//
// Tests
//

test "ChannelInfo tolerates connection_details and message_stats serialized as []" {
    const testing = std.testing;
    const json =
        \\[{"name":"x","number":1,"connection_details":[],"message_stats":[]}]
    ;
    const parsed = try std.json.parseFromSlice([]ChannelInfo, testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try testing.expect(parsed.value.len == 1);
    try testing.expect(parsed.value[0].connection_details != null);
    try testing.expect(parsed.value[0].message_stats != null);
    try testing.expect(parsed.value[0].connection_details.?.peer_host == null);
}

test "ChannelInfo accepts populated connection_details" {
    const testing = std.testing;
    const json =
        \\{"name":"x","connection_details":{"name":"c","peer_host":"h","peer_port":1234}}
    ;
    const parsed = try std.json.parseFromSlice(ChannelInfo, testing.allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try testing.expectEqualStrings("h", parsed.value.connection_details.?.peer_host.?);
    try testing.expect(parsed.value.connection_details.?.peer_port.? == 1234);
}
