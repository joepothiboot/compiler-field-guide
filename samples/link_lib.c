long call_count = 0;
static long helper(long x) { return x * x; }   /* static: not visible to the linker */
long square(long x) { call_count++; return helper(x); }
