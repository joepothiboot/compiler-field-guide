#include <stdio.h>
long square(long x);          /* declared here, defined in link_lib.c */
extern long call_count;       /* a global defined in link_lib.c */

int main(void) {
  long r = square(7);
  printf("square(7) = %ld, calls = %ld\n", r, call_count);
  return 0;
}
