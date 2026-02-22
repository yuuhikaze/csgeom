const std = @import("std");
const cli = @import("cli");
const repositories = @import("repositories");
const mem = repositories.memory;

pub fn instantiate() !void {
    var r = cli.AppRunner.init(&mem.init);

    const app = cli.App{
        .command = cli.Command{
            .name = "csgeom",
            .description = cli.Description{
                .one_line = "Computer Geometry Algorithms - Visualizations with SDL3",
            },
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = noOp },
            },
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "topic",
                    .help = "Algorithm family, e.g. ConvexHull (default)",
                    .value_ref = r.mkRef(&mem.config.topic),
                    .value_name = "AlgorithmFamilies.*",
                },
                .{
                    .long_name = "algo",
                    .help = "Specific algorithm from family, e.g. Slow (default)",
                    .value_ref = r.mkRef(&mem.config.algo),
                    .value_name = "Algorithms.*",
                },
            }),
        },
    };

    return r.run(&app);
}

fn noOp() !void {}
