# One block of 256 threads sums 256 floats using shared memory.
from max.gpu import barrier, block_dim, block_idx, thread_idx
from max.gpu.host import DeviceContext
from max.gpu.memory import AddressSpace
from std.memory import stack_allocation

comptime TPB = 256  # threads per block


def block_sum_kernel(
    data: Pointer[Float32, MutAnyOrigin],
    result: Pointer[Float32, MutAnyOrigin],
):
    # One shared array per block, visible to all 256 threads of that block.
    var shared = stack_allocation[
        TPB, Float32, address_space = AddressSpace.SHARED
    ]()
    var tid = Int(thread_idx.x)
    var i = Int(block_idx.x) * TPB + tid
    shared[tid] = data[unsafe_offset=i]
    barrier()  # wait until every thread has written its value

    var stride = TPB // 2
    while stride > 0:  # tree reduction: 256 → 128 → ... → 1
        if tid < stride:
            shared[tid] += shared[tid + stride]
        barrier()
        stride //= 2

    if tid == 0:
        result[unsafe_offset=Int(block_idx.x)] = shared[0]


def main() raises:
    var ctx = DeviceContext()
    var n = TPB * 4
    var data = ctx.enqueue_create_buffer[DType.float32](n)
    var out = ctx.enqueue_create_buffer[DType.float32](4)
    with data.map_to_host() as h:
        for i in range(n):
            h[i] = 1.0
    ctx.enqueue_function[block_sum_kernel](
        data.unsafe_ptr(), out.unsafe_ptr(), grid_dim=4, block_dim=TPB
    )
    with out.map_to_host() as h:
        print(h[0], h[1], h[2], h[3])
