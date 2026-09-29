# LayoutTensor (from MAX's `layout` package): a view = pointer + compile-time layout.
from std.collections import Array
from layout import Layout, LayoutTensor


def main():
    comptime layout = Layout.row_major(4, 8)  # shape (4, 8), strides (8, 1)
    var storage = Array[Float32, 32](fill=0)
    var t = LayoutTensor[DType.float32, layout](storage)
    for i in range(4):
        for j in range(8):
            t[i, j] = Float32(i * 10 + j)
    var tile = t.tile[2, 4](1, 1)  # the 2x4 block at tile coordinates (1, 1)
    print("tile (rows 2-3, cols 4-7):")
    print(tile)
