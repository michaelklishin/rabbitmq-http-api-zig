//
// Exchange Types
//

//
// Exchange Types
//

pub const ExchangeType = enum {
    direct,
    fanout,
    topic,
    headers,
    consistent_hashing,
    modulus_hash,
    random,
    local_random,
    jms_topic,
    recent_history,
    delayed_message,
    message_deduplication,

    pub fn toApiString(self: ExchangeType) []const u8 {
        return switch (self) {
            .direct => "direct",
            .fanout => "fanout",
            .topic => "topic",
            .headers => "headers",
            .consistent_hashing => "x-consistent-hash",
            .modulus_hash => "x-modulus-hash",
            .random => "x-random",
            .local_random => "x-local-random",
            .jms_topic => "x-jms-topic",
            .recent_history => "x-recent-history",
            .delayed_message => "x-delayed-message",
            .message_deduplication => "x-message-deduplication",
        };
    }
};

//
// Queue Types
//

pub const QueueType = enum {
    classic,
    quorum,
    stream,

    pub fn toApiString(self: QueueType) []const u8 {
        return switch (self) {
            .classic => "classic",
            .quorum => "quorum",
            .stream => "stream",
        };
    }
};

//
// Policy Targets
//

pub const PolicyTarget = enum {
    queues,
    classic_queues,
    quorum_queues,
    streams,
    exchanges,
    all,

    pub fn toApiString(self: PolicyTarget) []const u8 {
        return switch (self) {
            .queues => "queues",
            .classic_queues => "classic_queues",
            .quorum_queues => "quorum_queues",
            .streams => "streams",
            .exchanges => "exchanges",
            .all => "all",
        };
    }
};

//
// Supported Protocols
//

pub const SupportedProtocol = enum {
    amqp,
    amqp_tls,
    stream,
    stream_tls,
    mqtt,
    mqtt_tls,
    stomp,
    stomp_tls,
    http,
    http_tls,
    prometheus,
    prometheus_tls,
    clustering,

    pub fn toApiString(self: SupportedProtocol) []const u8 {
        return switch (self) {
            .amqp => "amqp",
            .amqp_tls => "amqp/ssl",
            .stream => "stream",
            .stream_tls => "stream/ssl",
            .mqtt => "mqtt",
            .mqtt_tls => "mqtt/ssl",
            .stomp => "stomp",
            .stomp_tls => "stomp/ssl",
            .http => "http",
            .http_tls => "https",
            .prometheus => "http/prometheus",
            .prometheus_tls => "https/prometheus",
            .clustering => "clustering",
        };
    }
};

//
// Binding Destination Types
//

pub const BindingDestinationType = enum {
    queue,
    exchange,

    pub fn toApiString(self: BindingDestinationType) []const u8 {
        return switch (self) {
            .queue => "queue",
            .exchange => "exchange",
        };
    }
};

//
// Queue Overflow Behavior
//

pub const OverflowBehavior = enum {
    drop_head,
    reject_publish,
    reject_publish_dlx,

    pub fn toApiString(self: OverflowBehavior) []const u8 {
        return switch (self) {
            .drop_head => "drop-head",
            .reject_publish => "reject-publish",
            .reject_publish_dlx => "reject-publish-dlx",
        };
    }
};

//
// Dead Letter Strategy
//

pub const DeadLetterStrategy = enum {
    at_most_once,
    at_least_once,

    pub fn toApiString(self: DeadLetterStrategy) []const u8 {
        return switch (self) {
            .at_most_once => "at-most-once",
            .at_least_once => "at-least-once",
        };
    }
};

//
// Queue Leader Locator
//

pub const QueueLeaderLocator = enum {
    balanced,
    client_local,

    pub fn toApiString(self: QueueLeaderLocator) []const u8 {
        return switch (self) {
            .balanced => "balanced",
            .client_local => "client-local",
        };
    }
};

//
// Virtual Host Limit Targets
//

pub const VirtualHostLimitTarget = enum {
    max_connections,
    max_queues,

    pub fn toApiString(self: VirtualHostLimitTarget) []const u8 {
        return switch (self) {
            .max_connections => "max-connections",
            .max_queues => "max-queues",
        };
    }
};

//
// User Limit Targets
//

pub const UserLimitTarget = enum {
    max_connections,
    max_channels,

    pub fn toApiString(self: UserLimitTarget) []const u8 {
        return switch (self) {
            .max_connections => "max-connections",
            .max_channels => "max-channels",
        };
    }
};

const std = @import("std");

//
// Password Hashing
//

pub fn saltedPasswordHashSha256(salt: [4]u8, password: []const u8) [32]u8 {
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    h.update(&salt);
    h.update(password);
    return h.finalResult();
}

pub fn saltedPasswordHashSha512(salt: [4]u8, password: []const u8) [64]u8 {
    var h = std.crypto.hash.sha2.Sha512.init(.{});
    h.update(&salt);
    h.update(password);
    return h.finalResult();
}

pub fn base64EncodedSaltedPasswordHashSha256(salt: [4]u8, password: []const u8) [52]u8 {
    const hash = saltedPasswordHashSha256(salt, password);
    var salted: [4 + 32]u8 = undefined;
    @memcpy(salted[0..4], &salt);
    @memcpy(salted[4..], &hash);
    var out: [52]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &salted);
    return out;
}

pub fn base64EncodedSaltedPasswordHashSha512(salt: [4]u8, password: []const u8) [96]u8 {
    const hash = saltedPasswordHashSha512(salt, password);
    var salted: [4 + 64]u8 = undefined;
    @memcpy(salted[0..4], &salt);
    @memcpy(salted[4..], &hash);
    var out: [96]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &salted);
    return out;
}

pub fn generateSalt() [4]u8 {
    var salt: [4]u8 = undefined;
    std.crypto.random.bytes(&salt);
    return salt;
}

//
// Unit Tests
//

const testing = std.testing;

test "ExchangeType.toApiString" {
    try testing.expectEqualStrings("fanout", ExchangeType.fanout.toApiString());
    try testing.expectEqualStrings("x-consistent-hash", ExchangeType.consistent_hashing.toApiString());
    try testing.expectEqualStrings("x-local-random", ExchangeType.local_random.toApiString());
}

test "QueueType.toApiString" {
    try testing.expectEqualStrings("classic", QueueType.classic.toApiString());
    try testing.expectEqualStrings("quorum", QueueType.quorum.toApiString());
    try testing.expectEqualStrings("stream", QueueType.stream.toApiString());
}

test "PolicyTarget.toApiString" {
    try testing.expectEqualStrings("queues", PolicyTarget.queues.toApiString());
    try testing.expectEqualStrings("classic_queues", PolicyTarget.classic_queues.toApiString());
    try testing.expectEqualStrings("all", PolicyTarget.all.toApiString());
}

test "SupportedProtocol.toApiString" {
    try testing.expectEqualStrings("amqp", SupportedProtocol.amqp.toApiString());
    try testing.expectEqualStrings("amqp/ssl", SupportedProtocol.amqp_tls.toApiString());
    try testing.expectEqualStrings("stream", SupportedProtocol.stream.toApiString());
    try testing.expectEqualStrings("https", SupportedProtocol.http_tls.toApiString());
}

test "OverflowBehavior.toApiString" {
    try testing.expectEqualStrings("drop-head", OverflowBehavior.drop_head.toApiString());
    try testing.expectEqualStrings("reject-publish", OverflowBehavior.reject_publish.toApiString());
    try testing.expectEqualStrings("reject-publish-dlx", OverflowBehavior.reject_publish_dlx.toApiString());
}

test "DeadLetterStrategy.toApiString" {
    try testing.expectEqualStrings("at-most-once", DeadLetterStrategy.at_most_once.toApiString());
    try testing.expectEqualStrings("at-least-once", DeadLetterStrategy.at_least_once.toApiString());
}

test "QueueLeaderLocator.toApiString" {
    try testing.expectEqualStrings("balanced", QueueLeaderLocator.balanced.toApiString());
    try testing.expectEqualStrings("client-local", QueueLeaderLocator.client_local.toApiString());
}

test "VirtualHostLimitTarget.toApiString" {
    try testing.expectEqualStrings("max-connections", VirtualHostLimitTarget.max_connections.toApiString());
    try testing.expectEqualStrings("max-queues", VirtualHostLimitTarget.max_queues.toApiString());
}

test "UserLimitTarget.toApiString" {
    try testing.expectEqualStrings("max-connections", UserLimitTarget.max_connections.toApiString());
    try testing.expectEqualStrings("max-channels", UserLimitTarget.max_channels.toApiString());
}

test "saltedPasswordHashSha256 is deterministic" {
    const salt = [4]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const h1 = saltedPasswordHashSha256(salt, "guest");
    const h2 = saltedPasswordHashSha256(salt, "guest");
    try testing.expectEqualSlices(u8, &h1, &h2);
}

test "base64EncodedSaltedPasswordHashSha256 produces valid base64" {
    const salt = [4]u8{ 0x01, 0x02, 0x03, 0x04 };
    const encoded = base64EncodedSaltedPasswordHashSha256(salt, "test");
    try testing.expect(encoded.len == 52);
}

test "base64EncodedSaltedPasswordHashSha512 produces valid base64" {
    const salt = [4]u8{ 0x01, 0x02, 0x03, 0x04 };
    const encoded = base64EncodedSaltedPasswordHashSha512(salt, "test");
    try testing.expect(encoded.len == 96);
}
