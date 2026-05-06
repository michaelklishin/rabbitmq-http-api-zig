// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");

//
// Pagination
//

pub const default_page_size: u32 = 100;
pub const max_page_size: u32 = 500;

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
    delayed,

    pub fn toApiString(self: QueueType) []const u8 {
        return switch (self) {
            .classic => "classic",
            .quorum => "quorum",
            .stream => "stream",
            .delayed => "delayed",
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

    pub fn doesApplyTo(self: PolicyTarget, other: PolicyTarget) bool {
        if (self == other) return true;
        if (self == .all) return other != .exchanges;
        if (self == .queues) {
            return other == .classic_queues or other == .quorum_queues or other == .streams;
        }
        return false;
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

    pub fn pathAbbreviation(self: BindingDestinationType) []const u8 {
        return switch (self) {
            .queue => "q",
            .exchange => "e",
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

//
// TLS Peer Verification
//

pub const TlsPeerVerificationMode = enum {
    enabled,
    disabled,

    pub fn toApiString(self: TlsPeerVerificationMode) []const u8 {
        return switch (self) {
            .enabled => "verify_peer",
            .disabled => "verify_none",
        };
    }
};

//
// Message Transfer Acknowledgement Mode
//

pub const MessageTransferAcknowledgementMode = enum {
    immediate,
    when_published,
    when_confirmed,

    pub fn toApiString(self: MessageTransferAcknowledgementMode) []const u8 {
        return switch (self) {
            .immediate => "no-ack",
            .when_published => "on-publish",
            .when_confirmed => "on-confirm",
        };
    }
};

//
// Channel Use Mode (Federation)
//

pub const ChannelUseMode = enum {
    multiple,
    single,

    pub fn toApiString(self: ChannelUseMode) []const u8 {
        return switch (self) {
            .multiple => "multiple",
            .single => "single",
        };
    }
};

//
// Federation Resource Cleanup Mode
//

pub const FederationResourceCleanupMode = enum {
    default,
    never,

    pub fn toApiString(self: FederationResourceCleanupMode) []const u8 {
        return switch (self) {
            .default => "default",
            .never => "never",
        };
    }
};

//
// Password Hashing Algorithm
//

pub const HashingAlgorithm = enum {
    sha256,
    sha512,

    pub fn toApiString(self: HashingAlgorithm) []const u8 {
        return switch (self) {
            .sha256 => "rabbit_password_hashing_sha256",
            .sha512 => "rabbit_password_hashing_sha512",
        };
    }
};

//
// Password Hashing Helpers
//

/// Fills a 4-byte salt from the platform secure RNG. Pass the same `Io`
/// instance used by your `Client`.
pub fn salt(io: std.Io) ![4]u8 {
    var s: [4]u8 = undefined;
    try std.Io.randomSecure(io, &s);
    return s;
}

pub fn saltedPasswordHashSha256(s: [4]u8, password: []const u8) [32]u8 {
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    h.update(&s);
    h.update(password);
    return h.finalResult();
}

pub fn saltedPasswordHashSha512(s: [4]u8, password: []const u8) [64]u8 {
    var h = std.crypto.hash.sha2.Sha512.init(.{});
    h.update(&s);
    h.update(password);
    return h.finalResult();
}

pub fn base64EncodedSaltedPasswordHashSha256(s: [4]u8, password: []const u8) [48]u8 {
    const hash = saltedPasswordHashSha256(s, password);
    var combined: [4 + 32]u8 = undefined;
    @memcpy(combined[0..4], &s);
    @memcpy(combined[4..], &hash);
    var out: [48]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &combined);
    return out;
}

pub fn base64EncodedSaltedPasswordHashSha512(s: [4]u8, password: []const u8) [92]u8 {
    const hash = saltedPasswordHashSha512(s, password);
    var combined: [4 + 64]u8 = undefined;
    @memcpy(combined[0..4], &s);
    @memcpy(combined[4..], &hash);
    var out: [92]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &combined);
    return out;
}

//
// Unit Tests
//

const testing = std.testing;

test "ExchangeType.toApiString covers plugin-provided types" {
    try testing.expectEqualStrings("fanout", ExchangeType.fanout.toApiString());
    try testing.expectEqualStrings("x-consistent-hash", ExchangeType.consistent_hashing.toApiString());
    try testing.expectEqualStrings("x-local-random", ExchangeType.local_random.toApiString());
    try testing.expectEqualStrings("x-delayed-message", ExchangeType.delayed_message.toApiString());
}

test "QueueType.toApiString" {
    try testing.expectEqualStrings("classic", QueueType.classic.toApiString());
    try testing.expectEqualStrings("quorum", QueueType.quorum.toApiString());
    try testing.expectEqualStrings("stream", QueueType.stream.toApiString());
    try testing.expectEqualStrings("delayed", QueueType.delayed.toApiString());
}

test "PolicyTarget.toApiString" {
    try testing.expectEqualStrings("queues", PolicyTarget.queues.toApiString());
    try testing.expectEqualStrings("classic_queues", PolicyTarget.classic_queues.toApiString());
    try testing.expectEqualStrings("all", PolicyTarget.all.toApiString());
}

test "PolicyTarget.doesApplyTo" {
    try testing.expect(PolicyTarget.queues.doesApplyTo(.classic_queues));
    try testing.expect(PolicyTarget.queues.doesApplyTo(.quorum_queues));
    try testing.expect(PolicyTarget.queues.doesApplyTo(.streams));
    try testing.expect(!PolicyTarget.queues.doesApplyTo(.exchanges));
    try testing.expect(PolicyTarget.all.doesApplyTo(.queues));
    try testing.expect(!PolicyTarget.all.doesApplyTo(.exchanges));
    try testing.expect(PolicyTarget.exchanges.doesApplyTo(.exchanges));
}

test "SupportedProtocol.toApiString" {
    try testing.expectEqualStrings("amqp", SupportedProtocol.amqp.toApiString());
    try testing.expectEqualStrings("amqp/ssl", SupportedProtocol.amqp_tls.toApiString());
    try testing.expectEqualStrings("stream", SupportedProtocol.stream.toApiString());
    try testing.expectEqualStrings("https", SupportedProtocol.http_tls.toApiString());
}

test "BindingDestinationType helpers" {
    try testing.expectEqualStrings("queue", BindingDestinationType.queue.toApiString());
    try testing.expectEqualStrings("q", BindingDestinationType.queue.pathAbbreviation());
    try testing.expectEqualStrings("e", BindingDestinationType.exchange.pathAbbreviation());
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

test "MessageTransferAcknowledgementMode.toApiString" {
    try testing.expectEqualStrings("no-ack", MessageTransferAcknowledgementMode.immediate.toApiString());
    try testing.expectEqualStrings("on-publish", MessageTransferAcknowledgementMode.when_published.toApiString());
    try testing.expectEqualStrings("on-confirm", MessageTransferAcknowledgementMode.when_confirmed.toApiString());
}

test "HashingAlgorithm.toApiString" {
    try testing.expectEqualStrings("rabbit_password_hashing_sha256", HashingAlgorithm.sha256.toApiString());
    try testing.expectEqualStrings("rabbit_password_hashing_sha512", HashingAlgorithm.sha512.toApiString());
}

test "saltedPasswordHashSha256 is deterministic" {
    const s = [4]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const h1 = saltedPasswordHashSha256(s, "guest");
    const h2 = saltedPasswordHashSha256(s, "guest");
    try testing.expectEqualSlices(u8, &h1, &h2);
}

test "different salts produce different hashes" {
    const a = saltedPasswordHashSha256([4]u8{ 1, 2, 3, 4 }, "p");
    const b = saltedPasswordHashSha256([4]u8{ 5, 6, 7, 8 }, "p");
    try testing.expect(!std.mem.eql(u8, &a, &b));
}

test "base64EncodedSaltedPasswordHashSha256 produces valid base64" {
    const s = [4]u8{ 0x01, 0x02, 0x03, 0x04 };
    const encoded = base64EncodedSaltedPasswordHashSha256(s, "test");
    try testing.expect(encoded.len == 48);
    var decoded: [36]u8 = undefined;
    try std.base64.standard.Decoder.decode(&decoded, &encoded);
    try testing.expectEqualSlices(u8, &s, decoded[0..4]);
}

test "base64EncodedSaltedPasswordHashSha512 produces valid base64" {
    const s = [4]u8{ 0x01, 0x02, 0x03, 0x04 };
    const encoded = base64EncodedSaltedPasswordHashSha512(s, "test");
    try testing.expect(encoded.len == 92);
    var decoded: [68]u8 = undefined;
    try std.base64.standard.Decoder.decode(&decoded, &encoded);
    try testing.expectEqualSlices(u8, &s, decoded[0..4]);
}
