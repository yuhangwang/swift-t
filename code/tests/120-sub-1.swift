#include "builtins.swift"

(int o) sub(int a, int b)
{
  (o) = plus_integer(a,b);
}

main
{
  int x;
  int y;
  int z;

  x = 1;
  y = 2;

  z = sub(x,y);
}
