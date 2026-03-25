const std = @import("std");

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
    disk_reads: ?u64 = null,
    disk_writes: ?u64 = null,
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
};

pub const Overview = struct {
    management_version: ?[]const u8 = null,
    rates_mode: ?[]const u8 = null,
    rabbitmq_version: ?[]const u8 = null,
    product_name: ?[]const u8 = null,
    product_version: ?[]const u8 = null,
    erlang_version: ?[]const u8 = null,
    erlang_full_version: ?[]const u8 = null,
    cluster_name: ?[]const u8 = null,
    node: ?[]const u8 = null,
    message_stats: ?MessageStats = null,
    object_totals: ?ObjectTotals = null,
    queue_totals: ?QueueTotals = null,
    churn_rates: ?ChurnRates = null,
    listeners: ?[]Listener = null,
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
};

pub const NodeMemoryFootprint = struct {
    memory: ?MemoryBreakdown = null,
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
    other_ets: ?u64 = null,
    binary: ?u64 = null,
    msg_index: ?u64 = null,
    code: ?u64 = null,
    atom: ?u64 = null,
    other_system: ?u64 = null,
    allocated_unused: ?u64 = null,
    reserved_unallocated: ?u64 = null,
    total: ?std.json.Value = null,
};

//
// Connections
//

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

pub const ConnectionDetails = struct {
    name: ?[]const u8 = null,
    peer_host: ?[]const u8 = null,
    peer_port: ?u16 = null,
};

//
// Consumers
//

pub const ConsumerInfo = struct {
    consumer_tag: ?[]const u8 = null,
    channel_details: ?ConnectionDetails = null,
    queue: ?ConsumerQueue = null,
    ack_required: ?bool = null,
    exclusive: ?bool = null,
    active: ?bool = null,
    activity_status: ?[]const u8 = null,
    prefetch_count: ?u32 = null,
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
    messages: ?u64 = null,
    messages_ready: ?u64 = null,
    messages_unacknowledged: ?u64 = null,
    messages_details: ?RateDetails = null,
    messages_ready_details: ?RateDetails = null,
    messages_unacknowledged_details: ?RateDetails = null,
    consumers: ?u32 = null,
    state: ?[]const u8 = null,
    type: ?[]const u8 = null,
    policy: ?[]const u8 = null,
    arguments: ?std.json.Value = null,
    memory: ?u64 = null,
    message_bytes: ?u64 = null,
    message_bytes_ready: ?u64 = null,
    message_bytes_unacknowledged: ?u64 = null,
    message_bytes_persistent: ?u64 = null,
    message_stats: ?MessageStats = null,
    leader: ?[]const u8 = null,
    members: ?[][]const u8 = null,
    online: ?[][]const u8 = null,
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
    metadata: ?std.json.Value = null,
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
    provided_by: ?[]const u8 = null,
};

//
// Deprecated Features
//

pub const DeprecatedFeatureInfo = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    deprecation_phase: ?[]const u8 = null,
    provided_by: ?[]const u8 = null,
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
    rabbitmq_version: ?[]const u8 = null,
    product_name: ?[]const u8 = null,
    product_version: ?[]const u8 = null,
    users: ?std.json.Value = null,
    vhosts: ?std.json.Value = null,
    permissions: ?std.json.Value = null,
    topic_permissions: ?std.json.Value = null,
    parameters: ?std.json.Value = null,
    global_parameters: ?std.json.Value = null,
    policies: ?std.json.Value = null,
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
    vhost: ?[]const u8 = null,
    type: ?[]const u8 = null,
    status: ?[]const u8 = null,
    local_connection: ?[]const u8 = null,
    uri: ?[]const u8 = null,
    timestamp: ?[]const u8 = null,
    id: ?[]const u8 = null,
    @"error": ?[]const u8 = null,
};

//
// Shovels
//

pub const ShovelStatus = struct {
    name: ?[]const u8 = null,
    vhost: ?[]const u8 = null,
    type: ?[]const u8 = null,
    state: ?[]const u8 = null,
    node: ?[]const u8 = null,
    timestamp: ?[]const u8 = null,
    src_uri: ?[]const u8 = null,
    src_protocol: ?[]const u8 = null,
    dest_uri: ?[]const u8 = null,
    dest_protocol: ?[]const u8 = null,
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
    client_properties: ?std.json.Value = null,
};

pub const StreamPublisherInfo = struct {
    reference: ?[]const u8 = null,
    publisher_id: ?u32 = null,
    stream: ?[]const u8 = null,
    connection_details: ?ConnectionDetails = null,
    node: ?[]const u8 = null,
    messages_published: ?u64 = null,
    messages_confirmed: ?u64 = null,
    messages_errored: ?u64 = null,
};

pub const StreamConsumerInfo = struct {
    stream: ?[]const u8 = null,
    subscription_id: ?u32 = null,
    credits: ?u32 = null,
    connection_details: ?ConnectionDetails = null,
    node: ?[]const u8 = null,
    messages_consumed: ?u64 = null,
    offset: ?u64 = null,
    offset_lag: ?u64 = null,
    active: ?bool = null,
    activity_status: ?[]const u8 = null,
    properties: ?std.json.Value = null,
};

//
// Plugins
//

pub const PluginInfo = struct {
    name: ?[]const u8 = null,
    version: ?[]const u8 = null,
    description: ?[]const u8 = null,
    enabled: ?[]const u8 = null,
    running: ?bool = null,
    dependencies: ?[][]const u8 = null,
};

//
// OAuth Configuration
//

pub const OAuthConfiguration = struct {
    oauth_enabled: ?bool = null,
    oauth_client_id: ?[]const u8 = null,
    oauth_provider_url: ?[]const u8 = null,
};

//
// Auth Attempts
//

pub const AuthAttemptInfo = struct {
    username: ?[]const u8 = null,
    auth_mechanism: ?[]const u8 = null,
    remote_address: ?[]const u8 = null,
    protocol: ?[]const u8 = null,
    timestamp: ?u64 = null,
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
// Extensions
//

pub const ExtensionInfo = struct {
    javascript: ?[]const u8 = null,
};

//
// Schema Replication
//

pub const SchemaReplicationStatus = struct {
    status: ?[]const u8 = null,
};

//
// Error Details
//

/// The RabbitMQ API returns {"error":"...", "reason":"..."} on errors.
pub const ErrorDetails = struct {
    @"error": ?[]const u8 = null,
    reason: ?[]const u8 = null,

    pub fn message(self: ErrorDetails) ?[]const u8 {
        return self.reason orelse self.@"error";
    }
};
