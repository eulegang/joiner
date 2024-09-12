const std = @import("std");
const joiner = @import("joiner");

const ArgState = enum {
    Blank,
    Ctx,
    In,
    Out,
};

fn die(comptime fmt: []const u8, ctx: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(fmt, ctx) catch {};

    std.process.exit(1);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    const del = '\n';
    var ctx = joiner.Context.load('{') orelse unreachable;
    var state: ArgState = .Blank;
    var in_file: ?[]const u8 = null;
    var out_file: ?[]const u8 = null;

    _ = args.next();
    while (args.next()) |arg| {
        switch (state) {
            ArgState.Blank => {
                if (std.mem.eql(u8, arg, "-c")) {
                    state = .Ctx;
                } else if (std.mem.eql(u8, arg, "-i")) {
                    state = .In;
                } else if (std.mem.eql(u8, arg, "-o")) {
                    state = .Out;
                } else {
                    die("invalid option used {s}\n", .{arg});
                }
            },

            ArgState.Ctx => {
                if (arg.len != 1) {
                    die("invalid context arguement {s}\n", .{arg});
                }

                ctx = joiner.Context.load(arg[0]) orelse die("invalid context arguement {s}\n", .{arg});
                state = .Blank;
            },

            ArgState.In => {
                in_file = arg;
                state = .Blank;
            },

            ArgState.Out => {
                out_file = arg;
                state = .Blank;
            },
        }
    }

    if (state != .Blank) {
        die("missing arguement\n", .{});
    }

    const in =
        if (in_file) |f|
        try std.fs.cwd().openFile(f, .{ .mode = .read_only })
    else
        std.io.getStdIn();

    const out =
        if (out_file) |f|
        try std.fs.cwd().openFile(f, .{ .mode = .write_only })
    else
        std.io.getStdIn();

    const proc = joiner.Proc.init(ctx, del);

    try proc.process(out, in);
}
