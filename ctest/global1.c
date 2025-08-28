
void print_int(int);

void println_int(int);

int version = 1;

void upgrade_version() {
  version++;
}

int main() {
  print_int(version);
  upgrade_version();
  println_int(version);
  return 0;
}
