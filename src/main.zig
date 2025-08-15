const std = @import("std");

var stdout: @typeInfo(@TypeOf(std.fs.File.writer)).Fn.return_type.? = undefined;
var ciphertext: []u8 = undefined;
var key: []u8 = undefined;
var best_score: u32 = 0;

fn score_char(c: u8) u32 {
    return switch (c) {
        'A'...'Z', 'a'...'z' => 3,
        ' ', '0'...'9' => 2,
        0x21...0x2F, 0x3A...0x40, 0x5B...0x60, 0x7B...0x7E => 1,
        0x0...0x1F, 0x7F...0xFF => 0,
    };
}

fn try_key(plaintext: []u8) !void {
    var score: u32 = 0;
    for (plaintext, ciphertext, 0..) |*p, c, i| {
        p.* = c ^ key[i % key.len];
        score += score_char(p.*);
    }
    if (score >= best_score) {
        best_score = score;
        try stdout.print("({s}) {s}\n---\n", .{ key, plaintext });
    }
}

fn try_all_keys(depth: u8, plaintext: []u8) !void {
    if (depth >= key.len) return try try_key(plaintext);
    for (0..256) |c| {
        key[depth] = @intCast(c);
        try try_all_keys(depth + 1, plaintext);
    }
}

pub fn main() !void {
    stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        try stdout.print(
            "Usage: {s} <binary file path or hex bytes>\n",
            .{args[0]},
        );
        return;
    }

    ciphertext = std.fs.cwd().readFileAlloc(
        allocator,
        args[args.len - 1],
        1024 * 1024 * 1024 * 4,
    ) catch fromhex: {
        const cipher_hex = args[args.len - 1];
        const c = try allocator.alloc(u8, cipher_hex.len / 2);
        break :fromhex try std.fmt.hexToBytes(c, cipher_hex);
    };
    defer allocator.free(ciphertext);

    const key_full = try allocator.alloc(u8, ciphertext.len);
    defer allocator.free(key_full);
    const plaintext = try allocator.alloc(u8, ciphertext.len);
    defer allocator.free(plaintext);

    for (1..ciphertext.len + 1) |key_length| {
        key = key_full[0..key_length];
        try try_all_keys(0, plaintext);
    }
}
