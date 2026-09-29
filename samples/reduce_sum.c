float sum(const float *x, int n) {
  float s = 0.0f;
  for (int i = 0; i < n; i++) s += x[i];
  return s;
}
