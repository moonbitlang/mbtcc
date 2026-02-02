#include <stdlib.h>

/* { dg-skip-if "requires alloca" { ! alloca } { "-O0" } { "" } } */
int f(){}
int main(){int n=2;double x[n];f();exit(0);}
