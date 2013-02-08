# Copyright 2013 University of Chicago and Argonne National Laboratory
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

# Turbine builtin functions

# All builtins will have signature:
#   f <STACK> <OUTPUT LIST> <INPUT LIST>
# where the lists are Tcl lists of TDs
# even if some of the arguments are not used
# The uniformity allows the stp code generator to simply write all
# calls to builtins the same way
# (Not all functions conform to this but they will. -Justin)

namespace eval turbine {

    # User functions
    namespace export enumerate literal shell

    # Memory functions (will be in turbine::f namespace)
    namespace export f_dereference

    # System functions
    namespace export stack_lookup

    # These are Swift-2 functions
    namespace export set1

    # Bring in Turbine extension features
    namespace import c::new c::typeof
    namespace import c::insert c::log

    proc call_composite { stack f outputs inputs blockon } {

        set rule_id [ turbine::c::rule $f "$blockon"        \
                          $turbine::CONTROL $adlb::RANK_ANY \
                          "$f $stack $outputs $inputs" ]
        return $rule_id
    }

    # User function
    # This name conflicts with a TCL built-in - it cannot be exported
    # TODO: Replace this with tracef()
    proc trace { stack signal inputs } {
        rule "trace" $inputs $turbine::LOCAL $adlb::RANK_ANY \
            "turbine::trace_body \"$signal\" $inputs"
    }

    proc trace_body { signal args } {
        set valuelist [ list ]
        foreach v $args {
            set value [ retrieve_decr $v ]
            lappend valuelist $value
        }
        trace_impl2 $valuelist
        if { $signal != "" } {
            store_void $signal
        }
    }
    proc trace_impl { args } {
        # variadic version
        trace_impl2 $args
    }

    proc trace_impl2 { arglist } {
        set n [ llength $arglist ]
        puts -nonewline "trace: "
        set first 1
        foreach value $arglist {
            if { $first } {
              set first 0
            } else {
              puts -nonewline ","
            }
            puts -nonewline $value
        }
        puts ""
    }

    # # For tests/debugging
    proc sleep_trace { stack signal inputs } {
      # parent stack and output arguments not read
      if { ! [ string length $inputs ] } {
        error "trace: received no arguments!"
      }
      set secs [ lindex $inputs 0 ]
      set args [ lreplace $inputs 0 0]
      rule "sleep_trace" $inputs $turbine::WORK $adlb::RANK_ANY \
           "turbine::sleep_trace_body $signal $secs $args"
    }
    proc sleep_trace_body { signal secs inputs } {
      set secs_val [ retrieve_decr_float $secs ]
      after [ expr round($secs_val * 1000) ]
      puts "AFTER"
      trace_body $signal $inputs
    }

    # User function
    proc range { stack result inputs } {
        # Assume that there was a container slot opened
        # that can be owned by range (this works with stc's calling
        #   conventions which don't close assigned arrays)
        set start [ lindex $inputs 0 ]
        set end [ lindex $inputs 1 ]
        rule "range-$result" "$start $end" $turbine::CONTROL $adlb::RANK_ANY \
            "range_body $result $start $end"
    }

    proc range_body { result start end } {

        set start_value [ retrieve_decr_integer $start ]
        set end_value   [ retrieve_decr_integer $end ]

        range_work $result $start_value $end_value 1
    }

    proc rangestep { stack result inputs } {
        # Assume that there was a container slot opened
        # that can be owned by range
        set start [ lindex $inputs 0 ]
        set end [ lindex $inputs 1 ]
        set step [ lindex $inputs 2 ]
        rule "rangestep-$result" [ list $start $end $step ] \
            $turbine::CONTROL $adlb::RANK_ANY\
            "rangestep_body $result $start $end $step"
    }

    proc rangestep_body { result start end step } {

        set start_value [ retrieve_decr_integer $start ]
        set end_value   [ retrieve_decr_integer $end ]
        set step_value   [ retrieve_decr_integer $step ]

        range_work $result $start_value $end_value $step_value
    }

    proc range_work { result start end step } {
        if { $start <= $end } {
            set k 0
            set slot_drop 0
            for { set i $start } { $i <= $end } { incr i $step } {
                allocate td integer
                store_integer $td $i
                
                if { [ expr $i + $step > $end ] } {
                  # Drop on last iter
                  set slot_drop 1
                }
                container_insert $result $k $td $slot_drop
                incr k
            }
        } else {
            # no contents, but have to close
            adlb::slot_drop $result
        }
    }

    # User function
    # Construct a distributed container of sequential integers
    proc drange { result start end parts } {

        rule "drange-$result" "$start $end" $turbine::CONTROL $adlb::RANK_ANY \
            "drange_body $result $start $end $parts"
    }

    proc drange_body { result start end parts } {

        set start_value [ retrieve_decr $start ]
        set end_value   [ retrieve_decr $end ]
        set parts_value [ retrieve_decr $parts ]
        set size        [ expr $end_value - $start_value + 1]
        set step        [ expr $size / $parts_value ]

        global WORK_TYPE
        for { set i 0 } { $i < $parts_value } { incr i } {
            # top-level container
            allocate_container c integer
            container_insert $result $i $c
            # start
            set s [ expr $i *  $step ]
            # end
            set e [ expr $s + $step - 1 ]
            adlb::put $adlb::RANK_ANY $WORK_TYPE(CONTROL) \
                "command priority: $turbine::priority range_work $c $s $e 1" \
                $turbine::priority
        }
        # close container
        adlb::slot_drop $result
    }

    # User function
    # Loop over a distributed container
    proc dloop { loop_body stack container } {

        c::log "log_dloop:"
        rule "dloop-$container" $container $turbine::CONTROL $adlb::RANK_ANY \
            "dloop_body $loop_body $stack $container"
    }

    proc dloop_body { loop_body stack container } {

        set keys [ container_list $container ]

        global WORK_TYPE
        foreach key $keys {
            c::log "log_dloop_body"
            set c [ container_lookup $container $key ]
            release "loop_body $loop_body $stack $c"
        }
    }

    proc readdata { result filename } {

        rule "read_data-$filename" $filename $turbine::CONTROL $adlb::RANK_ANY \
            "readdata_body $result $filename"
    }

    proc readdata_body { result filename } {

        set name_value [ retrieve_decr $filename ]
        if { [ catch { set fd [ open $name_value r ] } e ] } {
            error "Could not open file: '$name_value'"
        }

        set i 0
        while { [ gets $fd line ] >= 0 } {
            allocate s string
            store_string $s $line
            container_insert $result $i $s
            incr i
        }
        adlb::slot_drop $result
    }

    # User function
    proc loop { stmts stack container } {
        rule "loop-$container" $container $turbine::CONTROL $adlb::RANK_ANY \
            "loop_body $stmts $stack $container"
    }

    proc loop_body { stmts stack container } {
        set type [ container_typeof $container ]
        set L    [ container_list $container ]
        c::log "loop_body start"
        foreach subscript $L {
            set td_key [ literal $type $subscript ]
            # Call user body with subscript as TD
            # TODO: shouldn't this be an adlb::put ? -Justin
            $stmts $stack $container $td_key
        }
        c::log "log_loop_body done"
    }

    # Utility function to set up a TD
    # usage: [<name>] <type> <value>
    # If name is given, store TD in variable name and log name
    proc literal { args } {

        if { [ llength $args ] == 2 } {
            set type   [ lindex $args 0 ]
            set value  [ lindex $args 1 ]
            set result [ allocate_custom "" $type 1 1 1 ]
        } elseif { [ llength $args ] == 3 } {
            set name   [ lindex $args 0 ]
            set type   [ lindex $args 1 ]
            set value  [ lindex $args 2 ]
            set result [ allocate_custom $name $type 1 1 1 ]
            upvar 1 $name n
            set n $result
        } else {
            error "turbine::literal requires 2 or 3 args!"
        }

        store_${type} $result $value

        return $result
    }

    # User function
    proc toint { stack result input } {
        rule "toint-$input" $input $turbine::LOCAL $adlb::RANK_ANY \
            "toint_body $input $result"
    }

    proc toint_body { input result } {
      set t [ retrieve_decr $input ]
      store_integer $result [ check_str_int $t ]
    }

    # Must trim leading zeros - Tcl treats leading zeros as octal
    proc check_str_int { input } {
        if { [ string equal $input "0" ] } {
            return 0
        }
        if { ! [ string is integer -strict \
                     [ string trimleft $input "0" ] ] } {
            error "could not convert string '${input}' to integer"
        }
        return $input
    }

    proc fromint { stack result input } {
      rule "fromint-$input-$result" $input $turbine::LOCAL $adlb::RANK_ANY \
            "fromint_body $input $result"
    }

    proc fromint_body { input result } {
        set t [ retrieve_decr_integer $input ]
        # Tcl performs the conversion naturally
        store_string $result $t
    }

    proc tofloat { stack result input } {
        rule "tofloat-$input" $input $turbine::LOCAL $adlb::RANK_ANY \
            "tofloat_body $input $result"
    }

    proc tofloat_body { input result } {
        set t [ retrieve_decr $input ]
        #TODO: would be better if the accepted double types
        #     matched Swift float literals
        store_float $result [ check_str_float $t ]
    }

    proc check_str_float { input } {
      if { ! [ string is double $input ] } {
        error "could not convert string '${input}' to float"
      }
      return $input
    }

    proc fromfloat { stack result input } {
        rule "fromfloat-$input-$result" $input $turbine::LOCAL $adlb::RANK_ANY \
            "fromfloat_body $input $result"
    }

    proc fromfloat_body { input result } {
        set t [ retrieve_decr $input ]
        # Tcl performs the conversion naturally
        store_string $result $t
    }

    # Good for performance testing
    # c = 1;
    # and sleeps
    proc set0 { parent c } {
        rule "set0-$" "" $turbine::WORK $adlb::RANK_ANY "set0_body $parent $c"
    }
    proc set0_body { parent c } {
        log "set0"

        variable stats
        dict incr stats set0

        # Emulate some computation time
        # after 1000
        store_integer $c 0
    }

    # Good for performance testing
    # c = 1;
    # and sleeps
    proc set1 { parent c } {

        rule "set1-$" "" $turbine::WORK $adlb::RANK_ANY "set1_body $parent $c"
    }
    proc set1_body { parent c } {
        log "set1"

        variable stats
        dict incr stats set1

        # Emulate some computation time
        # after 1000
        store_integer $c 1
    }

    # Execute shell command
    proc shell { args } {
        puts "turbine::shell $args"
        set command [ lindex $args 0 ]
        set inputs [ lreplace $args 0 0 ]
        rule "shell-$command" $inputs $turbine::WORK $adlb::RANK_ANY \
            "shell_body $command \"$inputs\""
    }

    proc shell_body { args } {
        set command [ lindex $args 0 ]
        set inputs [ lreplace $args 0 0 ]
        set values [ list ]
        foreach i $inputs {
            set value [ retrieve_decr $i ]
            lappend values $value
        }
        debug "executing: $command $values"
        exec $command $values
    }

    # Look in all enclosing stack frames for the TD for the given symbol
    # If not found, abort
    proc stack_lookup { stack symbol } {

        set result ""
        while true {
            set result [ container_lookup $stack $symbol ]
            if { [ string equal $result "0" ] } {
                # Not found in local stack frame: check enclosing frame
                set enclosure [ container_lookup $stack _enclosure ]
                if { ! [ string equal $enclosure "0" ] } {
                    set stack $enclosure
                } else {
                    # We have no more frames to check
                    break
                }
            } else {
                return $result
            }
        }
        abort "stack_lookup failure: stack: <$stack> symbol: $symbol"
    }

    # o = i.  Void has no value, so this just makes sure that they close at
    # the same time
    proc copy_void { parent o i } {
        rule "copy-$o-$i" $i $turbine::LOCAL $adlb::RANK_ANY "copy_void_body $o $i"
    }
    proc copy_void_body { o i } {
        log "copy_void $i => $o"
        store_void $o
        read_refcount_decr $i
    }

    # Copy string value
    proc copy_string { parent o i } {
        rule "copystring-$o-$i" $i $turbine::LOCAL $adlb::RANK_ANY \
            "copy_string_body $o $i"
    }
    proc copy_string_body { o i } {
        set i_value [ retrieve_decr_string $i ]
        log "copy $i_value => $i_value"
        store_string $o $i_value
    }

    # Copy blob value
    proc copy_blob { parent o i } {
        rule "copyblob-$o-$i" $i $turbine::LOCAL $adlb::RANK_ANY \
            "copy_blob_body $o $i"
    }
    proc copy_blob_body { o i } {
        set i_value [ retrieve_decr_blob $i ]
        log "copy $i_value => $i_value"
        store_blob $o $i_value
        free_blob $i
    }

    # create a void type (i.e. just set it)
    proc make_void { parent o i } {
        empty i
        store_void $o
    }

    proc zero { stack outputs inputs } {
        rule "zero-$outputs-$inputs" $inputs $turbine::WORK $adlb::RANK_ANY \
            "turbine::zero_body $outputs $inputs"
    }
    proc zero_body { output input } {
        store_integer $output 0
    }
}

# Local Variables:
# mode: tcl
# tcl-indent-level: 4
# End:
