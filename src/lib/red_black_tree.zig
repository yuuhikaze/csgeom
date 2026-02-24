const std = @import("std");

/// Red-Black Tree node color
const Color = enum { Black, Red };

/// Comparison result for ordering operations
pub const Order = enum { Less, Equal, Greater };

/// Comparator function type: compares two values of type T
/// Returns: .Less if a < b, .Equal if a == b, .Greater if a > b
pub const CompareFn = fn (a: anytype, b: anytype) Order;

/// Generic Red-Black Tree node
fn Node(comptime T: type) type {
    return struct {
        key: T,
        color: Color,
        left: *Self,
        right: *Self,
        parent: *Self,

        const Self = @This();
    };
}

/// Generic Red-Black Tree with custom comparator
///
/// Properties maintained:
/// 1. Every node is either red or black
/// 2. Root is black
/// 3. All leaves (sentinel) are black
/// 4. Red nodes have black children
/// 5. All paths from node to descendant leaves contain same number of black nodes
///
/// Time complexity: O(log n) for insert, delete, search
/// Space complexity: O(n)
pub fn RBTree(comptime T: type) type {
    return struct {
        root: *NodeT,
        sentinel: *NodeT,
        allocator: std.mem.Allocator,
        compareFn: *const fn (T, T) Order,

        const Self = @This();
        const NodeT = Node(T);

        /// Initialize empty Red-Black Tree with given comparator
        /// Caller must call deinit() to free memory
        pub fn init(allocator: std.mem.Allocator, compareFn: *const fn (T, T) Order) !Self {
            // Create sentinel node (NIL) - always black, points to itself
            const sentinel = try allocator.create(NodeT);
            sentinel.* = NodeT{
                .key = undefined, // Sentinel key never accessed
                .color = .Black,
                .left = sentinel,
                .right = sentinel,
                .parent = sentinel,
            };

            return Self{
                .root = sentinel,
                .sentinel = sentinel,
                .allocator = allocator,
                .compareFn = compareFn,
            };
        }

        /// Free all tree memory including nodes and sentinel
        pub fn deinit(self: *Self) void {
            // Get all nodes in postorder (children before parents)
            const nodes = self.postorder(self.root) catch {
                // If postorder fails, still free sentinel to avoid leak
                self.allocator.destroy(self.sentinel);
                return;
            };
            defer self.allocator.free(nodes);

            // Free each node
            for (nodes) |node_ptr| {
                self.allocator.destroy(node_ptr);
            }

            // Free sentinel node
            self.allocator.destroy(self.sentinel);
        }

        /// Perform left rotation around node x
        ///     x                y
        ///    / \              / \
        ///   α   y     =>     x   γ
        ///      / \          / \
        ///     β   γ        α   β
        fn leftRotate(self: *Self, x: *NodeT) void {
            const y = x.right; // Set y

            // Turn y's left subtree into x's right subtree
            x.right = y.left;
            if (y.left != self.sentinel) {
                y.left.parent = x;
            }

            // Link x's parent to y
            y.parent = x.parent;
            if (x.parent == self.sentinel) {
                self.root = y; // x was root
            } else if (x == x.parent.left) {
                x.parent.left = y; // x was left child
            } else {
                x.parent.right = y; // x was right child
            }

            // Put x on y's left
            y.left = x;
            x.parent = y;
        }

        /// Perform right rotation around node y
        ///       y              x
        ///      / \            / \
        ///     x   γ   =>     α   y
        ///    / \                / \
        ///   α   β              β   γ
        fn rightRotate(self: *Self, y: *NodeT) void {
            const x = y.left; // Set x

            // Turn x's right subtree into y's left subtree
            y.left = x.right;
            if (x.right != self.sentinel) {
                x.right.parent = y;
            }

            // Link y's parent to x
            x.parent = y.parent;
            if (y.parent == self.sentinel) {
                self.root = x; // y was root
            } else if (y == y.parent.right) {
                y.parent.right = x; // y was right child
            } else {
                y.parent.left = x; // y was left child
            }

            // Put y on x's right
            x.right = y;
            y.parent = x;
        }

        /// Restore Red-Black Tree properties after insertion
        fn insertFixup(self: *Self, z_param: *NodeT) void {
            var z = z_param;

            // While parent is red (violates property 4)
            while (z.parent.color == .Red) {
                if (z.parent == z.parent.parent.left) {
                    // Parent is left child
                    const y = z.parent.parent.right; // Uncle

                    if (y.color == .Red) {
                        // Case 1: Uncle is red - recolor
                        z.parent.color = .Black;
                        y.color = .Black;
                        z.parent.parent.color = .Red;
                        z = z.parent.parent; // Move up tree
                    } else {
                        // Uncle is black
                        if (z == z.parent.right) {
                            // Case 2: z is right child - left rotate
                            z = z.parent;
                            self.leftRotate(z);
                        }
                        // Case 3: z is left child - recolor and right rotate
                        z.parent.color = .Black;
                        z.parent.parent.color = .Red;
                        self.rightRotate(z.parent.parent);
                    }
                } else {
                    // Parent is right child (symmetric)
                    const y = z.parent.parent.left; // Uncle

                    if (y.color == .Red) {
                        // Case 1: Uncle is red - recolor
                        z.parent.color = .Black;
                        y.color = .Black;
                        z.parent.parent.color = .Red;
                        z = z.parent.parent;
                    } else {
                        // Uncle is black
                        if (z == z.parent.left) {
                            // Case 2: z is left child - right rotate
                            z = z.parent;
                            self.rightRotate(z);
                        }
                        // Case 3: z is right child - recolor and left rotate
                        z.parent.color = .Black;
                        z.parent.parent.color = .Red;
                        self.leftRotate(z.parent.parent);
                    }
                }
            }

            // Ensure root is black (property 2)
            self.root.color = .Black;
        }

        /// Insert key into Red-Black Tree
        /// Returns error if allocation fails
        pub fn insert(self: *Self, key: T) !void {
            // Create new node
            const z = try self.allocator.create(NodeT);
            z.* = NodeT{
                .key = key,
                .color = .Red, // New nodes start red
                .left = self.sentinel,
                .right = self.sentinel,
                .parent = self.sentinel,
            };

            // Find position for new node
            var y = self.sentinel; // Trailing pointer
            var x = self.root; // Current node

            while (x != self.sentinel) {
                y = x;
                const cmp = self.compareFn(z.key, x.key);
                if (cmp == .Less) {
                    x = x.left;
                } else {
                    x = x.right;
                }
            }

            // Insert node as child of y
            z.parent = y;
            if (y == self.sentinel) {
                self.root = z; // Tree was empty
            } else {
                const cmp = self.compareFn(z.key, y.key);
                if (cmp == .Less) {
                    y.left = z;
                } else {
                    y.right = z;
                }
            }

            // Fix Red-Black Tree properties
            self.insertFixup(z);
        }

        /// Replace subtree rooted at u with subtree rooted at v
        fn transplant(self: *Self, u: *NodeT, v: *NodeT) void {
            if (u.parent == self.sentinel) {
                self.root = v; // u was root
            } else if (u == u.parent.left) {
                u.parent.left = v; // u was left child
            } else {
                u.parent.right = v; // u was right child
            }
            v.parent = u.parent;
        }

        /// Restore Red-Black Tree properties after deletion
        fn deleteFixup(self: *Self, x_param: *NodeT) void {
            var x = x_param;

            // While x is not root and x is black (double-black)
            while (x != self.root and x.color == .Black) {
                if (x == x.parent.left) {
                    // x is left child
                    var w = x.parent.right; // Sibling

                    if (w.color == .Red) {
                        // Case 1: Sibling is red
                        w.color = .Black;
                        x.parent.color = .Red;
                        self.leftRotate(x.parent);
                        w = x.parent.right;
                    }

                    if (w.left.color == .Black and w.right.color == .Black) {
                        // Case 2: Sibling's children are both black
                        w.color = .Red;
                        x = x.parent; // Move up
                    } else {
                        if (w.right.color == .Black) {
                            // Case 3: Sibling's right child is black
                            w.left.color = .Black;
                            w.color = .Red;
                            self.rightRotate(w);
                            w = x.parent.right;
                        }
                        // Case 4: Sibling's right child is red
                        w.color = x.parent.color;
                        x.parent.color = .Black;
                        w.right.color = .Black;
                        self.leftRotate(x.parent);
                        x = self.root; // Terminate loop
                    }
                } else {
                    // x is right child (symmetric)
                    var w = x.parent.left; // Sibling

                    if (w.color == .Red) {
                        // Case 1: Sibling is red
                        w.color = .Black;
                        x.parent.color = .Red;
                        self.rightRotate(x.parent);
                        w = x.parent.left;
                    }

                    if (w.right.color == .Black and w.left.color == .Black) {
                        // Case 2: Sibling's children are both black
                        w.color = .Red;
                        x = x.parent;
                    } else {
                        if (w.left.color == .Black) {
                            // Case 3: Sibling's left child is black
                            w.right.color = .Black;
                            w.color = .Red;
                            self.leftRotate(w);
                            w = x.parent.left;
                        }
                        // Case 4: Sibling's left child is red
                        w.color = x.parent.color;
                        x.parent.color = .Black;
                        w.left.color = .Black;
                        self.rightRotate(x.parent);
                        x = self.root;
                    }
                }
            }

            x.color = .Black;
        }

        /// Delete node with given key from tree
        /// Returns true if node was found and deleted, false otherwise
        pub fn delete(self: *Self, key: T) bool {
            // Find node to delete
            const z = self.search(key) orelse return false;

            var y = z; // Node to be removed or moved
            var y_original_color = y.color;
            var x: *NodeT = undefined; // Node that moves into y's position

            if (z.left == self.sentinel) {
                // Case 1: z has no left child
                x = z.right;
                self.transplant(z, z.right);
            } else if (z.right == self.sentinel) {
                // Case 2: z has no right child
                x = z.left;
                self.transplant(z, z.left);
            } else {
                // Case 3: z has two children
                y = self.minimumNode(z.right); // Find successor
                y_original_color = y.color;
                x = y.right;

                if (y.parent == z) {
                    x.parent = y; // x might be sentinel
                } else {
                    self.transplant(y, y.right);
                    y.right = z.right;
                    y.right.parent = y;
                }

                self.transplant(z, y);
                y.left = z.left;
                y.left.parent = y;
                y.color = z.color;
            }

            // Free deleted node
            self.allocator.destroy(z);

            // Fix tree if black node was removed
            if (y_original_color == .Black) {
                self.deleteFixup(x);
            }

            return true;
        }

        /// Search for node with given key
        /// Returns pointer to node if found, null otherwise
        pub fn search(self: *Self, key: T) ?*NodeT {
            var x = self.root;

            while (x != self.sentinel) {
                const cmp = self.compareFn(key, x.key);
                switch (cmp) {
                    .Equal => return x,
                    .Less => x = x.left,
                    .Greater => x = x.right,
                }
            }

            return null; // Not found
        }

        /// Find node with minimum key in subtree rooted at node
        fn minimumNode(self: *Self, node: *NodeT) *NodeT {
            var x = node;
            while (x.left != self.sentinel) {
                x = x.left;
            }
            return x;
        }

        /// Find minimum key in tree
        /// Returns null if tree is empty
        pub fn minimum(self: *Self) ?T {
            if (self.root == self.sentinel) return null;
            return self.minimumNode(self.root).key;
        }

        /// Find node with maximum key in subtree rooted at node
        fn maximumNode(self: *Self, node: *NodeT) *NodeT {
            var x = node;
            while (x.right != self.sentinel) {
                x = x.right;
            }
            return x;
        }

        /// Find maximum key in tree
        /// Returns null if tree is empty
        pub fn maximum(self: *Self) ?T {
            if (self.root == self.sentinel) return null;
            return self.maximumNode(self.root).key;
        }

        /// Find successor of node (next larger key)
        fn successorNode(self: *Self, node: *NodeT) ?*NodeT {
            var x = node;

            // If right subtree exists, successor is leftmost node in it
            if (x.right != self.sentinel) {
                return self.minimumNode(x.right);
            }

            // Otherwise, go up until we find a node that is a left child
            var y = x.parent;
            while (y != self.sentinel and x == y.right) {
                x = y;
                y = y.parent;
            }

            if (y == self.sentinel) return null;
            return y;
        }

        /// Find successor of key (next larger key)
        /// Returns null if key not found or key is maximum
        pub fn successor(self: *Self, key: T) ?T {
            const node = self.search(key) orelse return null;
            const succ = self.successorNode(node) orelse return null;
            return succ.key;
        }

        /// Find predecessor of node (next smaller key)
        fn predecessorNode(self: *Self, node: *NodeT) ?*NodeT {
            var x = node;

            // If left subtree exists, predecessor is rightmost node in it
            if (x.left != self.sentinel) {
                return self.maximumNode(x.left);
            }

            // Otherwise, go up until we find a node that is a right child
            var y = x.parent;
            while (y != self.sentinel and x == y.left) {
                x = y;
                y = y.parent;
            }

            if (y == self.sentinel) return null;
            return y;
        }

        /// Find predecessor of key (next smaller key)
        /// Returns null if key not found or key is minimum
        pub fn predecessor(self: *Self, key: T) ?T {
            const node = self.search(key) orelse return null;
            const pred = self.predecessorNode(node) orelse return null;
            return pred.key;
        }

        /// Check if tree is empty
        pub fn isEmpty(self: *Self) bool {
            return self.root == self.sentinel;
        }

        /// Postorder traversal helper (left, right, root)
        fn postorderHelper(self: *Self, node: *NodeT, snapshot: *std.ArrayList(*NodeT)) !void {
            if (node == self.sentinel) return;
            try self.postorderHelper(node.left, snapshot);
            try self.postorderHelper(node.right, snapshot);
            try snapshot.append(self.allocator, node);
        }

        /// Get postorder traversal of tree starting from node
        /// Caller owns returned slice and must free with allocator
        pub fn postorder(self: *Self, node: *NodeT) ![]*NodeT {
            var snapshot: std.ArrayList(*NodeT) = .empty;
            errdefer snapshot.deinit(self.allocator);
            try self.postorderHelper(node, &snapshot);
            return try snapshot.toOwnedSlice(self.allocator);
        }

        /// Inorder traversal helper (left, root, right)
        fn inorderHelper(self: *Self, node: *NodeT, snapshot: *std.ArrayList(*NodeT)) !void {
            if (node == self.sentinel) return;
            try self.inorderHelper(node.left, snapshot);
            try snapshot.append(self.allocator, node);
            try self.inorderHelper(node.right, snapshot);
        }

        /// Get inorder traversal of tree (returns keys in sorted order)
        /// Caller owns returned slice and must free with allocator
        pub fn inorder(self: *Self) ![]*NodeT {
            var snapshot: std.ArrayList(*NodeT) = .empty;
            errdefer snapshot.deinit(self.allocator);
            try self.inorderHelper(self.root, &snapshot);
            return try snapshot.toOwnedSlice(self.allocator);
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

// Simple integer comparator for testing
fn compareI32(a: i32, b: i32) Order {
    if (a < b) return .Less;
    if (a > b) return .Greater;
    return .Equal;
}

test "RBTree: init and deinit" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    try std.testing.expect(tree.isEmpty());
    try std.testing.expectEqual(null, tree.minimum());
    try std.testing.expectEqual(null, tree.maximum());
}

test "RBTree: insert single element" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    try tree.insert(42);
    try std.testing.expect(!tree.isEmpty());
    try std.testing.expectEqual(42, tree.minimum());
    try std.testing.expectEqual(42, tree.maximum());
    try std.testing.expect(tree.search(42) != null);
}

test "RBTree: insert and search multiple elements" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    // Insert elements
    const values = [_]i32{ 10, 20, 5, 15, 25, 3, 7 };
    for (values) |val| {
        try tree.insert(val);
    }

    // Verify all elements can be found
    for (values) |val| {
        try std.testing.expect(tree.search(val) != null);
    }

    // Verify non-existent element not found
    try std.testing.expect(tree.search(100) == null);
}

test "RBTree: min and max" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    const values = [_]i32{ 50, 30, 70, 20, 40, 60, 80 };
    for (values) |val| {
        try tree.insert(val);
    }

    try std.testing.expectEqual(20, tree.minimum());
    try std.testing.expectEqual(80, tree.maximum());
}

test "RBTree: delete elements" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    // Insert elements
    const values = [_]i32{ 10, 20, 5, 15, 25, 3, 7 };
    for (values) |val| {
        try tree.insert(val);
    }

    // Delete element
    try std.testing.expect(tree.delete(20));
    try std.testing.expect(tree.search(20) == null);
    try std.testing.expect(tree.search(10) != null);

    // Delete non-existent element
    try std.testing.expect(!tree.delete(100));
}

test "RBTree: delete all elements" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    const values = [_]i32{ 10, 20, 5 };
    for (values) |val| {
        try tree.insert(val);
    }

    // Delete all elements
    for (values) |val| {
        try std.testing.expect(tree.delete(val));
    }

    try std.testing.expect(tree.isEmpty());
    try std.testing.expectEqual(null, tree.minimum());
}

test "RBTree: successor operations" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    const values = [_]i32{ 50, 30, 70, 20, 40, 60, 80 };
    for (values) |val| {
        try tree.insert(val);
    }

    // Test successors
    try std.testing.expectEqual(30, tree.successor(20));
    try std.testing.expectEqual(40, tree.successor(30));
    try std.testing.expectEqual(50, tree.successor(40));
    try std.testing.expectEqual(60, tree.successor(50));
    try std.testing.expectEqual(70, tree.successor(60));
    try std.testing.expectEqual(80, tree.successor(70));

    // Maximum has no successor
    try std.testing.expectEqual(null, tree.successor(80));

    // Non-existent element
    try std.testing.expectEqual(null, tree.successor(100));
}

test "RBTree: predecessor operations" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    const values = [_]i32{ 50, 30, 70, 20, 40, 60, 80 };
    for (values) |val| {
        try tree.insert(val);
    }

    // Test predecessors
    try std.testing.expectEqual(70, tree.predecessor(80));
    try std.testing.expectEqual(60, tree.predecessor(70));
    try std.testing.expectEqual(50, tree.predecessor(60));
    try std.testing.expectEqual(40, tree.predecessor(50));
    try std.testing.expectEqual(30, tree.predecessor(40));
    try std.testing.expectEqual(20, tree.predecessor(30));

    // Minimum has no predecessor
    try std.testing.expectEqual(null, tree.predecessor(20));

    // Non-existent element
    try std.testing.expectEqual(null, tree.predecessor(100));
}

test "RBTree: inorder traversal returns sorted order" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    // Insert in random order
    const values = [_]i32{ 50, 30, 70, 20, 40, 60, 80, 10, 25, 35 };
    for (values) |val| {
        try tree.insert(val);
    }

    // Get inorder traversal
    const nodes = try tree.inorder();
    defer allocator.free(nodes);

    // Verify sorted order
    const expected = [_]i32{ 10, 20, 25, 30, 35, 40, 50, 60, 70, 80 };
    try std.testing.expectEqual(expected.len, nodes.len);

    for (expected, 0..) |exp_val, i| {
        try std.testing.expectEqual(exp_val, nodes[i].key);
    }
}

test "RBTree: duplicate insertions" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    // Insert same value multiple times
    try tree.insert(10);
    try tree.insert(10);
    try tree.insert(10);

    // Should create multiple nodes (duplicates go to right subtree)
    const nodes = try tree.inorder();
    defer allocator.free(nodes);

    try std.testing.expectEqual(3, nodes.len);
}

test "RBTree: stress test with many insertions" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    // Insert 100 elements
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        try tree.insert(i);
    }

    // Verify all elements present
    i = 0;
    while (i < 100) : (i += 1) {
        try std.testing.expect(tree.search(i) != null);
    }

    try std.testing.expectEqual(0, tree.minimum());
    try std.testing.expectEqual(99, tree.maximum());
}

test "RBTree: stress test with insertions and deletions" {
    const allocator = std.testing.allocator;
    var tree = try RBTree(i32).init(allocator, compareI32);
    defer tree.deinit();

    // Insert 50 elements
    var i: i32 = 0;
    while (i < 50) : (i += 1) {
        try tree.insert(i);
    }

    // Delete even elements
    i = 0;
    while (i < 50) : (i += 2) {
        try std.testing.expect(tree.delete(i));
    }

    // Verify odd elements remain
    i = 1;
    while (i < 50) : (i += 2) {
        try std.testing.expect(tree.search(i) != null);
    }

    // Verify even elements deleted
    i = 0;
    while (i < 50) : (i += 2) {
        try std.testing.expect(tree.search(i) == null);
    }
}

test "RBTree: custom comparator with structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const comparePoints = struct {
        fn cmp(a: Point, b: Point) Order {
            // Compare by x first, then y
            if (a.x < b.x) return .Less;
            if (a.x > b.x) return .Greater;
            if (a.y < b.y) return .Less;
            if (a.y > b.y) return .Greater;
            return .Equal;
        }
    }.cmp;

    const allocator = std.testing.allocator;
    var tree = try RBTree(Point).init(allocator, comparePoints);
    defer tree.deinit();

    try tree.insert(.{ .x = 10, .y = 20 });
    try tree.insert(.{ .x = 5, .y = 15 });
    try tree.insert(.{ .x = 15, .y = 25 });

    try std.testing.expect(tree.search(.{ .x = 10, .y = 20 }) != null);
    try std.testing.expect(tree.search(.{ .x = 5, .y = 15 }) != null);
    try std.testing.expect(tree.search(.{ .x = 99, .y = 99 }) == null);
}
