# modified librelane base.sdc to support 2 clocks

# custom env variable
set ::env(JTAG_CLOCK_PERIOD) 500


if { [info exists ::env(CLOCK_PORT)] } {
    set port_count [llength $::env(CLOCK_PORT)]
    puts "\[INFO] Found ${port_count} clocks : $::env(CLOCK_PORT)%"
    if { $port_count == "0" } {
        puts "\[ERROR] No CLOCK_PORT found."
        error
    }

    # set both clock ports
    set ::clock_port [lindex $::env(CLOCK_PORT) 0]
    set ::jtag_clock_port [lindex $::env(CLOCK_PORT) 1]
}


set port_args [get_ports $clock_port]
set jtag_port_args [get_ports $jtag_clock_port]

puts "\[INFO] Using clock $clock_port… with args $port_args"
puts "\[INFO] Using jtag clock $jtag_clock_port… with args $jtag_port_args"


create_clock {*}$port_args -name $clock_port -period $::env(CLOCK_PERIOD)
create_clock {*}$jtag_port_args -name $jtag_clock_port -period $::env(JTAG_CLOCK_PERIOD)

set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
puts "\[INFP] for clk $clock_port :"
puts "\[INFO] Setting output delay to: $output_delay_value"
puts "\[INFO] Setting input delay to: $input_delay_value"


# keep the same io delay constraints for jtag 
set jtag_input_delay_value [expr $::env(JTAG_CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set jtag_output_delay_value [expr $::env(JTAG_CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
puts "\[INFP] for clk $jtag_clock_port :"
puts "\[INFO] Setting output delay to: $jtag_output_delay_value"
puts "\[INFO] Setting input delay to: $jtag_input_delay_value"


set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
} 

# clk
set clk_input [get_port $clock_port]
set clk_indx [lsearch [all_inputs] $clk_input]
set all_inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx ""]

# jtag clk
set jtag_clk_input [get_port $jtag_clock_port]
set jtag_clk_indx [lsearch [all_inputs] $jtag_clk_input]
set jtag_all_inputs_wo_clk [lreplace [all_inputs] $jtag_clk_indx $jtag_clk_indx ""]

# rst
set all_inputs_wo_clk_rst $all_inputs_wo_clk

# jtag has no trst so there is no need to define another rst path 

# correct resetn
set clocks [get_clocks $clock_port]

set_input_delay $input_delay_value -clock $clocks $all_inputs_wo_clk_rst
set_output_delay $output_delay_value -clock $clocks [all_outputs]

if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL) $::env(SYNTH_DRIVING_CELL)
}

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 1] \
    $all_inputs_wo_clk_rst

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
    $clk_input

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
    $jtag_clk_input

set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting load to: $cap_load"
set_load $cap_load [all_outputs]

puts "\[INFO] Setting clock uncertainty to: $::env(CLOCK_UNCERTAINTY_CONSTRAINT)"
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $clocks

puts "\[INFO] Setting clock transition to: $::env(CLOCK_TRANSITION_CONSTRAINT)"
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) $clocks

puts "\[INFO] Setting timing derate to: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1-[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]
set_timing_derate -late [expr 1+[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}


set_clock_groups -asynchronous -group $clock_port -group $jtag_clock_port
