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
                .one_line = "Computational Geometry Algorithms - Visualizations with SDL3",
            },
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = noOp },
            },
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "algorithm",
                    .help = "Algorithm, e.g. ConvexHull (default)",
                    .value_ref = r.mkRef(&mem.config.algorithm),
                    .value_name = "Algorithm.*",
                    .short_alias = 'a',
                },
                .{
                    .long_name = "implementation",
                    .help = "Specific implementation, e.g. Slow (default)",
                    .value_ref = r.mkRef(&mem.config.implementation),
                    .value_name = "Implementation.*",
                    .short_alias = 'i',
                },
            }),
        },
    };

    return r.run(&app);
}

fn noOp() !void {}
