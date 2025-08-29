
void println_int(int n);
void* malloc(unsigned long);

typedef struct {
  double* buf;
  int len;
  int cap;
} Vector;

Vector* new_vec(int cap) {
  Vector* v = (Vector*)malloc(sizeof(Vector));
  v->buf = (double*)malloc(sizeof(double) * cap);
  v->cap = cap;
  v->len = 0;
  return v;
}

Vector* vec_push(Vector* v, double val) {
  if (v->len >= v-> cap) {
    return v;
  }
  v->buf[v->len] = val;
  v->len += 1;
  return v;
}

double sum(Vector* v) {
  double s = 0.0;
  for (int i = 0; i < v->len; i++) {
    s += v->buf[i];
  }
  return s;
}

int main() {
  Vector* v = new_vec(5);
  v = vec_push(v, 1.0);
  v = vec_push(v, 2.0);
  v = vec_push(v, 3.0);
  double s = sum(v);
  int r = (int)s;
  println_int(r); // expect: 6
  return 0;
}
