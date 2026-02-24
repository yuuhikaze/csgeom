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

    pub fn init(allocator: std.mem.Allocator) !RBTree {
        // Instantiate sentinel node
        const sentinel = try allocator.create(Node);
        sentinel.* = Node{
            .key = 0,
            .color = .Black,
            .left = sentinel,
            .right = sentinel,
            .parent = sentinel,
        };
        // Instantiate RBTree
        return RBTree{ .root = sentinel, .sentinel = sentinel, .allocator = allocator };
    }

    fn _postorder(self: *RBTree, n: *Node, snapshot: *std.ArrayList(*Node)) !void {
        if (n == self.sentinel) return; // base case
        self._postorder(n.left, snapshot);
        self._postorder(n.right, snapshot);
        try snapshot.append(n);
    }

    /// Returns slice (snapshot) of nodes induced by postorder
    pub fn postorder(self: *RBTree, n: *Node) ![]*Node {
        var snapshot = std.ArrayList(*Node).init(self.allocator);
        errdefer snapshot.deinit(); // clean up snapshot given that appends fail
        try self._postorder(n, &snapshot);
        return try snapshot.toOwnedSlice();
    }

    pub fn deinit(self: *RBTree) void {
        const nodes = self.postorder(self.root);
        for (nodes) |node_ptr| {
            // Free nodes memory
            self.allocator.destroy(node_ptr);
        }
        // Free nodes list memory
        self.allocator.free(nodes);
        // Free sentinel node memory
        self.allocator.destroy(self.sentinel);
    }
};
