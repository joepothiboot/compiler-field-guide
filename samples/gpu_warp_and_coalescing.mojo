# Three small kernels, compiled to PTX to compare what the hardware sees.
from max.gpu import block_dim, block_idx, thread_idx
from max.gpu.host import DeviceContext
from max.gpu.primitives import warp


def copy_coalesced(src: Pointer[Float32, MutAnyOrigin], dst: Pointer[Float32, MutAnyOrigin]):
    # Neighboring threads touch neighboring addresses: 32 threads x 4 B = 128 B.
    var i = Int(block_idx.x * block_dim.x + thread_idx.x)
    dst[unsafe_offset=i] = src[unsafe_offset=i]


def copy_strided(src: Pointer[Float32, MutAnyOrigin], dst: Pointer[Float32, MutAnyOrigin]):
    # Neighboring threads are 32 floats (128 B) apart: one transaction each.
    var i = Int(block_idx.x * block_dim.x + thread_idx.x)
    dst[unsafe_offset=i] = src[unsafe_offset=i * 32]


def warp_sum_kernel(src: Pointer[Float32, MutAnyOrigin], dst: Pointer[Float32, MutAnyOrigin]):
    # 32 threads add their values with register shuffles; no shared memory.
    var tid = Int(thread_idx.x)
    var total = warp.sum(src[unsafe_offset=tid])
    if tid == 0:
        dst[unsafe_offset=0] = total


def main() raises:
    var ctx = DeviceContext()
    var src = ctx.enqueue_create_buffer[DType.float32](32 * 32)
    var dst = ctx.enqueue_create_buffer[DType.float32](32)
    ctx.enqueue_function[copy_coalesced](src.unsafe_ptr(), dst.unsafe_ptr(), grid_dim=1, block_dim=32)
    ctx.enqueue_function[copy_strided](src.unsafe_ptr(), dst.unsafe_ptr(), grid_dim=1, block_dim=32)
    ctx.enqueue_function[warp_sum_kernel](src.unsafe_ptr(), dst.unsafe_ptr(), grid_dim=1, block_dim=32)
    ctx.synchronize()
