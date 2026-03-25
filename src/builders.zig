const std = @import("std");
const Allocator = std.mem.Allocator;
const ObjectMap = std.json.ObjectMap;
const Value = std.json.Value;
const commons = @import("commons.zig");

//
// XArgumentsBuilder
//

pub const XArgumentsBuilder = struct {
    map: ObjectMap,
    allocator: Allocator,
    failed: bool = false,

    pub fn init(allocator: Allocator) XArgumentsBuilder {
        return .{ .map = ObjectMap.init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *XArgumentsBuilder) void {
        self.map.deinit();
    }

    pub fn messageTtl(self: *XArgumentsBuilder, millis: i64) *XArgumentsBuilder {
        self.put("x-message-ttl", .{ .integer = millis });
        return self;
    }

    pub fn queueTtl(self: *XArgumentsBuilder, millis: i64) *XArgumentsBuilder {
        self.put("x-expires", .{ .integer = millis });
        return self;
    }

    pub fn maxLength(self: *XArgumentsBuilder, max: i64) *XArgumentsBuilder {
        self.put("x-max-length", .{ .integer = max });
        return self;
    }

    pub fn maxLengthBytes(self: *XArgumentsBuilder, max_bytes: i64) *XArgumentsBuilder {
        self.put("x-max-length-bytes", .{ .integer = max_bytes });
        return self;
    }

    pub fn deadLetterExchange(self: *XArgumentsBuilder, exchange: []const u8) *XArgumentsBuilder {
        self.put("x-dead-letter-exchange", .{ .string = exchange });
        return self;
    }

    pub fn deadLetterRoutingKey(self: *XArgumentsBuilder, key: []const u8) *XArgumentsBuilder {
        self.put("x-dead-letter-routing-key", .{ .string = key });
        return self;
    }

    pub fn overflowDropHead(self: *XArgumentsBuilder) *XArgumentsBuilder {
        self.put("x-overflow", .{ .string = "drop-head" });
        return self;
    }

    pub fn overflowRejectPublish(self: *XArgumentsBuilder) *XArgumentsBuilder {
        self.put("x-overflow", .{ .string = "reject-publish" });
        return self;
    }

    pub fn overflowRejectPublishDlx(self: *XArgumentsBuilder) *XArgumentsBuilder {
        self.put("x-overflow", .{ .string = "reject-publish-dlx" });
        return self;
    }

    pub fn maxPriority(self: *XArgumentsBuilder, max: i64) *XArgumentsBuilder {
        self.put("x-max-priority", .{ .integer = max });
        return self;
    }

    pub fn quorumInitialGroupSize(self: *XArgumentsBuilder, size: i64) *XArgumentsBuilder {
        self.put("x-quorum-initial-group-size", .{ .integer = size });
        return self;
    }

    pub fn quorumTargetGroupSize(self: *XArgumentsBuilder, size: i64) *XArgumentsBuilder {
        self.put("x-quorum-target-group-size", .{ .integer = size });
        return self;
    }

    pub fn deliveryLimit(self: *XArgumentsBuilder, limit: i64) *XArgumentsBuilder {
        self.put("x-delivery-limit", .{ .integer = limit });
        return self;
    }

    pub fn singleActiveConsumer(self: *XArgumentsBuilder, enabled: bool) *XArgumentsBuilder {
        self.put("x-single-active-consumer", .{ .bool = enabled });
        return self;
    }

    pub fn queueLeaderLocator(self: *XArgumentsBuilder, locator: commons.QueueLeaderLocator) *XArgumentsBuilder {
        self.put("x-queue-leader-locator", .{ .string = locator.toApiString() });
        return self;
    }

    pub fn deadLetterStrategy(self: *XArgumentsBuilder, strategy: commons.DeadLetterStrategy) *XArgumentsBuilder {
        self.put("x-dead-letter-strategy", .{ .string = strategy.toApiString() });
        return self;
    }

    pub fn streamMaxSegmentSizeBytes(self: *XArgumentsBuilder, bytes: i64) *XArgumentsBuilder {
        self.put("x-stream-max-segment-size-bytes", .{ .integer = bytes });
        return self;
    }

    pub fn streamFilterSizeBytes(self: *XArgumentsBuilder, bytes: i64) *XArgumentsBuilder {
        self.put("x-stream-filter-size-bytes", .{ .integer = bytes });
        return self;
    }

    pub fn custom(self: *XArgumentsBuilder, key: []const u8, value: Value) *XArgumentsBuilder {
        self.put(key, value);
        return self;
    }

    pub fn build(self: *const XArgumentsBuilder) Allocator.Error!Value {
        if (self.failed) return error.OutOfMemory;
        return .{ .object = self.map };
    }

    fn put(self: *XArgumentsBuilder, key: []const u8, value: Value) void {
        self.map.put(key, value) catch {
            self.failed = true;
        };
    }
};

//
// PolicyDefinitionBuilder
//

pub const PolicyDefinitionBuilder = struct {
    map: ObjectMap,
    allocator: Allocator,
    failed: bool = false,

    pub fn init(allocator: Allocator) PolicyDefinitionBuilder {
        return .{ .map = ObjectMap.init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *PolicyDefinitionBuilder) void {
        self.map.deinit();
    }

    pub fn messageTtl(self: *PolicyDefinitionBuilder, millis: i64) *PolicyDefinitionBuilder {
        self.put("message-ttl", .{ .integer = millis });
        return self;
    }

    pub fn maxLength(self: *PolicyDefinitionBuilder, max: i64) *PolicyDefinitionBuilder {
        self.put("max-length", .{ .integer = max });
        return self;
    }

    pub fn maxLengthBytes(self: *PolicyDefinitionBuilder, max_bytes: i64) *PolicyDefinitionBuilder {
        self.put("max-length-bytes", .{ .integer = max_bytes });
        return self;
    }

    pub fn deadLetterExchange(self: *PolicyDefinitionBuilder, exchange: []const u8) *PolicyDefinitionBuilder {
        self.put("dead-letter-exchange", .{ .string = exchange });
        return self;
    }

    pub fn deadLetterRoutingKey(self: *PolicyDefinitionBuilder, key: []const u8) *PolicyDefinitionBuilder {
        self.put("dead-letter-routing-key", .{ .string = key });
        return self;
    }

    pub fn overflowDropHead(self: *PolicyDefinitionBuilder) *PolicyDefinitionBuilder {
        self.put("overflow", .{ .string = "drop-head" });
        return self;
    }

    pub fn overflowRejectPublish(self: *PolicyDefinitionBuilder) *PolicyDefinitionBuilder {
        self.put("overflow", .{ .string = "reject-publish" });
        return self;
    }

    pub fn deliveryLimit(self: *PolicyDefinitionBuilder, limit: i64) *PolicyDefinitionBuilder {
        self.put("delivery-limit", .{ .integer = limit });
        return self;
    }

    pub fn custom(self: *PolicyDefinitionBuilder, key: []const u8, value: Value) *PolicyDefinitionBuilder {
        self.put(key, value);
        return self;
    }

    pub fn build(self: *const PolicyDefinitionBuilder) Allocator.Error!Value {
        if (self.failed) return error.OutOfMemory;
        return .{ .object = self.map };
    }

    fn put(self: *PolicyDefinitionBuilder, key: []const u8, value: Value) void {
        self.map.put(key, value) catch {
            self.failed = true;
        };
    }
};

//
// Unit Tests
//

const testing = std.testing;

test "XArgumentsBuilder: empty build returns empty object" {
    var b = XArgumentsBuilder.init(testing.allocator);
    defer b.deinit();
    const v = try b.build();
    try testing.expect(v.object.count() == 0);
}

test "XArgumentsBuilder: chained methods" {
    var b = XArgumentsBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.messageTtl(60000).maxLength(1000).deadLetterExchange("dlx").singleActiveConsumer(true);
    const v = try b.build();
    try testing.expect(v.object.count() == 4);
    try testing.expectEqual(@as(i64, 60000), v.object.get("x-message-ttl").?.integer);
    try testing.expectEqual(@as(i64, 1000), v.object.get("x-max-length").?.integer);
    try testing.expectEqualStrings("dlx", v.object.get("x-dead-letter-exchange").?.string);
    try testing.expect(v.object.get("x-single-active-consumer").?.bool);
}

test "XArgumentsBuilder: overflow variants" {
    var b = XArgumentsBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.overflowRejectPublish();
    const v = try b.build();
    try testing.expectEqualStrings("reject-publish", v.object.get("x-overflow").?.string);
}

test "PolicyDefinitionBuilder: chained methods" {
    var b = PolicyDefinitionBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.messageTtl(30000).maxLength(500).deadLetterExchange("my-dlx");
    const v = try b.build();
    try testing.expect(v.object.count() == 3);
    try testing.expectEqual(@as(i64, 30000), v.object.get("message-ttl").?.integer);
}

test "PolicyDefinitionBuilder: custom key" {
    var b = PolicyDefinitionBuilder.init(testing.allocator);
    defer b.deinit();
    _ = b.custom("max-length-bytes", .{ .integer = 1048576 });
    const v = try b.build();
    try testing.expectEqual(@as(i64, 1048576), v.object.get("max-length-bytes").?.integer);
}
