#include "builtins.swift"

main {
    int A[];
    A[0] = 1;
    A[1] = 2;
    
    foreach x, i in A {
        trace(i, x);
    }
    
    A[5] = 3;
    A[6] = 4;

    foreach x in A {
        trace(x);
    }
}
