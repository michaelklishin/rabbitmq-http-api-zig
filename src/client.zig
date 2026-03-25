const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;
const responses = @import("responses.zig");
const requests = @import("requests.zig");
const commons = @import("commons.zig");

pub const ClientError = error{
    HttpRequestFailed,
    JsonParseFailed,
    NotFound,
    Unauthorized,
    ServerError,
    BadRequest,
    OutOfMemory,
    Unexpected,
};

pub const ClientOptions = struct {
    endpoint: []const u8 = "http://localhost:15672/api",
    username: []const u8 = "guest",
    password: []const u8 = "guest",
    /// Absolute path to a PEM CA certificate file for TLS verification.
    /// When set, the certificate is loaded and used to verify the server.
    /// Required for self-signed certificates (e.g. from tls-gen).
    ca_cert_file: ?[]const u8 = null,
};

pub const Client = struct {
    allocator: Allocator,
    options: ClientOptions,
    auth_header: []const u8,
    http_client: http.Client,

    pub fn init(allocator: Allocator, io: std.Io, options: ClientOptions) !Client {
        const credentials = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ options.username, options.password });
        defer allocator.free(credentials);
        const encoded = try allocator.alloc(u8, std.base64.standard.Encoder.calcSize(credentials.len));
        defer allocator.free(encoded);
        _ = std.base64.standard.Encoder.encode(encoded, credentials);
        const header = try std.fmt.allocPrint(allocator, "Basic {s}", .{encoded});

        var client = Client{
            .allocator = allocator,
            .options = options,
            .auth_header = header,
            .http_client = .{ .allocator = allocator, .io = io },
        };

        if (options.ca_cert_file) |ca_path| {
            // Set now so the http.Client uses our ca_bundle instead of rescanning system certs
            const now = std.Io.Clock.real.now(io);
            client.http_client.now = now;
            client.http_client.ca_bundle.addCertsFromFilePathAbsolute(
                allocator,
                io,
                now,
                ca_path,
            ) catch return error.HttpRequestFailed;
        }

        return client;
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
        self.allocator.free(self.auth_header);
    }

    //
    // Overview & Cluster
    //

    pub fn getOverview(self: *Client) !std.json.Parsed(responses.Overview) {
        return self.getJson(responses.Overview, "/overview");
    }

    pub fn getClusterName(self: *Client) !std.json.Parsed(responses.ClusterIdentity) {
        return self.getJson(responses.ClusterIdentity, "/cluster-name");
    }

    pub fn setClusterName(self: *Client, name: []const u8) !void {
        try self.putJson("/cluster-name", requests.ClusterNameParams{ .name = name });
    }

    pub fn getClusterTags(self: *Client) !std.json.Parsed(std.json.Value) {
        return self.getJson(std.json.Value, "/cluster/tags");
    }

    pub fn setClusterTags(self: *Client, tags_json: []const u8) !void {
        try self.httpSend(.PUT, "/cluster/tags", tags_json);
    }

    pub fn clearClusterTags(self: *Client) !void {
        try self.httpSend(.PUT, "/cluster/tags", "{}");
    }

    //
    // Nodes
    //

    pub fn listNodes(self: *Client) !std.json.Parsed([]responses.ClusterNode) {
        return self.getJson([]responses.ClusterNode, "/nodes");
    }

    pub fn getNodeInfo(self: *Client, name: []const u8) !std.json.Parsed(responses.ClusterNode) {
        const path = try self.encodePath1("/nodes", name);
        defer self.allocator.free(path);
        return self.getJson(responses.ClusterNode, path);
    }

    pub fn getNodeMemoryFootprint(self: *Client, name: []const u8) !std.json.Parsed(responses.NodeMemoryFootprint) {
        const enc = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/nodes/{s}/memory", .{enc});
        defer self.allocator.free(path);
        return self.getJson(responses.NodeMemoryFootprint, path);
    }

    //
    // Virtual Hosts
    //

    pub fn listVhosts(self: *Client) !std.json.Parsed([]responses.VhostInfo) {
        return self.getJson([]responses.VhostInfo, "/vhosts");
    }

    pub fn listVhostsPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.VhostInfo)) {
        const path = try self.paginatedPath("/vhosts", params);
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.VhostInfo), path);
    }

    pub fn getVhost(self: *Client, name: []const u8) !std.json.Parsed(responses.VhostInfo) {
        const path = try self.encodePath1("/vhosts", name);
        defer self.allocator.free(path);
        return self.getJson(responses.VhostInfo, path);
    }

    pub fn createVhost(self: *Client, name: []const u8, params: requests.VirtualHostParams) !void {
        const path = try self.encodePath1("/vhosts", name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deleteVhost(self: *Client, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath1("/vhosts", name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn enableVhostDeletionProtection(self: *Client, name: []const u8) !void {
        const enc = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/vhosts/{s}/deletion/protection", .{enc});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    pub fn disableVhostDeletionProtection(self: *Client, name: []const u8) !void {
        const enc = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/vhosts/{s}/deletion/protection", .{enc});
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    //
    // Connections
    //

    pub fn listConnections(self: *Client) !std.json.Parsed([]responses.ConnectionInfo) {
        return self.getJson([]responses.ConnectionInfo, "/connections");
    }

    pub fn listConnectionsPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.ConnectionInfo)) {
        const path = try self.paginatedPath("/connections", params);
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.ConnectionInfo), path);
    }

    pub fn listConnectionsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.ConnectionInfo) {
        const path = try self.encodePath1("/vhosts", vhost);
        defer self.allocator.free(path);
        const full = try std.fmt.allocPrint(self.allocator, "{s}/connections", .{path});
        defer self.allocator.free(full);
        return self.getJson([]responses.ConnectionInfo, full);
    }

    pub fn getConnectionInfo(self: *Client, name: []const u8) !std.json.Parsed(responses.ConnectionInfo) {
        const path = try self.encodePath1("/connections", name);
        defer self.allocator.free(path);
        return self.getJson(responses.ConnectionInfo, path);
    }

    pub fn closeConnection(self: *Client, name: []const u8, reason: ?[]const u8, idempotent: bool) !void {
        const path = try self.encodePath1("/connections", name);
        defer self.allocator.free(path);
        try self.httpDelete(path, reason, idempotent);
    }

    pub fn listUserConnections(self: *Client, username: []const u8) !std.json.Parsed([]responses.UserConnectionInfo) {
        const enc = try percentEncode(self.allocator, username);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/connections/username/{s}", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.UserConnectionInfo, path);
    }

    pub fn closeUserConnections(self: *Client, username: []const u8, reason: ?[]const u8, idempotent: bool) !void {
        const enc = try percentEncode(self.allocator, username);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/connections/username/{s}", .{enc});
        defer self.allocator.free(path);
        try self.httpDelete(path, reason, idempotent);
    }

    //
    // Channels
    //

    pub fn listChannels(self: *Client) !std.json.Parsed([]responses.ChannelInfo) {
        return self.getJson([]responses.ChannelInfo, "/channels");
    }

    pub fn listChannelsPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.ChannelInfo)) {
        const path = try self.paginatedPath("/channels", params);
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.ChannelInfo), path);
    }

    pub fn listChannelsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.ChannelInfo) {
        const path = try self.encodePath1("/vhosts", vhost);
        defer self.allocator.free(path);
        const full = try std.fmt.allocPrint(self.allocator, "{s}/channels", .{path});
        defer self.allocator.free(full);
        return self.getJson([]responses.ChannelInfo, full);
    }

    pub fn listChannelsByVhostPaged(self: *Client, vhost: []const u8, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.ChannelInfo)) {
        const enc = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/vhosts/{s}/channels?page={d}&page_size={d}", .{ enc, params.page, params.page_size });
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.ChannelInfo), path);
    }

    pub fn getChannelInfo(self: *Client, name: []const u8) !std.json.Parsed(responses.ChannelInfo) {
        const path = try self.encodePath1("/channels", name);
        defer self.allocator.free(path);
        return self.getJson(responses.ChannelInfo, path);
    }

    pub fn listChannelsOnConnection(self: *Client, connection: []const u8) !std.json.Parsed([]responses.ChannelInfo) {
        const enc = try percentEncode(self.allocator, connection);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/connections/{s}/channels", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.ChannelInfo, path);
    }

    //
    // Consumers
    //

    pub fn listConsumers(self: *Client) !std.json.Parsed([]responses.ConsumerInfo) {
        return self.getJson([]responses.ConsumerInfo, "/consumers");
    }

    pub fn listConsumersByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.ConsumerInfo) {
        const path = try self.encodePath1("/consumers", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.ConsumerInfo, path);
    }

    //
    // Queues
    //

    /// Requires RabbitMQ 3.13+.
    pub fn listQueuesWithDetails(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.getJson([]responses.QueueInfo, "/queues/detailed");
    }

    pub fn listQueues(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.getJson([]responses.QueueInfo, "/queues");
    }

    pub fn listQueuesPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.QueueInfo)) {
        const path = try self.paginatedPath("/queues", params);
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.QueueInfo), path);
    }

    pub fn listQueuesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        const path = try self.encodePath1("/queues", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.QueueInfo, path);
    }

    pub fn listQueuesByVhostPaged(self: *Client, vhost: []const u8, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.QueueInfo)) {
        const enc = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/{s}?page={d}&page_size={d}", .{ enc, params.page, params.page_size });
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.QueueInfo), path);
    }

    pub fn listQueuesByType(self: *Client, queue_type: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        var result = try self.getJson([]responses.QueueInfo, "/queues");
        result.value = filterQueuesByType(result.value, queue_type);
        return result;
    }

    pub fn listQueuesByVhostAndType(self: *Client, vhost: []const u8, queue_type: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        const path = try self.encodePath1("/queues", vhost);
        defer self.allocator.free(path);
        var result = try self.getJson([]responses.QueueInfo, path);
        result.value = filterQueuesByType(result.value, queue_type);
        return result;
    }

    pub fn listClassicQueues(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByType("classic");
    }

    pub fn listClassicQueuesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByVhostAndType(vhost, "classic");
    }

    pub fn listQuorumQueues(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByType("quorum");
    }

    pub fn listQuorumQueuesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByVhostAndType(vhost, "quorum");
    }

    pub fn listStreams(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByType("stream");
    }

    pub fn listStreamsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByVhostAndType(vhost, "stream");
    }

    /// Page counts reflect all queue types, not just streams.
    pub fn listStreamsPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.QueueInfo)) {
        const path = try self.paginatedPath("/queues", params);
        defer self.allocator.free(path);
        var result = try self.getJson(responses.PaginatedResponse(responses.QueueInfo), path);
        result.value.items = filterQueuesByType(result.value.items, "stream");
        return result;
    }

    pub fn listStreamsInPaged(self: *Client, vhost: []const u8, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.QueueInfo)) {
        const enc = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/{s}?page={d}&page_size={d}", .{ enc, params.page, params.page_size });
        defer self.allocator.free(path);
        var result = try self.getJson(responses.PaginatedResponse(responses.QueueInfo), path);
        result.value.items = filterQueuesByType(result.value.items, "stream");
        return result;
    }

    pub fn getQueueInfo(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.QueueInfo) {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.QueueInfo, path);
    }

    pub fn declareQueue(self: *Client, vhost: []const u8, name: []const u8, params: requests.QueueParams) !void {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn declareClassicQueue(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareQueue(vhost, name, .{ .durable = true, .auto_delete = false });
    }

    pub fn declareQuorumQueue(self: *Client, vhost: []const u8, name: []const u8) !void {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        try self.httpSend(.PUT, path,
            \\{"durable":true,"auto_delete":false,"arguments":{"x-queue-type":"quorum"}}
        );
    }

    pub fn declareStream(self: *Client, vhost: []const u8, name: []const u8) !void {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        try self.httpSend(.PUT, path,
            \\{"durable":true,"auto_delete":false,"arguments":{"x-queue-type":"stream"}}
        );
    }

    pub fn deleteQueue(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn deleteQueues(self: *Client, vhost: []const u8, names: []const []const u8, idempotent: bool) !void {
        for (names) |name| {
            try self.deleteQueue(vhost, name, idempotent);
        }
    }

    pub fn purgeQueue(self: *Client, vhost: []const u8, name: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_n = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/{s}/{s}/contents", .{ enc_v, enc_n });
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    //
    // Exchanges
    //

    pub fn listExchanges(self: *Client) !std.json.Parsed([]responses.ExchangeInfo) {
        return self.getJson([]responses.ExchangeInfo, "/exchanges");
    }

    pub fn listExchangesPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.ExchangeInfo)) {
        const path = try self.paginatedPath("/exchanges", params);
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.ExchangeInfo), path);
    }

    pub fn listExchangesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.ExchangeInfo) {
        const path = try self.encodePath1("/exchanges", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.ExchangeInfo, path);
    }

    pub fn listExchangesByVhostPaged(self: *Client, vhost: []const u8, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.ExchangeInfo)) {
        const enc = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/exchanges/{s}?page={d}&page_size={d}", .{ enc, params.page, params.page_size });
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.ExchangeInfo), path);
    }

    pub fn getExchangeInfo(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.ExchangeInfo) {
        const path = try self.encodePath2("/exchanges", vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.ExchangeInfo, path);
    }

    pub fn declareExchange(self: *Client, vhost: []const u8, name: []const u8, params: requests.ExchangeParams) !void {
        const path = try self.encodePath2("/exchanges", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn declareFanoutExchange(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareExchange(vhost, name, .{ .type = "fanout" });
    }

    pub fn declareTopicExchange(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareExchange(vhost, name, .{ .type = "topic" });
    }

    pub fn declareDirectExchange(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareExchange(vhost, name, .{ .type = "direct" });
    }

    pub fn declareHeadersExchange(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareExchange(vhost, name, .{ .type = "headers" });
    }

    pub fn deleteExchange(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/exchanges", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn deleteExchanges(self: *Client, vhost: []const u8, names: []const []const u8, idempotent: bool) !void {
        for (names) |name| {
            try self.deleteExchange(vhost, name, idempotent);
        }
    }

    //
    // Bindings
    //

    pub fn listBindings(self: *Client) !std.json.Parsed([]responses.BindingInfo) {
        return self.getJson([]responses.BindingInfo, "/bindings");
    }

    pub fn listBindingsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const path = try self.encodePath1("/bindings", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listQueueBindings(self: *Client, vhost: []const u8, queue: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_q = try percentEncode(self.allocator, queue);
        defer self.allocator.free(enc_q);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/{s}/{s}/bindings", .{ enc_v, enc_q });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listExchangeBindingsWithSource(self: *Client, vhost: []const u8, exchange: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_e = try percentEncode(self.allocator, exchange);
        defer self.allocator.free(enc_e);
        const path = try std.fmt.allocPrint(self.allocator, "/exchanges/{s}/{s}/bindings/source", .{ enc_v, enc_e });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listExchangeBindingsWithDestination(self: *Client, vhost: []const u8, exchange: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_e = try percentEncode(self.allocator, exchange);
        defer self.allocator.free(enc_e);
        const path = try std.fmt.allocPrint(self.allocator, "/exchanges/{s}/{s}/bindings/destination", .{ enc_v, enc_e });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listBindingsBetweenExchangeAndQueue(self: *Client, vhost: []const u8, exchange: []const u8, queue: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_e = try percentEncode(self.allocator, exchange);
        defer self.allocator.free(enc_e);
        const enc_q = try percentEncode(self.allocator, queue);
        defer self.allocator.free(enc_q);
        const path = try std.fmt.allocPrint(self.allocator, "/bindings/{s}/e/{s}/q/{s}", .{ enc_v, enc_e, enc_q });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listExchangeBindingsBetween(self: *Client, vhost: []const u8, source: []const u8, destination: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_s = try percentEncode(self.allocator, source);
        defer self.allocator.free(enc_s);
        const enc_d = try percentEncode(self.allocator, destination);
        defer self.allocator.free(enc_d);
        const path = try std.fmt.allocPrint(self.allocator, "/bindings/{s}/e/{s}/e/{s}", .{ enc_v, enc_s, enc_d });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn bindQueue(self: *Client, vhost: []const u8, exchange: []const u8, queue: []const u8, params: requests.BindingParams) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_e = try percentEncode(self.allocator, exchange);
        defer self.allocator.free(enc_e);
        const enc_q = try percentEncode(self.allocator, queue);
        defer self.allocator.free(enc_q);
        const path = try std.fmt.allocPrint(self.allocator, "/bindings/{s}/e/{s}/q/{s}", .{ enc_v, enc_e, enc_q });
        defer self.allocator.free(path);
        try self.postJson(path, params);
    }

    pub fn bindExchange(self: *Client, vhost: []const u8, source: []const u8, destination: []const u8, params: requests.BindingParams) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_s = try percentEncode(self.allocator, source);
        defer self.allocator.free(enc_s);
        const enc_d = try percentEncode(self.allocator, destination);
        defer self.allocator.free(enc_d);
        const path = try std.fmt.allocPrint(self.allocator, "/bindings/{s}/e/{s}/e/{s}", .{ enc_v, enc_s, enc_d });
        defer self.allocator.free(path);
        try self.postJson(path, params);
    }

    pub fn deleteQueueBinding(self: *Client, vhost: []const u8, exchange: []const u8, queue: []const u8, properties_key: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_e = try percentEncode(self.allocator, exchange);
        defer self.allocator.free(enc_e);
        const enc_q = try percentEncode(self.allocator, queue);
        defer self.allocator.free(enc_q);
        const enc_p = try percentEncode(self.allocator, properties_key);
        defer self.allocator.free(enc_p);
        const path = try std.fmt.allocPrint(self.allocator, "/bindings/{s}/e/{s}/q/{s}/{s}", .{ enc_v, enc_e, enc_q, enc_p });
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    pub fn deleteExchangeBinding(self: *Client, vhost: []const u8, source: []const u8, destination: []const u8, properties_key: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_s = try percentEncode(self.allocator, source);
        defer self.allocator.free(enc_s);
        const enc_d = try percentEncode(self.allocator, destination);
        defer self.allocator.free(enc_d);
        const enc_p = try percentEncode(self.allocator, properties_key);
        defer self.allocator.free(enc_p);
        const path = try std.fmt.allocPrint(self.allocator, "/bindings/{s}/e/{s}/e/{s}/{s}", .{ enc_v, enc_s, enc_d, enc_p });
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    //
    // Users
    //

    pub fn listUsers(self: *Client) !std.json.Parsed([]responses.UserInfo) {
        return self.getJson([]responses.UserInfo, "/users");
    }

    pub fn listUsersPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.UserInfo)) {
        const path = try self.paginatedPath("/users", params);
        defer self.allocator.free(path);
        return self.getJson(responses.PaginatedResponse(responses.UserInfo), path);
    }

    pub fn listUsersWithoutPermissions(self: *Client) !std.json.Parsed([]responses.UserInfo) {
        return self.getJson([]responses.UserInfo, "/users/without-permissions");
    }

    pub fn getUser(self: *Client, name: []const u8) !std.json.Parsed(responses.UserInfo) {
        const path = try self.encodePath1("/users", name);
        defer self.allocator.free(path);
        return self.getJson(responses.UserInfo, path);
    }

    pub fn createUser(self: *Client, name: []const u8, params: requests.UserParams) !void {
        const path = try self.encodePath1("/users", name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deleteUser(self: *Client, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath1("/users", name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn deleteUsers(self: *Client, params: requests.BulkUserDeleteParams) !void {
        try self.postJson("/users/bulk-delete", params);
    }

    pub fn whoAmI(self: *Client) !std.json.Parsed(responses.CurrentUser) {
        return self.getJson(responses.CurrentUser, "/whoami");
    }

    //
    // Permissions
    //

    pub fn listPermissions(self: *Client) !std.json.Parsed([]responses.PermissionInfo) {
        return self.getJson([]responses.PermissionInfo, "/permissions");
    }

    pub fn listPermissionsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.PermissionInfo) {
        const enc = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/vhosts/{s}/permissions", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.PermissionInfo, path);
    }

    pub fn listPermissionsOf(self: *Client, username: []const u8) !std.json.Parsed([]responses.PermissionInfo) {
        const enc = try percentEncode(self.allocator, username);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/users/{s}/permissions", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.PermissionInfo, path);
    }

    pub fn getPermissions(self: *Client, vhost: []const u8, username: []const u8) !std.json.Parsed(responses.PermissionInfo) {
        const path = try self.encodePath2("/permissions", vhost, username);
        defer self.allocator.free(path);
        return self.getJson(responses.PermissionInfo, path);
    }

    pub fn grantPermissions(self: *Client, vhost: []const u8, username: []const u8, params: requests.PermissionParams) !void {
        const path = try self.encodePath2("/permissions", vhost, username);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn clearPermissions(self: *Client, vhost: []const u8, username: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/permissions", vhost, username);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn grantFullPermissions(self: *Client, vhost: []const u8, username: []const u8) !void {
        try self.grantPermissions(vhost, username, .{
            .configure = ".*",
            .write = ".*",
            .read = ".*",
        });
    }

    //
    // Topic Permissions
    //

    pub fn listTopicPermissions(self: *Client) !std.json.Parsed([]responses.TopicPermissionInfo) {
        return self.getJson([]responses.TopicPermissionInfo, "/topic-permissions");
    }

    pub fn listTopicPermissionsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.TopicPermissionInfo) {
        const enc = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/vhosts/{s}/topic-permissions", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.TopicPermissionInfo, path);
    }

    pub fn listTopicPermissionsOf(self: *Client, username: []const u8) !std.json.Parsed([]responses.TopicPermissionInfo) {
        const enc = try percentEncode(self.allocator, username);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/users/{s}/topic-permissions", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.TopicPermissionInfo, path);
    }

    pub fn getTopicPermissions(self: *Client, vhost: []const u8, username: []const u8) !std.json.Parsed(responses.TopicPermissionInfo) {
        const path = try self.encodePath2("/topic-permissions", vhost, username);
        defer self.allocator.free(path);
        return self.getJson(responses.TopicPermissionInfo, path);
    }

    pub fn grantTopicPermissions(self: *Client, vhost: []const u8, username: []const u8, params: requests.TopicPermissionParams) !void {
        const path = try self.encodePath2("/topic-permissions", vhost, username);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn clearTopicPermissions(self: *Client, vhost: []const u8, username: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/topic-permissions", vhost, username);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    //
    // Policies
    //

    pub fn listPolicies(self: *Client) !std.json.Parsed([]responses.PolicyInfo) {
        return self.getJson([]responses.PolicyInfo, "/policies");
    }

    pub fn listPoliciesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.PolicyInfo) {
        const path = try self.encodePath1("/policies", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.PolicyInfo, path);
    }

    pub fn getPolicy(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.PolicyInfo) {
        const path = try self.encodePath2("/policies", vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.PolicyInfo, path);
    }

    pub fn declarePolicy(self: *Client, vhost: []const u8, name: []const u8, params: requests.PolicyParams) !void {
        const path = try self.encodePath2("/policies", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deletePolicy(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/policies", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn listPoliciesForTarget(self: *Client, vhost: []const u8, target: commons.PolicyTarget) !std.json.Parsed([]responses.PolicyInfo) {
        const path = try self.encodePath1("/policies", vhost);
        defer self.allocator.free(path);
        var result = try self.getJson([]responses.PolicyInfo, path);
        result.value = filterPoliciesByTarget(result.value, target.toApiString());
        return result;
    }

    pub fn listOperatorPoliciesForTarget(self: *Client, vhost: []const u8, target: commons.PolicyTarget) !std.json.Parsed([]responses.PolicyInfo) {
        const path = try self.encodePath1("/operator-policies", vhost);
        defer self.allocator.free(path);
        var result = try self.getJson([]responses.PolicyInfo, path);
        result.value = filterPoliciesByTarget(result.value, target.toApiString());
        return result;
    }

    pub fn listMatchingPolicies(self: *Client, vhost: []const u8, name: []const u8, target: commons.PolicyTarget) !std.json.Parsed([]responses.PolicyInfo) {
        var result = try self.listPoliciesForTarget(vhost, target);
        result.value = filterMatchingPolicies(result.value, name);
        return result;
    }

    pub fn listMatchingOperatorPolicies(self: *Client, vhost: []const u8, name: []const u8, target: commons.PolicyTarget) !std.json.Parsed([]responses.PolicyInfo) {
        var result = try self.listOperatorPoliciesForTarget(vhost, target);
        result.value = filterMatchingPolicies(result.value, name);
        return result;
    }

    //
    // Operator Policies
    //

    pub fn listOperatorPolicies(self: *Client) !std.json.Parsed([]responses.PolicyInfo) {
        return self.getJson([]responses.PolicyInfo, "/operator-policies");
    }

    pub fn listOperatorPoliciesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.PolicyInfo) {
        const path = try self.encodePath1("/operator-policies", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.PolicyInfo, path);
    }

    pub fn getOperatorPolicy(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.PolicyInfo) {
        const path = try self.encodePath2("/operator-policies", vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.PolicyInfo, path);
    }

    pub fn declareOperatorPolicy(self: *Client, vhost: []const u8, name: []const u8, params: requests.PolicyParams) !void {
        const path = try self.encodePath2("/operator-policies", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deleteOperatorPolicy(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/operator-policies", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn declarePolicies(self: *Client, vhost: []const u8, policies: []const requests.NamedPolicyParams) !void {
        for (policies) |p| {
            try self.declarePolicy(vhost, p.name, p.params);
        }
    }

    pub fn deletePoliciesIn(self: *Client, vhost: []const u8, names: []const []const u8, idempotent: bool) !void {
        for (names) |name| {
            try self.deletePolicy(vhost, name, idempotent);
        }
    }

    pub fn declareOperatorPolicies(self: *Client, vhost: []const u8, policies: []const requests.NamedPolicyParams) !void {
        for (policies) |p| {
            try self.declareOperatorPolicy(vhost, p.name, p.params);
        }
    }

    pub fn deleteOperatorPoliciesIn(self: *Client, vhost: []const u8, names: []const []const u8, idempotent: bool) !void {
        for (names) |name| {
            try self.deleteOperatorPolicy(vhost, name, idempotent);
        }
    }

    //
    // Health Checks
    //

    pub fn healthCheckClusterAlarms(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/alarms");
    }

    pub fn healthCheckLocalAlarms(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/local-alarms");
    }

    pub fn healthCheckNodeIsQuorumCritical(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/node-is-quorum-critical");
    }

    pub fn healthCheckPortListener(self: *Client, port: u16) !bool {
        const path = try std.fmt.allocPrint(self.allocator, "/health/checks/port-listener/{d}", .{port});
        defer self.allocator.free(path);
        return self.healthCheckGet(path);
    }

    pub fn healthCheckProtocolListener(self: *Client, protocol: []const u8) !bool {
        const enc = try percentEncode(self.allocator, protocol);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/health/checks/protocol-listener/{s}", .{enc});
        defer self.allocator.free(path);
        return self.healthCheckGet(path);
    }

    pub fn healthCheckVirtualHosts(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/virtual-hosts");
    }

    pub fn healthCheckIsInService(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/is-in-service");
    }

    pub fn healthCheckBelowConnectionLimit(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/below-node-connection-limit");
    }

    pub fn healthCheckReadyToServeClients(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/ready-to-serve-clients");
    }

    pub fn healthCheckCertificateExpiration(self: *Client, within: u32, unit: []const u8) !bool {
        const path = try std.fmt.allocPrint(self.allocator, "/health/checks/certificate-expiration/{d}/{s}", .{ within, unit });
        defer self.allocator.free(path);
        return self.healthCheckGet(path);
    }

    //
    // Feature Flags
    //

    pub fn listFeatureFlags(self: *Client) !std.json.Parsed([]responses.FeatureFlagInfo) {
        return self.getJson([]responses.FeatureFlagInfo, "/feature-flags");
    }

    pub fn enableFeatureFlag(self: *Client, name: []const u8) !void {
        const enc = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/feature-flags/{s}/enable", .{enc});
        defer self.allocator.free(path);
        try self.httpSend(.PUT, path, "{}");
    }

    pub fn enableAllStableFeatureFlags(self: *Client) !void {
        try self.httpSend(.PUT, "/feature-flags", "{}");
    }

    //
    // Deprecated Features
    //

    pub fn listDeprecatedFeatures(self: *Client) !std.json.Parsed([]responses.DeprecatedFeatureInfo) {
        return self.getJson([]responses.DeprecatedFeatureInfo, "/deprecated-features");
    }

    pub fn listDeprecatedFeaturesInUse(self: *Client) !std.json.Parsed([]responses.DeprecatedFeatureInfo) {
        return self.getJson([]responses.DeprecatedFeatureInfo, "/deprecated-features/used");
    }

    //
    // Definitions
    //

    pub fn exportDefinitions(self: *Client) !std.json.Parsed(responses.DefinitionSet) {
        return self.getJson(responses.DefinitionSet, "/definitions");
    }

    pub fn exportVhostDefinitions(self: *Client, vhost: []const u8) !std.json.Parsed(responses.DefinitionSet) {
        const path = try self.encodePath1("/definitions", vhost);
        defer self.allocator.free(path);
        return self.getJson(responses.DefinitionSet, path);
    }

    pub fn exportDefinitionsAsString(self: *Client) ![]u8 {
        return self.httpGet("/definitions");
    }

    pub fn exportVhostDefinitionsAsString(self: *Client, vhost: []const u8) ![]u8 {
        const path = try self.encodePath1("/definitions", vhost);
        defer self.allocator.free(path);
        return self.httpGet(path);
    }

    pub fn importDefinitions(self: *Client, definitions_json: []const u8) !void {
        try self.httpSend(.POST, "/definitions", definitions_json);
    }

    pub fn importVhostDefinitions(self: *Client, vhost: []const u8, definitions_json: []const u8) !void {
        const path = try self.encodePath1("/definitions", vhost);
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, definitions_json);
    }

    //
    // Runtime Parameters
    //

    pub fn listRuntimeParameters(self: *Client) !std.json.Parsed([]responses.RuntimeParameter) {
        return self.getJson([]responses.RuntimeParameter, "/parameters");
    }

    pub fn listRuntimeParametersByComponent(self: *Client, component: []const u8) !std.json.Parsed([]responses.RuntimeParameter) {
        const path = try self.encodePath1("/parameters", component);
        defer self.allocator.free(path);
        return self.getJson([]responses.RuntimeParameter, path);
    }

    pub fn listRuntimeParametersByComponentInVhost(self: *Client, component: []const u8, vhost: []const u8) !std.json.Parsed([]responses.RuntimeParameter) {
        const path = try self.encodePath2("/parameters", component, vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.RuntimeParameter, path);
    }

    pub fn getRuntimeParameter(self: *Client, component: []const u8, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.RuntimeParameter) {
        const path = try self.encodePath3("/parameters", component, vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.RuntimeParameter, path);
    }

    pub fn upsertRuntimeParameter(self: *Client, component: []const u8, vhost: []const u8, name: []const u8, params: requests.RuntimeParameterParams) !void {
        const path = try self.encodePath3("/parameters", component, vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deleteRuntimeParameter(self: *Client, component: []const u8, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath3("/parameters", component, vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn clearAllRuntimeParameters(self: *Client, vhost: []const u8) !void {
        const result = try self.listRuntimeParameters();
        defer result.deinit();
        for (result.value) |p| {
            if (p.vhost) |v| {
                if (std.mem.eql(u8, v, vhost)) {
                    if (p.component) |c| {
                        if (p.name) |n| {
                            try self.deleteRuntimeParameter(c, vhost, n, true);
                        }
                    }
                }
            }
        }
    }

    pub fn clearAllRuntimeParametersOfComponent(self: *Client, vhost: []const u8, component: []const u8) !void {
        const result = try self.listRuntimeParametersByComponentInVhost(component, vhost);
        defer result.deinit();
        for (result.value) |p| {
            if (p.name) |n| {
                try self.deleteRuntimeParameter(component, vhost, n, true);
            }
        }
    }

    //
    // Global Parameters
    //

    pub fn listGlobalParameters(self: *Client) !std.json.Parsed([]responses.GlobalParameter) {
        return self.getJson([]responses.GlobalParameter, "/global-parameters");
    }

    pub fn getGlobalParameter(self: *Client, name: []const u8) !std.json.Parsed(responses.GlobalParameter) {
        const path = try self.encodePath1("/global-parameters", name);
        defer self.allocator.free(path);
        return self.getJson(responses.GlobalParameter, path);
    }

    pub fn upsertGlobalParameter(self: *Client, name: []const u8, params: requests.GlobalParameterParams) !void {
        const path = try self.encodePath1("/global-parameters", name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deleteGlobalParameter(self: *Client, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath1("/global-parameters", name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    //
    // User Limits
    //

    pub fn listAllUserLimits(self: *Client) !std.json.Parsed([]responses.UserLimitInfo) {
        return self.getJson([]responses.UserLimitInfo, "/user-limits");
    }

    pub fn listUserLimits(self: *Client, username: []const u8) !std.json.Parsed([]responses.UserLimitInfo) {
        const path = try self.encodePath1("/user-limits", username);
        defer self.allocator.free(path);
        return self.getJson([]responses.UserLimitInfo, path);
    }

    pub fn setUserLimit(self: *Client, username: []const u8, limit_name: []const u8, params: requests.LimitParams) !void {
        const path = try self.encodePath2("/user-limits", username, limit_name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn clearUserLimit(self: *Client, username: []const u8, limit_name: []const u8) !void {
        const path = try self.encodePath2("/user-limits", username, limit_name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    //
    // Virtual Host Limits
    //

    pub fn listAllVhostLimits(self: *Client) !std.json.Parsed([]responses.VhostLimitInfo) {
        return self.getJson([]responses.VhostLimitInfo, "/vhost-limits");
    }

    pub fn listVhostLimits(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.VhostLimitInfo) {
        const path = try self.encodePath1("/vhost-limits", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.VhostLimitInfo, path);
    }

    pub fn setVhostLimit(self: *Client, vhost: []const u8, limit_name: []const u8, params: requests.LimitParams) !void {
        const path = try self.encodePath2("/vhost-limits", vhost, limit_name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn clearVhostLimit(self: *Client, vhost: []const u8, limit_name: []const u8) !void {
        const path = try self.encodePath2("/vhost-limits", vhost, limit_name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    //
    // Federation
    //

    pub fn listFederationUpstreams(self: *Client) !std.json.Parsed([]responses.FederationUpstream) {
        return self.getJson([]responses.FederationUpstream, "/parameters/federation-upstream");
    }

    pub fn listFederationUpstreamsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.FederationUpstream) {
        const path = try self.encodePath1("/parameters/federation-upstream", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.FederationUpstream, path);
    }

    pub fn getFederationUpstream(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.FederationUpstream) {
        const path = try self.encodePath2("/parameters/federation-upstream", vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.FederationUpstream, path);
    }

    pub fn declareFederationUpstream(self: *Client, vhost: []const u8, name: []const u8, params: requests.FederationUpstreamParams) !void {
        const path = try self.encodePath2("/parameters/federation-upstream", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deleteFederationUpstream(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/parameters/federation-upstream", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn listFederationLinks(self: *Client) !std.json.Parsed([]responses.FederationLink) {
        return self.getJson([]responses.FederationLink, "/federation-links");
    }

    pub fn listFederationLinksByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.FederationLink) {
        const path = try self.encodePath1("/federation-links", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.FederationLink, path);
    }

    //
    // Shovels
    //

    pub fn listShovels(self: *Client) !std.json.Parsed([]responses.ShovelStatus) {
        return self.getJson([]responses.ShovelStatus, "/shovels");
    }

    pub fn listShovelsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.ShovelStatus) {
        const path = try self.encodePath1("/shovels", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.ShovelStatus, path);
    }

    pub fn declareShovel(self: *Client, vhost: []const u8, name: []const u8, params: requests.ShovelParams) !void {
        const path = try self.encodePath2("/parameters/shovel", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn deleteShovel(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/parameters/shovel", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn getShovelStatus(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.ShovelStatus) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_n = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/shovels/vhost/{s}/{s}", .{ enc_v, enc_n });
        defer self.allocator.free(path);
        return self.getJson(responses.ShovelStatus, path);
    }

    pub fn declareAmqp091Shovel(self: *Client, vhost: []const u8, name: []const u8, params: requests.Amqp091ShovelParams) !void {
        const path = try self.encodePath2("/parameters/shovel", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, .{ .value = params });
    }

    pub fn declareAmqp10Shovel(self: *Client, vhost: []const u8, name: []const u8, params: requests.Amqp10ShovelParams) !void {
        const path = try self.encodePath2("/parameters/shovel", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, .{ .value = params });
    }

    pub fn deleteBinding(self: *Client, params: requests.BindingDeletionParams) !void {
        switch (params.destination_type) {
            .queue => try self.deleteQueueBinding(params.vhost, params.source, params.destination, params.properties_key),
            .exchange => try self.deleteExchangeBinding(params.vhost, params.source, params.destination, params.properties_key),
        }
    }

    pub fn recreateBinding(self: *Client, info: responses.BindingInfo) !void {
        const vhost = info.vhost orelse return error.BadRequest;
        const source = info.source orelse return error.BadRequest;
        const destination = info.destination orelse return error.BadRequest;
        const dest_type = info.destination_type orelse "queue";
        const rk = info.routing_key orelse "";

        if (std.mem.eql(u8, dest_type, "queue")) {
            try self.bindQueue(vhost, source, destination, .{
                .routing_key = rk,
                .arguments = info.arguments,
            });
        } else {
            try self.bindExchange(vhost, source, destination, .{
                .routing_key = rk,
                .arguments = info.arguments,
            });
        }
    }

    //
    // Stream Protocol
    //

    pub fn listStreamConnections(self: *Client) !std.json.Parsed([]responses.StreamConnectionInfo) {
        return self.getJson([]responses.StreamConnectionInfo, "/stream/connections");
    }

    pub fn listStreamConnectionsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.StreamConnectionInfo) {
        const path = try self.encodePath1("/stream/connections", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.StreamConnectionInfo, path);
    }

    pub fn getStreamConnectionInfo(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.StreamConnectionInfo) {
        const path = try self.encodePath2("/stream/connections", vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.StreamConnectionInfo, path);
    }

    pub fn closeStreamConnection(self: *Client, vhost: []const u8, name: []const u8, reason: ?[]const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/stream/connections", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, reason, idempotent);
    }

    pub fn listStreamPublishers(self: *Client) !std.json.Parsed([]responses.StreamPublisherInfo) {
        return self.getJson([]responses.StreamPublisherInfo, "/stream/publishers");
    }

    pub fn listStreamPublishersByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.StreamPublisherInfo) {
        const path = try self.encodePath1("/stream/publishers", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.StreamPublisherInfo, path);
    }

    pub fn listStreamPublishersOfStream(self: *Client, vhost: []const u8, stream: []const u8) !std.json.Parsed([]responses.StreamPublisherInfo) {
        const path = try self.encodePath2("/stream/publishers", vhost, stream);
        defer self.allocator.free(path);
        return self.getJson([]responses.StreamPublisherInfo, path);
    }

    pub fn listStreamPublishersOnConnection(self: *Client, vhost: []const u8, connection: []const u8) !std.json.Parsed([]responses.StreamPublisherInfo) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_c = try percentEncode(self.allocator, connection);
        defer self.allocator.free(enc_c);
        const path = try std.fmt.allocPrint(self.allocator, "/stream/connections/{s}/{s}/publishers", .{ enc_v, enc_c });
        defer self.allocator.free(path);
        return self.getJson([]responses.StreamPublisherInfo, path);
    }

    pub fn listStreamConsumers(self: *Client) !std.json.Parsed([]responses.StreamConsumerInfo) {
        return self.getJson([]responses.StreamConsumerInfo, "/stream/consumers");
    }

    pub fn listStreamConsumersByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.StreamConsumerInfo) {
        const path = try self.encodePath1("/stream/consumers", vhost);
        defer self.allocator.free(path);
        return self.getJson([]responses.StreamConsumerInfo, path);
    }

    pub fn listStreamConsumersOnConnection(self: *Client, vhost: []const u8, connection: []const u8) !std.json.Parsed([]responses.StreamConsumerInfo) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_c = try percentEncode(self.allocator, connection);
        defer self.allocator.free(enc_c);
        const path = try std.fmt.allocPrint(self.allocator, "/stream/connections/{s}/{s}/consumers", .{ enc_v, enc_c });
        defer self.allocator.free(path);
        return self.getJson([]responses.StreamConsumerInfo, path);
    }

    //
    // Plugins
    //

    pub fn listNodePlugins(self: *Client, node: []const u8) !std.json.Parsed([]responses.PluginInfo) {
        const enc = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/nodes/{s}/plugins", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.PluginInfo, path);
    }

    pub fn listExtensions(self: *Client) !std.json.Parsed([]responses.ExtensionInfo) {
        return self.getJson([]responses.ExtensionInfo, "/extensions");
    }

    //
    // OAuth & Authentication
    //

    pub fn getOAuthConfiguration(self: *Client) !std.json.Parsed(responses.OAuthConfiguration) {
        return self.getJson(responses.OAuthConfiguration, "/auth");
    }

    pub fn getAuthAttempts(self: *Client, node: []const u8) !std.json.Parsed([]responses.AuthAttemptInfo) {
        const enc = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/auth/attempts/{s}", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.AuthAttemptInfo, path);
    }

    //
    // Rebalancing
    //

    pub fn rebalanceQueueLeaders(self: *Client) !void {
        try self.httpSend(.POST, "/rebalance/queues", "{}");
    }

    //
    // Schema Definition Sync
    //

    pub fn enableSchemaDefinitionSync(self: *Client) !void {
        try self.httpSend(.POST, "/schema-definition-sync/enable", null);
    }

    pub fn disableSchemaDefinitionSync(self: *Client) !void {
        try self.httpSend(.POST, "/schema-definition-sync/disable", null);
    }

    pub fn getSchemaDefinitionSyncStatus(self: *Client) !std.json.Parsed(responses.SchemaReplicationStatus) {
        return self.getJson(responses.SchemaReplicationStatus, "/schema-definition-sync/status");
    }

    pub fn enableSchemaDefinitionSyncOnNode(self: *Client, node: []const u8) !void {
        const enc = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/schema-definition-sync/enable/{s}", .{enc});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    pub fn disableSchemaDefinitionSyncOnNode(self: *Client, node: []const u8) !void {
        const enc = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/schema-definition-sync/disable/{s}", .{enc});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    pub fn getSchemaDefinitionSyncStatusOnNode(self: *Client, node: []const u8) !std.json.Parsed(responses.SchemaReplicationStatus) {
        const enc = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/schema-definition-sync/status/{s}", .{enc});
        defer self.allocator.free(path);
        return self.getJson(responses.SchemaReplicationStatus, path);
    }

    pub fn getWarmStandbyReplicationStatus(self: *Client) !std.json.Parsed(std.json.Value) {
        return self.getJson(std.json.Value, "/warm-standby/replication/status");
    }

    //
    // Messages
    //

    pub fn publishMessage(self: *Client, vhost: []const u8, exchange: []const u8, params: requests.PublishMessageParams) !std.json.Parsed(responses.PublishResult) {
        const path = try self.encodePath2("/exchanges", vhost, exchange);
        defer self.allocator.free(path);
        const full = try std.fmt.allocPrint(self.allocator, "{s}/publish", .{path});
        defer self.allocator.free(full);
        // The API requires "properties" even when empty.
        const wire = PublishRequest{
            .properties = params.properties orelse .{ .object = std.json.ObjectMap.init(self.allocator) },
            .routing_key = params.routing_key,
            .payload = params.payload,
            .payload_encoding = params.payload_encoding,
        };
        return self.postJsonGetJson(responses.PublishResult, full, wire);
    }

    const PublishRequest = struct {
        properties: std.json.Value,
        routing_key: []const u8,
        payload: []const u8,
        payload_encoding: []const u8,
    };

    pub fn getMessages(self: *Client, vhost: []const u8, queue: []const u8, params: requests.GetMessagesParams) !std.json.Parsed([]responses.MessageInfo) {
        const path = try self.encodePath2("/queues", vhost, queue);
        defer self.allocator.free(path);
        const full = try std.fmt.allocPrint(self.allocator, "{s}/get", .{path});
        defer self.allocator.free(full);
        return self.postJsonGetJson([]responses.MessageInfo, full, params);
    }

    //
    // Quorum Queue Replica Management
    //

    pub fn getQuorumQueueStatus(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(std.json.Value) {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_n = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/quorum/{s}/{s}/status", .{ enc_v, enc_n });
        defer self.allocator.free(path);
        return self.getJson(std.json.Value, path);
    }

    pub fn addQuorumQueueReplica(self: *Client, vhost: []const u8, name: []const u8, node: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_n = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/quorum/{s}/{s}/replicas/add", .{ enc_v, enc_n });
        defer self.allocator.free(path);
        const body = try std.fmt.allocPrint(self.allocator, "{{\"node\":\"{s}\"}}", .{node});
        defer self.allocator.free(body);
        try self.httpSend(.POST, path, body);
    }

    pub fn deleteQuorumQueueReplica(self: *Client, vhost: []const u8, name: []const u8, node: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_n = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/quorum/{s}/{s}/replicas/delete", .{ enc_v, enc_n });
        defer self.allocator.free(path);
        const body = try std.fmt.allocPrint(self.allocator, "{{\"node\":\"{s}\"}}", .{node});
        defer self.allocator.free(body);
        try self.httpSend(.POST, path, body);
    }

    pub fn growQuorumQueueReplicas(self: *Client, node: []const u8) !void {
        const enc = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/quorum/replicas/on/{s}/grow", .{enc});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, "{}");
    }

    pub fn shrinkQuorumQueueReplicas(self: *Client, node: []const u8) !void {
        const enc = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/queues/quorum/replicas/on/{s}/shrink", .{enc});
        defer self.allocator.free(path);
        try self.httpSend(.DELETE, path, null);
    }

    //
    // Virtual Host Operations
    //

    pub fn startVhostOnNode(self: *Client, vhost: []const u8, node: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_n = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/vhosts/{s}/start/{s}", .{ enc_v, enc_n });
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    //
    // Shovel Operations
    //

    pub fn restartShovel(self: *Client, vhost: []const u8, name: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_n = try percentEncode(self.allocator, name);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/shovels/vhost/{s}/{s}/restart", .{ enc_v, enc_n });
        defer self.allocator.free(path);
        try self.httpSend(.DELETE, path, null);
    }

    //
    // Federation Operations
    //

    pub fn restartFederationLink(self: *Client, vhost: []const u8, id: []const u8, node: []const u8) !void {
        const enc_v = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc_v);
        const enc_id = try percentEncode(self.allocator, id);
        defer self.allocator.free(enc_id);
        const enc_n = try percentEncode(self.allocator, node);
        defer self.allocator.free(enc_n);
        const path = try std.fmt.allocPrint(self.allocator, "/federation-links/vhost/{s}/{s}/{s}/restart", .{ enc_v, enc_id, enc_n });
        defer self.allocator.free(path);
        try self.httpSend(.DELETE, path, null);
    }

    pub fn listDownFederationLinks(self: *Client) !std.json.Parsed([]responses.FederationLink) {
        return self.getJson([]responses.FederationLink, "/federation-links/state/down/");
    }

    pub fn listDownFederationLinksByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.FederationLink) {
        const enc = try percentEncode(self.allocator, vhost);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/federation-links/{s}/state/down", .{enc});
        defer self.allocator.free(path);
        return self.getJson([]responses.FederationLink, path);
    }

    //
    // Hash Password
    //

    pub fn hashPassword(self: *Client, password: []const u8) !std.json.Parsed(std.json.Value) {
        const enc = try percentEncode(self.allocator, password);
        defer self.allocator.free(enc);
        const path = try std.fmt.allocPrint(self.allocator, "/auth/hash_password/{s}", .{enc});
        defer self.allocator.free(path);
        return self.getJson(std.json.Value, path);
    }

    //
    // Effective Configuration
    //

    pub fn getEffectiveConfig(self: *Client) !std.json.Parsed(std.json.Value) {
        return self.getJson(std.json.Value, "/config/effective");
    }

    const json_stringify_options: std.json.Stringify.Options = .{ .emit_null_optional_fields = false };
    const json_parse_options: std.json.ParseOptions = .{ .ignore_unknown_fields = true, .allocate = .alloc_always };

    //
    // Internal HTTP helpers
    //

    fn getJson(self: *Client, comptime T: type, path: []const u8) !std.json.Parsed(T) {
        const body = try self.httpGet(path);
        defer self.allocator.free(body);
        return std.json.parseFromSlice(T, self.allocator, body, json_parse_options) catch return error.JsonParseFailed;
    }

    fn putJson(self: *Client, path: []const u8, body: anytype) !void {
        const json = std.json.Stringify.valueAlloc(self.allocator, body, json_stringify_options) catch return error.OutOfMemory;
        defer self.allocator.free(json);
        try self.httpSend(.PUT, path, json);
    }

    fn postJson(self: *Client, path: []const u8, body: anytype) !void {
        const json = std.json.Stringify.valueAlloc(self.allocator, body, json_stringify_options) catch return error.OutOfMemory;
        defer self.allocator.free(json);
        try self.httpSend(.POST, path, json);
    }

    fn postJsonGetJson(self: *Client, comptime T: type, path: []const u8, body: anytype) !std.json.Parsed(T) {
        const json = std.json.Stringify.valueAlloc(self.allocator, body, json_stringify_options) catch return error.OutOfMemory;
        defer self.allocator.free(json);
        const resp = try self.httpRequestWithBody(.POST, path, json);
        defer self.allocator.free(resp);
        return std.json.parseFromSlice(T, self.allocator, resp, json_parse_options) catch return error.JsonParseFailed;
    }

    fn paginatedPath(self: *Client, base: []const u8, params: requests.PaginationParams) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{s}?page={d}&page_size={d}", .{ base, params.page, params.page_size });
    }

    fn checkStatus(status: http.Status) !void {
        const code = @intFromEnum(status);
        if (code >= 200 and code < 300) return;
        switch (status) {
            .unauthorized => return error.Unauthorized,
            .not_found => return error.NotFound,
            else => {},
        }
        if (code >= 500) return error.ServerError;
        if (code >= 400) return error.BadRequest;
        return error.HttpRequestFailed;
    }

    fn readResponseBody(self: *Client, response: *http.Client.Response) ![]u8 {
        var transfer_buf: [65536]u8 = undefined;
        var decompress: http.Decompress = undefined;
        var decompress_buf: [65536]u8 = undefined;
        const rdr = response.readerDecompressing(&transfer_buf, &decompress, &decompress_buf);
        var body: std.ArrayList(u8) = .empty;
        errdefer body.deinit(self.allocator);
        rdr.appendRemainingUnlimited(self.allocator, &body) catch return error.HttpRequestFailed;
        return body.toOwnedSlice(self.allocator) catch return error.OutOfMemory;
    }

    fn httpGet(self: *Client, path: []const u8) ![]u8 {
        const url = try self.buildUrl(path);
        defer self.allocator.free(url);

        const uri = std.Uri.parse(url) catch return error.HttpRequestFailed;
        var req = self.http_client.request(.GET, uri, .{
            .extra_headers = &.{
                .{ .name = "authorization", .value = self.auth_header },
            },
            .keep_alive = false,
        }) catch return error.HttpRequestFailed;
        defer req.deinit();

        req.sendBodiless() catch return error.HttpRequestFailed;
        var redirect_buf: [1024]u8 = undefined;
        var response = req.receiveHead(&redirect_buf) catch return error.HttpRequestFailed;
        try checkStatus(response.head.status);
        return self.readResponseBody(&response);
    }

    fn httpSend(self: *Client, method: http.Method, path: []const u8, body: ?[]const u8) !void {
        const url = try self.buildUrl(path);
        defer self.allocator.free(url);

        const payload: ?[]const u8 = body orelse if (method.requestHasBody()) "" else null;

        var header_buf: [3]http.Header = undefined;
        var header_count: usize = 1;
        header_buf[0] = .{ .name = "authorization", .value = self.auth_header };
        if (payload != null) {
            header_buf[header_count] = .{ .name = "content-type", .value = "application/json" };
            header_count += 1;
        }

        const result = self.http_client.fetch(.{
            .location = .{ .url = url },
            .method = method,
            .payload = payload,
            .extra_headers = header_buf[0..header_count],
            .keep_alive = false,
        }) catch return error.HttpRequestFailed;

        try checkStatus(result.status);
    }

    fn httpRequestWithBody(self: *Client, method: http.Method, path: []const u8, body: []const u8) ![]u8 {
        const url = try self.buildUrl(path);
        defer self.allocator.free(url);

        const uri = std.Uri.parse(url) catch return error.HttpRequestFailed;
        var req = self.http_client.request(method, uri, .{
            .extra_headers = &.{
                .{ .name = "authorization", .value = self.auth_header },
                .{ .name = "content-type", .value = "application/json" },
            },
            .keep_alive = false,
        }) catch return error.HttpRequestFailed;
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = body.len };
        const buf_size = std.math.ceilPowerOfTwo(usize, @max(body.len, 512)) catch 8192;
        const send_buf = self.allocator.alloc(u8, buf_size) catch return error.OutOfMemory;
        defer self.allocator.free(send_buf);
        var send = req.sendBodyUnflushed(send_buf) catch return error.HttpRequestFailed;
        send.writer.writeAll(body) catch return error.HttpRequestFailed;
        send.end() catch return error.HttpRequestFailed;
        if (req.connection) |conn| conn.flush() catch return error.HttpRequestFailed;

        var redirect_buf: [1024]u8 = undefined;
        var response = req.receiveHead(&redirect_buf) catch return error.HttpRequestFailed;
        try checkStatus(response.head.status);
        return self.readResponseBody(&response);
    }

    fn httpDelete(self: *Client, path: []const u8, reason: ?[]const u8, idempotent: bool) !void {
        const url = try self.buildUrl(path);
        defer self.allocator.free(url);

        var extra_headers_buf: [2]http.Header = undefined;
        var header_count: usize = 1;
        extra_headers_buf[0] = .{ .name = "authorization", .value = self.auth_header };
        if (reason) |r| {
            extra_headers_buf[1] = .{ .name = "x-reason", .value = r };
            header_count = 2;
        }

        const result = self.http_client.fetch(.{
            .location = .{ .url = url },
            .method = .DELETE,
            .extra_headers = extra_headers_buf[0..header_count],
            .keep_alive = false,
        }) catch return error.HttpRequestFailed;

        if (result.status == .not_found and idempotent) return;
        try checkStatus(result.status);
    }

    fn healthCheckGet(self: *Client, path: []const u8) !bool {
        const url = try self.buildUrl(path);
        defer self.allocator.free(url);

        const result = self.http_client.fetch(.{
            .location = .{ .url = url },
            .method = .GET,
            .extra_headers = &.{
                .{ .name = "authorization", .value = self.auth_header },
            },
            .keep_alive = false,
        }) catch return error.HttpRequestFailed;

        return result.status == .ok;
    }

    //
    // Path & URL helpers
    //

    fn buildUrl(self: *Client, path: []const u8) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.options.endpoint, path });
    }

    fn encodePath1(self: *Client, prefix: []const u8, seg1: []const u8) ![]u8 {
        const enc1 = try percentEncode(self.allocator, seg1);
        defer self.allocator.free(enc1);
        return std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ prefix, enc1 });
    }

    fn encodePath2(self: *Client, prefix: []const u8, seg1: []const u8, seg2: []const u8) ![]u8 {
        const enc1 = try percentEncode(self.allocator, seg1);
        defer self.allocator.free(enc1);
        const enc2 = try percentEncode(self.allocator, seg2);
        defer self.allocator.free(enc2);
        return std.fmt.allocPrint(self.allocator, "{s}/{s}/{s}", .{ prefix, enc1, enc2 });
    }

    fn encodePath3(self: *Client, prefix: []const u8, seg1: []const u8, seg2: []const u8, seg3: []const u8) ![]u8 {
        const enc1 = try percentEncode(self.allocator, seg1);
        defer self.allocator.free(enc1);
        const enc2 = try percentEncode(self.allocator, seg2);
        defer self.allocator.free(enc2);
        const enc3 = try percentEncode(self.allocator, seg3);
        defer self.allocator.free(enc3);
        return std.fmt.allocPrint(self.allocator, "{s}/{s}/{s}/{s}", .{ prefix, enc1, enc2, enc3 });
    }
};

//
// Filters
//

fn filterQueuesByType(queues: []responses.QueueInfo, queue_type: []const u8) []responses.QueueInfo {
    var count: usize = 0;
    for (queues) |q| {
        if (q.type) |t| {
            if (std.mem.eql(u8, t, queue_type)) {
                queues[count] = q;
                count += 1;
            }
        }
    }
    return queues[0..count];
}

fn filterPoliciesByTarget(policies: []responses.PolicyInfo, target: []const u8) []responses.PolicyInfo {
    var count: usize = 0;
    for (policies) |p| {
        if (p.@"apply-to") |at| {
            if (std.mem.eql(u8, at, target)) {
                policies[count] = p;
                count += 1;
            }
        }
    }
    return policies[0..count];
}

fn filterMatchingPolicies(policies: []responses.PolicyInfo, name: []const u8) []responses.PolicyInfo {
    var count: usize = 0;
    for (policies) |p| {
        if (p.pattern) |pattern| {
            if (regexMatch(pattern, name)) {
                policies[count] = p;
                count += 1;
            }
        }
    }
    return policies[0..count];
}

const Regex = @import("regex").Regex;

fn regexMatch(pattern: []const u8, input: []const u8) bool {
    // page_allocator is intentional: these are short-lived compilations during
    // client-side filtering, and we don't have access to the Client's allocator
    // from a free function. The regex library uses a Thompson NFA (linear time).
    var re = Regex.compile(std.heap.page_allocator, pattern) catch return false;
    defer re.deinit();
    return re.partialMatch(input) catch false;
}

//
// Utilities
//

/// Percent-encodes a string for use in URL path segments (RFC 3986).
pub fn percentEncode(allocator: Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    for (input) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            try result.append(allocator, c);
        } else {
            var hex_buf: [3]u8 = undefined;
            _ = std.fmt.bufPrint(&hex_buf, "%{X:0>2}", .{c}) catch unreachable;
            try result.appendSlice(allocator, &hex_buf);
        }
    }
    return result.toOwnedSlice(allocator);
}

//
// Unit Tests
//

test "percent encode: passthrough for safe characters" {
    const allocator = std.testing.allocator;
    const result = try percentEncode(allocator, "hello-world_123");
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "hello-world_123", result);
}

//
// Unit Tests
//

test "percent encode: encodes slash" {
    const allocator = std.testing.allocator;
    const result = try percentEncode(allocator, "/");
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "%2F", result);
}

//
// Unit Tests
//

test "percent encode: encodes spaces and special chars" {
    const allocator = std.testing.allocator;
    const result = try percentEncode(allocator, "my vhost");
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "my%20vhost", result);
}

//
// Unit Tests
//

test "percent encode: encodes at sign and hash" {
    const allocator = std.testing.allocator;
    const result = try percentEncode(allocator, "user@host#1");
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "user%40host%231", result);
}

test "client init and deinit" {
    const allocator = std.testing.allocator;
    var threaded_io: std.Io.Threaded = .init(allocator, .{});
    defer threaded_io.deinit();
    var client = try Client.init(allocator, threaded_io.io(), .{});
    defer client.deinit();
    try std.testing.expect(std.mem.startsWith(u8, client.auth_header, "Basic "));
}

test "client init with custom options" {
    const allocator = std.testing.allocator;
    var threaded_io: std.Io.Threaded = .init(allocator, .{});
    defer threaded_io.deinit();
    var client = try Client.init(allocator, threaded_io.io(), .{
        .endpoint = "http://rabbitmq:15672/api",
        .username = "admin",
        .password = "secret",
    });
    defer client.deinit();
    try std.testing.expectEqualSlices(u8, "http://rabbitmq:15672/api", client.options.endpoint);
}
