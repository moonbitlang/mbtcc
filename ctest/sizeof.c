
void println_int(int);

typedef struct {
  int a;
  char b;
} S;

int main() {
  int a = sizeof(S);

  println_int(a);
  return 0;
}
