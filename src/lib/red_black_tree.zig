const std = @import("std");

const Color = enum { Black, Red };

const Node = struct {
    key: i32,
    color: Color,
    left: *Node,
    right: *Node,
    parent: *Node,
};

pub const RBTree = struct {
    root: *Node,
    sentinel: *Node,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RBTree {
        // allocator.create?
        // Instantiate sentinel node
        var sentinel = Node{
            .key = 0,
            .color = .Black,
        };
        sentinel.left = &sentinel;
        sentinel.right = &sentinel;
        sentinel.parent = &sentinel;
        // Instantiate root node
        const root = Node{
            .key = 0,
            .color = .Black,
            // .left = ?,
            // .right = ?,
            .parent = &sentinel,
        };
        return RBTree{ .root = root, .allocator = allocator };
    }

    fn _postorder(n: *Node, snapshot: std.ArrayList(Node)) void {
        _postorder(n.left, snapshot);
        _postorder(n.right, snapshot);
        snapshot.append(n);
    }

    /// Returns slice (snapshot) of nodes induced by postorder
    pub fn postorder(n: *Node, allocator: std.mem.Allocator) []const Node {
        const snapshot = std.ArrayList(Node).init(allocator);
        _postorder(n, snapshot);
        return snapshot.toOwnedSlice();
    }

    pub fn deinit(self: *RBTree) void {
        const nodes = postorder(self.root, self.allocator);
        for (nodes) |node| {
            // node.destroy()?
        }
        self.allocator.destroy(self.sentinel);
    }
};
