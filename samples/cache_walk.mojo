# Sums the same 4096x4096 float32 matrix (64 MiB) twice:
# row by row (contiguous) and column by column (stride of 4096 floats).
from std.time import perf_counter_ns

comptime N = 4096


def sum_rows(data: List[Float32]) -> Float32:
    var p = data.unsafe_ptr()
    var s: Float32 = 0
    for i in range(N):
        for j in range(N):
            s += p[unsafe_offset=i * N + j]  # next element is 4 bytes away
    return s


def sum_cols(data: List[Float32]) -> Float32:
    var p = data.unsafe_ptr()
    var s: Float32 = 0
    for j in range(N):
        for i in range(N):
            s += p[unsafe_offset=i * N + j]  # next element is 16 KiB away
    return s


def main():
    var data = List[Float32](length=N * N, fill=1.0)
    for _ in range(2):  # second round = warm caches and page tables
        var t0 = perf_counter_ns()
        var a = sum_rows(data)
        var t1 = perf_counter_ns()
        var b = sum_cols(data)
        var t2 = perf_counter_ns()
        print("rows:", (t1 - t0) // 1_000_000, "ms   cols:", (t2 - t1) // 1_000_000, "ms   sums:", a, b)
