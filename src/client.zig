// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

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
    Forbidden,
    ServerError,
    BadRequest,
    Conflict,
    OutOfMemory,
    Unexpected,
};

pub const ClientOptions = struct {
    endpoint: []const u8 = "http://localhost:15672/api",
    username: []const u8 = "guest",
    password: []const u8 = "guest",
    /// Absolute path to a CA bundle file in the PEM format. When set, the system trust
    /// store is bypassed.
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
            // Pre-set `now` so the http.Client uses our pre-loaded bundle instead
            // of rescanning system trust roots on first use.
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

    /// Returns a heap-allocated copy of the broker version. Caller owns the slice.
    /// Uses the lightweight /version endpoint instead of /overview.
    pub fn serverVersion(self: *Client) ![]u8 {
        const body = try self.httpGet("/version");
        defer self.allocator.free(body);
        // Body is a JSON-quoted string like "\"4.3.0\"". Strip the quotes.
        if (body.len < 2 or body[0] != '"' or body[body.len - 1] != '"') return error.JsonParseFailed;
        return self.allocator.dupe(u8, body[1 .. body.len - 1]);
    }

    pub fn getClusterName(self: *Client) !std.json.Parsed(responses.ClusterIdentity) {
        return self.getJson(responses.ClusterIdentity, "/cluster-name");
    }

    pub fn setClusterName(self: *Client, name: []const u8) !void {
        try self.putJson("/cluster-name", requests.ClusterNameParams{ .name = name });
    }

    /// Cluster tags are stored as a global runtime parameter named "cluster_tags".
    pub fn getClusterTags(self: *Client) !std.json.Parsed(responses.GlobalParameter) {
        return self.getGlobalParameter("cluster_tags");
    }

    pub fn setClusterTags(self: *Client, tags: std.json.Value) !void {
        try self.upsertGlobalParameter("cluster_tags", .{ .value = tags });
    }

    pub fn clearClusterTags(self: *Client) !void {
        try self.deleteGlobalParameter("cluster_tags", true);
    }

    /// Probes /whoami; succeeds when the broker is reachable and credentials work.
    pub fn probeReachability(self: *Client) responses.ReachabilityProbeOutcome {
        const result = self.healthCheckGet("/whoami") catch return .{ .successful = false };
        return .{ .successful = result };
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
        const path = try self.encodePathVar("/nodes/{s}/memory", &.{name});
        defer self.allocator.free(path);
        return self.getJson(responses.NodeMemoryFootprint, path);
    }

    pub fn getNodeMemoryFootprintRelative(self: *Client, name: []const u8) !std.json.Parsed(std.json.Value) {
        const path = try self.encodePathVar("/nodes/{s}/memory/relative", &.{name});
        defer self.allocator.free(path);
        return self.getJson(std.json.Value, path);
    }

    /// The management API does not expose a per-node plugin endpoint, so this
    /// returns the `enabled_plugins` list from the node's info endpoint.
    /// Caller owns the returned arena; access plugins via `result.value`.
    pub fn listNodePlugins(self: *Client, node: []const u8) !std.json.Parsed([][]const u8) {
        const info = try self.getNodeInfo(node);
        defer info.deinit();
        const enabled = info.value.enabled_plugins orelse &.{};
        return self.dupePluginList(enabled);
    }

    /// Returns the union of `enabled_plugins` across all cluster nodes,
    /// sorted and deduplicated.
    pub fn listAllClusterPlugins(self: *Client) !std.json.Parsed([][]const u8) {
        const nodes = try self.listNodes();
        defer nodes.deinit();

        var seen: std.StringHashMapUnmanaged(void) = .empty;
        defer seen.deinit(self.allocator);
        for (nodes.value) |n| {
            const enabled = n.enabled_plugins orelse continue;
            for (enabled) |p| try seen.put(self.allocator, p, {});
        }

        var unique: std.ArrayList([]const u8) = .empty;
        defer unique.deinit(self.allocator);
        var it = seen.keyIterator();
        while (it.next()) |k| try unique.append(self.allocator, k.*);
        std.mem.sort([]const u8, unique.items, {}, lexicallyLess);

        return self.dupePluginList(unique.items);
    }

    fn dupePluginList(self: *Client, source: []const []const u8) !std.json.Parsed([][]const u8) {
        const arena = try self.allocator.create(std.heap.ArenaAllocator);
        errdefer self.allocator.destroy(arena);
        arena.* = .init(self.allocator);
        errdefer arena.deinit();

        const a = arena.allocator();
        const out = try a.alloc([]const u8, source.len);
        for (source, 0..) |s, i| out[i] = try a.dupe(u8, s);

        return .{ .arena = arena, .value = out };
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

    /// PUT /vhosts/:name performs an upsert; this method is provided for callers who
    /// want to make the intent clear.
    pub fn updateVhost(self: *Client, name: []const u8, params: requests.VirtualHostParams) !void {
        return self.createVhost(name, params);
    }

    pub fn deleteVhost(self: *Client, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath1("/vhosts", name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn enableVhostDeletionProtection(self: *Client, name: []const u8) !void {
        const path = try self.encodePathVar("/vhosts/{s}/deletion/protection", &.{name});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    pub fn disableVhostDeletionProtection(self: *Client, name: []const u8) !void {
        const path = try self.encodePathVar("/vhosts/{s}/deletion/protection", &.{name});
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    pub fn startVhostOnNode(self: *Client, vhost: []const u8, node: []const u8) !void {
        const path = try self.encodePathVar("/vhosts/{s}/start/{s}", &.{ vhost, node });
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    pub fn alivenessTest(self: *Client, vhost: []const u8) !bool {
        const path = try self.encodePath1("/aliveness-test", vhost);
        defer self.allocator.free(path);
        return self.healthCheckGet(path);
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
        const path = try self.encodePathVar("/vhosts/{s}/connections", &.{vhost});
        defer self.allocator.free(path);
        return self.getJson([]responses.ConnectionInfo, path);
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
        const path = try self.encodePathVar("/connections/username/{s}", &.{username});
        defer self.allocator.free(path);
        return self.getJson([]responses.UserConnectionInfo, path);
    }

    pub fn closeUserConnections(self: *Client, username: []const u8, reason: ?[]const u8, idempotent: bool) !void {
        const path = try self.encodePathVar("/connections/username/{s}", &.{username});
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
        const path = try self.encodePathVar("/vhosts/{s}/channels", &.{vhost});
        defer self.allocator.free(path);
        return self.getJson([]responses.ChannelInfo, path);
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
        const path = try self.encodePathVar("/connections/{s}/channels", &.{connection});
        defer self.allocator.free(path);
        return self.getJson([]responses.ChannelInfo, path);
    }

    /// Lists AMQP 1.0 sessions multiplexed onto a single connection.
    pub fn listSessionsOnConnection(self: *Client, connection: []const u8) !std.json.Parsed(std.json.Value) {
        const path = try self.encodePathVar("/connections/{s}/sessions", &.{connection});
        defer self.allocator.free(path);
        return self.getJson(std.json.Value, path);
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
    // Queues, Streams
    //

    /// Requires RabbitMQ 3.13 or later. Earlier versions return 404.
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

    pub fn listQueuesOfType(self: *Client, qt: commons.QueueType) !std.json.Parsed([]responses.QueueInfo) {
        var result = try self.listQueues();
        result.value = filterQueuesByType(result.value, qt.toApiString());
        return result;
    }

    pub fn listQueuesByVhostOfType(self: *Client, vhost: []const u8, qt: commons.QueueType) !std.json.Parsed([]responses.QueueInfo) {
        var result = try self.listQueuesByVhost(vhost);
        result.value = filterQueuesByType(result.value, qt.toApiString());
        return result;
    }

    pub fn listClassicQueues(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesOfType(.classic);
    }

    pub fn listClassicQueuesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByVhostOfType(vhost, .classic);
    }

    pub fn listQuorumQueues(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesOfType(.quorum);
    }

    pub fn listQuorumQueuesByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByVhostOfType(vhost, .quorum);
    }

    pub fn listStreams(self: *Client) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesOfType(.stream);
    }

    pub fn listStreamsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        return self.listQueuesByVhostOfType(vhost, .stream);
    }

    /// Filtering happens client-side, so `page_count` and `total_count` reflect
    /// all queue types, not just streams.
    pub fn listStreamsPaged(self: *Client, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.QueueInfo)) {
        var result = try self.listQueuesPaged(params);
        result.value.items = filterQueuesByType(result.value.items, "stream");
        return result;
    }

    pub fn listStreamsByVhostPaged(self: *Client, vhost: []const u8, params: requests.PaginationParams) !std.json.Parsed(responses.PaginatedResponse(responses.QueueInfo)) {
        var result = try self.listQueuesByVhostPaged(vhost, params);
        result.value.items = filterQueuesByType(result.value.items, "stream");
        return result;
    }

    pub fn getQueueInfo(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.QueueInfo) {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        return self.getJson(responses.QueueInfo, path);
    }

    pub fn getStreamInfo(self: *Client, vhost: []const u8, name: []const u8) !std.json.Parsed(responses.QueueInfo) {
        return self.getQueueInfo(vhost, name);
    }

    pub fn declareQueue(self: *Client, vhost: []const u8, name: []const u8, params: requests.QueueParams) !void {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        try self.putJson(path, params);
    }

    pub fn declareClassicQueue(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareQueue(vhost, name, requests.QueueParams.newDurableClassicQueue());
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

    pub fn declareStreamWithArguments(self: *Client, vhost: []const u8, name: []const u8, arguments: std.json.Value) !void {
        try self.declareQueue(vhost, name, .{ .arguments = arguments });
    }

    pub fn deleteQueue(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/queues", vhost, name);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn deleteStream(self: *Client, vhost: []const u8, name: []const u8, idempotent: bool) !void {
        return self.deleteQueue(vhost, name, idempotent);
    }

    pub fn deleteQueues(self: *Client, vhost: []const u8, names: []const []const u8, idempotent: bool) !void {
        for (names) |name| {
            try self.deleteQueue(vhost, name, idempotent);
        }
    }

    pub fn purgeQueue(self: *Client, vhost: []const u8, name: []const u8) !void {
        const path = try self.encodePathVar("/queues/{s}/{s}/contents", &.{ vhost, name });
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
        try self.declareExchange(vhost, name, requests.ExchangeParams.durableFanout());
    }

    pub fn declareTopicExchange(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareExchange(vhost, name, requests.ExchangeParams.durableTopic());
    }

    pub fn declareDirectExchange(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareExchange(vhost, name, requests.ExchangeParams.durableDirect());
    }

    pub fn declareHeadersExchange(self: *Client, vhost: []const u8, name: []const u8) !void {
        try self.declareExchange(vhost, name, requests.ExchangeParams.durableHeaders());
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
        const path = try self.encodePathVar("/queues/{s}/{s}/bindings", &.{ vhost, queue });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listExchangeBindingsWithSource(self: *Client, vhost: []const u8, exchange: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const path = try self.encodePathVar("/exchanges/{s}/{s}/bindings/source", &.{ vhost, exchange });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listExchangeBindingsWithDestination(self: *Client, vhost: []const u8, exchange: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const path = try self.encodePathVar("/exchanges/{s}/{s}/bindings/destination", &.{ vhost, exchange });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listBindingsBetweenExchangeAndQueue(self: *Client, vhost: []const u8, exchange: []const u8, queue: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const path = try self.encodePathVar("/bindings/{s}/e/{s}/q/{s}", &.{ vhost, exchange, queue });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn listExchangeBindingsBetween(self: *Client, vhost: []const u8, source: []const u8, destination: []const u8) !std.json.Parsed([]responses.BindingInfo) {
        const path = try self.encodePathVar("/bindings/{s}/e/{s}/e/{s}", &.{ vhost, source, destination });
        defer self.allocator.free(path);
        return self.getJson([]responses.BindingInfo, path);
    }

    pub fn bindQueue(self: *Client, vhost: []const u8, exchange: []const u8, queue: []const u8, params: requests.BindingParams) !void {
        const path = try self.encodePathVar("/bindings/{s}/e/{s}/q/{s}", &.{ vhost, exchange, queue });
        defer self.allocator.free(path);
        try self.postJson(path, params);
    }

    pub fn bindExchange(self: *Client, vhost: []const u8, source: []const u8, destination: []const u8, params: requests.BindingParams) !void {
        const path = try self.encodePathVar("/bindings/{s}/e/{s}/e/{s}", &.{ vhost, source, destination });
        defer self.allocator.free(path);
        try self.postJson(path, params);
    }

    pub fn deleteQueueBinding(self: *Client, vhost: []const u8, exchange: []const u8, queue: []const u8, properties_key: []const u8) !void {
        const path = try self.encodePathVar("/bindings/{s}/e/{s}/q/{s}/{s}", &.{ vhost, exchange, queue, properties_key });
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
    }

    pub fn deleteExchangeBinding(self: *Client, vhost: []const u8, source: []const u8, destination: []const u8, properties_key: []const u8) !void {
        const path = try self.encodePathVar("/bindings/{s}/e/{s}/e/{s}/{s}", &.{ vhost, source, destination, properties_key });
        defer self.allocator.free(path);
        try self.httpDelete(path, null, false);
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

    pub fn listUserQueues(self: *Client, username: []const u8) !std.json.Parsed([]responses.QueueInfo) {
        const path = try self.encodePathVar("/users/{s}/queues", &.{username});
        defer self.allocator.free(path);
        return self.getJson([]responses.QueueInfo, path);
    }

    //
    // Permissions
    //

    pub fn listPermissions(self: *Client) !std.json.Parsed([]responses.PermissionInfo) {
        return self.getJson([]responses.PermissionInfo, "/permissions");
    }

    pub fn listPermissionsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.PermissionInfo) {
        const path = try self.encodePathVar("/vhosts/{s}/permissions", &.{vhost});
        defer self.allocator.free(path);
        return self.getJson([]responses.PermissionInfo, path);
    }

    pub fn listPermissionsOf(self: *Client, username: []const u8) !std.json.Parsed([]responses.PermissionInfo) {
        const path = try self.encodePathVar("/users/{s}/permissions", &.{username});
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

    pub fn declarePermissions(self: *Client, vhost: []const u8, username: []const u8, params: requests.PermissionParams) !void {
        return self.grantPermissions(vhost, username, params);
    }

    pub fn clearPermissions(self: *Client, vhost: []const u8, username: []const u8, idempotent: bool) !void {
        const path = try self.encodePath2("/permissions", vhost, username);
        defer self.allocator.free(path);
        try self.httpDelete(path, null, idempotent);
    }

    pub fn grantFullPermissions(self: *Client, vhost: []const u8, username: []const u8) !void {
        try self.grantPermissions(vhost, username, requests.PermissionParams.fullAccess());
    }

    //
    // Topic Permissions
    //

    pub fn listTopicPermissions(self: *Client) !std.json.Parsed([]responses.TopicPermissionInfo) {
        return self.getJson([]responses.TopicPermissionInfo, "/topic-permissions");
    }

    pub fn listTopicPermissionsByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.TopicPermissionInfo) {
        const path = try self.encodePathVar("/vhosts/{s}/topic-permissions", &.{vhost});
        defer self.allocator.free(path);
        return self.getJson([]responses.TopicPermissionInfo, path);
    }

    pub fn listTopicPermissionsOf(self: *Client, username: []const u8) !std.json.Parsed([]responses.TopicPermissionInfo) {
        const path = try self.encodePathVar("/users/{s}/topic-permissions", &.{username});
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

    pub fn declareTopicPermissions(self: *Client, vhost: []const u8, username: []const u8, params: requests.TopicPermissionParams) !void {
        return self.grantTopicPermissions(vhost, username, params);
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
        var result = try self.listPoliciesByVhost(vhost);
        result.value = filterPoliciesByTarget(result.value, target.toApiString());
        return result;
    }

    pub fn listOperatorPoliciesForTarget(self: *Client, vhost: []const u8, target: commons.PolicyTarget) !std.json.Parsed([]responses.PolicyInfo) {
        var result = try self.listOperatorPoliciesByVhost(vhost);
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

    pub fn healthCheckProtocolListener(self: *Client, protocol: commons.SupportedProtocol) !bool {
        const path = try self.encodePathVar("/health/checks/protocol-listener/{s}", &.{protocol.toApiString()});
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

    pub fn healthCheckMetadataStoreInitialized(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/metadata-store/initialized");
    }

    pub fn healthCheckMetadataStoreInitializedWithData(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/metadata-store/initialized/with-data");
    }

    pub fn healthCheckReachedTargetClusterSize(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/reached-target-cluster-size");
    }

    pub fn healthCheckQuorumQueuesWithoutLeaders(self: *Client) !bool {
        return self.healthCheckGet("/health/checks/quorum-queues-without-elected-leaders/all-vhosts/");
    }

    pub fn healthCheckQuorumQueuesWithoutLeadersIn(self: *Client, vhost: []const u8) !bool {
        const path = try self.encodePathVar("/health/checks/quorum-queues-without-elected-leaders/vhost/{s}/", &.{vhost});
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
        const path = try self.encodePathVar("/feature-flags/{s}/enable", &.{name});
        defer self.allocator.free(path);
        try self.httpSend(.PUT, path, "{}");
    }

    /// PUT /feature-flags/all/enable does not exist; the broker only supports
    /// enabling flags one at a time. We discover the disabled stable flags
    /// from /feature-flags and enable each individually.
    pub fn enableAllStableFeatureFlags(self: *Client) !void {
        const flags = try self.listFeatureFlags();
        defer flags.deinit();
        for (flags.value) |f| {
            const state = f.state orelse continue;
            const stability = f.stability orelse continue;
            const name = f.name orelse continue;
            if (!std.mem.eql(u8, state, "disabled")) continue;
            if (!std.mem.eql(u8, stability, "stable")) continue;
            try self.enableFeatureFlag(name);
        }
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

    pub fn exportClusterWideDefinitions(self: *Client) !std.json.Parsed(responses.DefinitionSet) {
        return self.getJson(responses.DefinitionSet, "/definitions");
    }

    pub fn exportVhostDefinitions(self: *Client, vhost: []const u8) !std.json.Parsed(responses.DefinitionSet) {
        const path = try self.encodePath1("/definitions", vhost);
        defer self.allocator.free(path);
        return self.getJson(responses.DefinitionSet, path);
    }

    pub fn exportClusterWideDefinitionsAsString(self: *Client) ![]u8 {
        return self.httpGet("/definitions");
    }

    pub fn exportVhostDefinitionsAsString(self: *Client, vhost: []const u8) ![]u8 {
        const path = try self.encodePath1("/definitions", vhost);
        defer self.allocator.free(path);
        return self.httpGet(path);
    }

    pub fn importClusterWideDefinitions(self: *Client, definitions_json: []const u8) !void {
        try self.httpSend(.POST, "/definitions", definitions_json);
    }

    pub fn importVhostDefinitions(self: *Client, vhost: []const u8, definitions_json: []const u8) !void {
        const path = try self.encodePath1("/definitions", vhost);
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, definitions_json);
    }

    pub fn exportDefinitions(self: *Client) !std.json.Parsed(responses.DefinitionSet) {
        return self.exportClusterWideDefinitions();
    }

    pub fn exportDefinitionsAsString(self: *Client) ![]u8 {
        return self.exportClusterWideDefinitionsAsString();
    }

    pub fn importDefinitions(self: *Client, definitions_json: []const u8) !void {
        return self.importClusterWideDefinitions(definitions_json);
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

    /// /parameters returns parameters across all vhosts; we filter client-side.
    pub fn clearAllRuntimeParametersIn(self: *Client, vhost: []const u8) !void {
        const result = try self.listRuntimeParameters();
        defer result.deinit();
        for (result.value) |p| {
            const v = p.vhost orelse continue;
            if (!std.mem.eql(u8, v, vhost)) continue;
            const c = p.component orelse continue;
            const n = p.name orelse continue;
            try self.deleteRuntimeParameter(c, v, n, true);
        }
    }

    pub fn clearAllRuntimeParameters(self: *Client, vhost: []const u8) !void {
        return self.clearAllRuntimeParametersIn(vhost);
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

    pub fn setUserLimit(self: *Client, username: []const u8, limit: commons.UserLimitTarget, value: i64) !void {
        const path = try self.encodePathVar("/user-limits/{s}/{s}", &.{ username, limit.toApiString() });
        defer self.allocator.free(path);
        try self.putJson(path, requests.LimitParams{ .value = value });
    }

    pub fn clearUserLimit(self: *Client, username: []const u8, limit: commons.UserLimitTarget) !void {
        const path = try self.encodePathVar("/user-limits/{s}/{s}", &.{ username, limit.toApiString() });
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

    pub fn setVhostLimit(self: *Client, vhost: []const u8, limit: commons.VirtualHostLimitTarget, value: i64) !void {
        const path = try self.encodePathVar("/vhost-limits/{s}/{s}", &.{ vhost, limit.toApiString() });
        defer self.allocator.free(path);
        try self.putJson(path, requests.LimitParams{ .value = value });
    }

    pub fn clearVhostLimit(self: *Client, vhost: []const u8, limit: commons.VirtualHostLimitTarget) !void {
        const path = try self.encodePathVar("/vhost-limits/{s}/{s}", &.{ vhost, limit.toApiString() });
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

    pub fn declareFederationUpstreamTyped(self: *Client, vhost: []const u8, name: []const u8, params: requests.TypedFederationUpstreamParams) !void {
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
        const path = try self.encodePathVar("/shovels/vhost/{s}/{s}", &.{ vhost, name });
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

    pub fn restartShovel(self: *Client, vhost: []const u8, name: []const u8) !void {
        const path = try self.encodePathVar("/shovels/vhost/{s}/{s}/restart", &.{ vhost, name });
        defer self.allocator.free(path);
        try self.httpSend(.DELETE, path, null);
    }

    pub fn restartFederationLink(self: *Client, vhost: []const u8, id: []const u8, node: []const u8) !void {
        const path = try self.encodePathVar("/federation-links/vhost/{s}/{s}/{s}/restart", &.{ vhost, id, node });
        defer self.allocator.free(path);
        try self.httpSend(.DELETE, path, null);
    }

    pub fn listDownFederationLinks(self: *Client) !std.json.Parsed([]responses.FederationLink) {
        return self.getJson([]responses.FederationLink, "/federation-links/state/down/");
    }

    pub fn listDownFederationLinksByVhost(self: *Client, vhost: []const u8) !std.json.Parsed([]responses.FederationLink) {
        const path = try self.encodePathVar("/federation-links/{s}/state/down", &.{vhost});
        defer self.allocator.free(path);
        return self.getJson([]responses.FederationLink, path);
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
        const path = try self.encodePathVar("/stream/connections/{s}/{s}/publishers", &.{ vhost, connection });
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
        const path = try self.encodePathVar("/stream/connections/{s}/{s}/consumers", &.{ vhost, connection });
        defer self.allocator.free(path);
        return self.getJson([]responses.StreamConsumerInfo, path);
    }

    //
    // Plugins & Extensions
    //

    /// /extensions returns a heterogeneous array — some entries are
    /// `{"javascript":"..."}` objects, others are empty arrays from plugins
    /// that don't expose a UI extension. The result is left as a raw `Value`.
    pub fn listExtensions(self: *Client) !std.json.Parsed(std.json.Value) {
        return self.getJson(std.json.Value, "/extensions");
    }

    //
    // Authentication
    //

    pub fn getAuthAttempts(self: *Client, node: []const u8) !std.json.Parsed([]responses.AuthAttemptInfo) {
        const path = try self.encodePathVar("/auth/attempts/{s}", &.{node});
        defer self.allocator.free(path);
        return self.getJson([]responses.AuthAttemptInfo, path);
    }

    pub fn getAuthAttemptsBySource(self: *Client, node: []const u8) !std.json.Parsed([]responses.AuthAttemptInfo) {
        const path = try self.encodePathVar("/auth/attempts/{s}/source", &.{node});
        defer self.allocator.free(path);
        return self.getJson([]responses.AuthAttemptInfo, path);
    }

    pub fn clearAuthAttempts(self: *Client, node: []const u8) !void {
        const path = try self.encodePathVar("/auth/attempts/{s}", &.{node});
        defer self.allocator.free(path);
        try self.httpDelete(path, null, true);
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
        const path = try self.encodePathVar("/schema-definition-sync/enable/{s}", &.{node});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    pub fn disableSchemaDefinitionSyncOnNode(self: *Client, node: []const u8) !void {
        const path = try self.encodePathVar("/schema-definition-sync/disable/{s}", &.{node});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, null);
    }

    pub fn getSchemaDefinitionSyncStatusOnNode(self: *Client, node: []const u8) !std.json.Parsed(responses.SchemaReplicationStatus) {
        const path = try self.encodePathVar("/schema-definition-sync/status/{s}", &.{node});
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
        // The HTTP API requires "properties" even when empty.
        const wire = PublishRequest{
            .properties = params.properties orelse .{ .object = .empty },
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
        const path = try self.encodePathVar("/queues/quorum/{s}/{s}/status", &.{ vhost, name });
        defer self.allocator.free(path);
        return self.getJson(std.json.Value, path);
    }

    pub fn addQuorumQueueReplica(self: *Client, vhost: []const u8, name: []const u8, node: []const u8) !void {
        const path = try self.encodePathVar("/queues/quorum/{s}/{s}/replicas/add", &.{ vhost, name });
        defer self.allocator.free(path);
        try self.postJson(path, .{ .node = node });
    }

    pub fn deleteQuorumQueueReplica(self: *Client, vhost: []const u8, name: []const u8, node: []const u8) !void {
        const path = try self.encodePathVar("/queues/quorum/{s}/{s}/replicas/delete", &.{ vhost, name });
        defer self.allocator.free(path);
        try self.postJson(path, .{ .node = node });
    }

    pub fn growQuorumQueueReplicas(self: *Client, node: []const u8) !void {
        const path = try self.encodePathVar("/queues/quorum/replicas/on/{s}/grow", &.{node});
        defer self.allocator.free(path);
        try self.httpSend(.POST, path, "{}");
    }

    pub fn shrinkQuorumQueueReplicas(self: *Client, node: []const u8) !void {
        const path = try self.encodePathVar("/queues/quorum/replicas/on/{s}/shrink", &.{node});
        defer self.allocator.free(path);
        try self.httpSend(.DELETE, path, null);
    }

    //
    // Password Hashing
    //

    pub fn hashPassword(self: *Client, password: []const u8) !std.json.Parsed(responses.HashPasswordResult) {
        const path = try self.encodePathVar("/auth/hash_password/{s}", &.{password});
        defer self.allocator.free(path);
        return self.getJson(responses.HashPasswordResult, path);
    }

    //
    // Internal HTTP & JSON helpers
    //

    const json_stringify_options: std.json.Stringify.Options = .{ .emit_null_optional_fields = false };
    const json_parse_options: std.json.ParseOptions = .{ .ignore_unknown_fields = true, .allocate = .alloc_always };

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
            .forbidden => return error.Forbidden,
            .not_found => return error.NotFound,
            .conflict => return error.Conflict,
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
            .headers = .{ .accept_encoding = .{ .override = "identity" } },
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
            .headers = .{ .accept_encoding = .{ .override = "identity" } },
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

    /// Percent-encodes each segment and substitutes them into the format string in order.
    /// The format string must use `{s}` for every encoded segment.
    fn encodePathVar(self: *Client, comptime fmt: []const u8, segments: []const []const u8) ![]u8 {
        const encoded = try self.allocator.alloc([]u8, segments.len);
        var written: usize = 0;
        defer {
            for (encoded[0..written]) |e| self.allocator.free(e);
            self.allocator.free(encoded);
        }
        for (segments, 0..) |s, i| {
            encoded[i] = try percentEncode(self.allocator, s);
            written = i + 1;
        }
        return formatWithSegments(self.allocator, fmt, encoded);
    }
};

fn formatWithSegments(allocator: Allocator, comptime fmt: []const u8, segments: []const []const u8) ![]u8 {
    var total: usize = 0;
    var idx: usize = 0;
    var seg_i: usize = 0;
    const placeholder = "{s}";
    while (idx < fmt.len) : (idx += 1) {
        if (idx + placeholder.len <= fmt.len and std.mem.eql(u8, fmt[idx .. idx + placeholder.len], placeholder)) {
            total += segments[seg_i].len;
            seg_i += 1;
            idx += placeholder.len - 1;
        } else {
            total += 1;
        }
    }
    const out = try allocator.alloc(u8, total);
    var w: usize = 0;
    idx = 0;
    seg_i = 0;
    while (idx < fmt.len) : (idx += 1) {
        if (idx + placeholder.len <= fmt.len and std.mem.eql(u8, fmt[idx .. idx + placeholder.len], placeholder)) {
            const seg = segments[seg_i];
            @memcpy(out[w..][0..seg.len], seg);
            w += seg.len;
            seg_i += 1;
            idx += placeholder.len - 1;
        } else {
            out[w] = fmt[idx];
            w += 1;
        }
    }
    return out;
}

//
// Client-side filters
//

fn lexicallyLess(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn filterQueuesByType(queues: []responses.QueueInfo, queue_type: []const u8) []responses.QueueInfo {
    var count: usize = 0;
    for (queues) |q| {
        const t = q.type orelse continue;
        if (std.mem.eql(u8, t, queue_type)) {
            queues[count] = q;
            count += 1;
        }
    }
    return queues[0..count];
}

fn filterPoliciesByTarget(policies: []responses.PolicyInfo, target: []const u8) []responses.PolicyInfo {
    var count: usize = 0;
    for (policies) |p| {
        const at = p.@"apply-to" orelse continue;
        if (std.mem.eql(u8, at, target)) {
            policies[count] = p;
            count += 1;
        }
    }
    return policies[0..count];
}

fn filterMatchingPolicies(policies: []responses.PolicyInfo, name: []const u8) []responses.PolicyInfo {
    var count: usize = 0;
    for (policies) |p| {
        const pattern = p.pattern orelse continue;
        if (regexMatch(pattern, name)) {
            policies[count] = p;
            count += 1;
        }
    }
    return policies[0..count];
}

const Regex = @import("regex").Regex;

fn regexMatch(pattern: []const u8, input: []const u8) bool {
    // page_allocator is intentional: the regex library's internal allocator
    // is not exposed through the Regex type, and these compilations are
    // short-lived during client-side filtering.
    var re = Regex.compile(std.heap.page_allocator, pattern) catch return false;
    defer re.deinit();
    return re.partialMatch(input) catch false;
}

//
// Utilities
//

/// Percent-encodes a string for a URL path segment using the RFC 3986 unreserved set.
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

const testing = std.testing;

test "percent encode passthrough for unreserved characters" {
    const result = try percentEncode(testing.allocator, "hello-world_123.~");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "hello-world_123.~", result);
}

test "percent encode encodes slash" {
    const result = try percentEncode(testing.allocator, "/");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "%2F", result);
}

test "percent encode encodes spaces and special chars" {
    const result = try percentEncode(testing.allocator, "my vhost");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "my%20vhost", result);
}

test "percent encode encodes at sign and hash" {
    const result = try percentEncode(testing.allocator, "user@host#1");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "user%40host%231", result);
}

test "percent encode preserves the empty string" {
    const result = try percentEncode(testing.allocator, "");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "", result);
}

test "percent encode handles UTF-8 bytes" {
    // Each multi-byte UTF-8 byte must be percent-encoded individually.
    const result = try percentEncode(testing.allocator, "café");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "caf%C3%A9", result);
}

test "percent encode encodes plus and equals" {
    const result = try percentEncode(testing.allocator, "a+b=c&d");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "a%2Bb%3Dc%26d", result);
}

test "formatWithSegments substitutes encoded segments in order" {
    const out = try formatWithSegments(testing.allocator, "/a/{s}/b/{s}", &.{ "x", "y" });
    defer testing.allocator.free(out);
    try testing.expectEqualSlices(u8, "/a/x/b/y", out);
}

test "client init produces a Basic auth header" {
    var threaded_io: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded_io.deinit();
    var client = try Client.init(testing.allocator, threaded_io.io(), .{});
    defer client.deinit();
    try testing.expect(std.mem.startsWith(u8, client.auth_header, "Basic "));
}

test "client init preserves custom endpoint" {
    var threaded_io: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded_io.deinit();
    var client = try Client.init(testing.allocator, threaded_io.io(), .{
        .endpoint = "http://rabbitmq:15672/api",
        .username = "admin",
        .password = "secret",
    });
    defer client.deinit();
    try testing.expectEqualSlices(u8, "http://rabbitmq:15672/api", client.options.endpoint);
}

test "filterQueuesByType selects only the requested type" {
    var queues = [_]responses.QueueInfo{
        .{ .name = "a", .type = "classic" },
        .{ .name = "b", .type = "quorum" },
        .{ .name = "c", .type = "stream" },
        .{ .name = "d", .type = "quorum" },
    };
    const filtered = filterQueuesByType(&queues, "quorum");
    try testing.expectEqual(@as(usize, 2), filtered.len);
    try testing.expectEqualStrings("b", filtered[0].name);
    try testing.expectEqualStrings("d", filtered[1].name);
}

test "filterPoliciesByTarget keeps only matching apply-to" {
    var policies = [_]responses.PolicyInfo{
        .{ .name = "p1", .@"apply-to" = "queues" },
        .{ .name = "p2", .@"apply-to" = "exchanges" },
        .{ .name = "p3", .@"apply-to" = "queues" },
    };
    const filtered = filterPoliciesByTarget(&policies, "queues");
    try testing.expectEqual(@as(usize, 2), filtered.len);
}

test "filterMatchingPolicies matches name against pattern" {
    var policies = [_]responses.PolicyInfo{
        .{ .name = "p1", .pattern = "^logs\\." },
        .{ .name = "p2", .pattern = "^events\\." },
        .{ .name = "p3", .pattern = "" },
    };
    const filtered = filterMatchingPolicies(&policies, "logs.app");
    try testing.expectEqual(@as(usize, 2), filtered.len);
    try testing.expectEqualStrings("p1", filtered[0].name.?);
    try testing.expectEqualStrings("p3", filtered[1].name.?);
}

test "regexMatch returns false on invalid pattern" {
    try testing.expect(!regexMatch("[invalid(", "anything"));
}
