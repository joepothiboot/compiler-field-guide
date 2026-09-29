# Vector add on the GPU: one thread per element.
from max.gpu import WARP_SIZE, block_dim, block_idx, thread_idx
from max.gpu.host import DeviceContext

comptime N = 1000
comptime BLOCK = 256


def vadd_kernel(
    a: Pointer[Float32, MutAnyOrigin],
    b: Pointer[Float32, MutAnyOrigin],
    c: Pointer[Float32, MutAnyOrigin],
    n: Int32,
):
    var i = Int(block_idx.x * block_dim.x + thread_idx.x)
    if i < Int(n):
        c[unsafe_offset=i] = a[unsafe_offset=i] + b[unsafe_offset=i]


def main() raises:
    var ctx = DeviceContext()
    print("device:", ctx.name(), " warp size:", WARP_SIZE)
    var a = ctx.enqueue_create_buffer[DType.float32](N)
    var b = ctx.enqueue_create_buffer[DType.float32](N)
    var c = ctx.enqueue_create_buffer[DType.float32](N)
    with a.map_to_host() as ha, b.map_to_host() as hb:
        for i in range(N):
            ha[i] = Float32(i)
            hb[i] = 2.0
    var grid = (N + BLOCK - 1) // BLOCK
    ctx.enqueue_function[vadd_kernel](
        a.unsafe_ptr(), b.unsafe_ptr(), c.unsafe_ptr(), Int32(N),
        grid_dim=grid, block_dim=BLOCK,
    )
    with c.map_to_host() as hc:
        print(hc[0], hc[999], "blocks:", grid)
