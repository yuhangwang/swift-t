
// UNISTD.SWIFT

#ifndef UNISTD_SWIFT
#define UNISTD_SWIFT

/* Model arg functions as pure, since they will be deterministic
 * within the scope of a program */

@pure
(int c)    argc()
    "turbine" "0.0.2" "argc_get"
    [ "set <<c>> [ turbine::argc_get_impl ]" ];
@pure
(string s) args()
    "turbine" "0.0.2" "args_get"
    [ "set <<s>> [ turbine::args_get_local ]" ];
@pure
(boolean b) argv_contains(string key)
    "turbine" "0.0.2" "argv_contains"
    [ "set <<b>> [ turbine::argv_contains_impl <<key>> ]" ];
argv_accept(string... keys)
    "turbine" "0.0.2" "argv_accept"
    [ "turbine::argv_accept_impl [ list <<keys>> ]" ];
@pure
(string s) argv(string|int key, string... default_val)
    "turbine" "0.0.2" "argv_get"
    [ "set <<s>> [ turbine::argv_get_impl <<key>> <<default_val>> ]" ];

// Do not optimize this- it is for tests
(void v) sleep(float seconds) "turbine" "0.0.4" "sleep";

#endif
