#include "builtins.swift"
(int M[]) f () {
    M[-1] = 13;
    M[-2] = 37;
}

main {
    trace(f()[-1], f()[-2]);
}
