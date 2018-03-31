#set variables
set rootdirectory "/research1/arnabbag/Projects/Synopsys"
set designname "<DesignName>"
set constraintrptfile "_constraint.rpt"
set arearptfile "_area.rpt"
set timerptfile "_time.rpt"
set powerrptfile "_power.rpt"

set netlistfile "_netlist.v"
set sdffile "_sdf.sdf"
set sdcfile "_sdc.sdc"
set ddcfile "_ddc.ddc"

#set libraries
set search_path [list . "/designPackages/design_installer/scl/scl_pdk/stdlib/fs120/liberty/lib_flow_ss" "/designPackages/design_installer/scl/scl_pdk/stdlib/fs120/liberty/lib_flow_ff" $rootdirectory/lib/SCL]
set target_library tsl18fs120_scl_ff.db
set symbol_library ""
set synthetic_library ""
set link_library "* $target_library $synthetic_library"
set designer "Arnab Bag"

#create working directories
sh mkdir workspace
sh mkdir report

define_design_lib WORK -path "workspace"

#read design sources
analyze -library WORK -format verilog {./src/<myverilogfile1.v> ./src/<myverilogfile2.v> ./src/<myverilogfile3.v>}

#elaborate design
elaborate <TOPMODULE> -architecture verilog -library WORK

#check design
check_design

#get index of clock input
set idx [lsearch [all_inputs] "CLK"]

#set design environment
set_operating_conditions WCCOM -lib WORK
set_wire_load_model "10x10"
set_wire_load_mode enclosed
set_drive 2 [all_inputs]
set_drive 0 CLK
set_load 10 [all_outputs]
set_fanout_load 4 [all_outputs]

#set design constraints
set_max_capacitance 20 [all_outputs]
set_max_fanout 4 [lreplace [all_inputs] $idx $idx]
set_max_transition 2 [all_inputs]


#create clock
create_clock -period 10 -name sysclk CLK

#set constraints
set_clock_latency 0.5 -source -early [get_clocks sysclk]
set_clock_latency 0.5 -source -late [get_clocks sysclk]
set_clock_latency 0.2 -rise [get_clocks sysclk]
set_clock_latency 0.2 -fall [get_clocks sysclk]
set_clock_uncertainty -setup 0.1 [get_clocks sysclk]
set_clock_uncertainty -hold  0.1 [get_clocks sysclk]
set_clock_gating_style -minimum_bitwidth 2
set_clock_transition 0.5 [get_clocks sysclk]

set_input_delay -max 4 [lreplace [all_inputs] $idx $idx] -clock sysclk
set_output_delay -max 4 [all_outputs] -clock sysclk

#set area ***area=0 implies use minimum area***
set_max_area 0

#remove constant flipflops
set compile_seqmap_propagate_constants true

#do not remove unloaded flipflops
set compile_delete_unloaded_sequential_cells false

#set top design
current_design <TOPMODULE>

#set compile map effort
compile -map_effort high -area_effort high

#compile for deep submicron technology
compile_ultra

#turn off output inversion of sequential cells
compile_ultra -no_seq_output_inversion

#flatten your design
ungroup -all -flatten

#write the netlist
write -format verilog -output ./syn/$designname$netlistfile

#write sdf file
write_sdf ./syn/$designname$sdffile

#write sdc file 
write_sdc ./syn/$designname$sdcfile

#generate reports
report_constraint -all_violators > $rootdirectory/$designname/report/$designname$constraintrptfile
report_area > $rootdirectory/$designname/report/$designname$arearptfile
report_power > $rootdirectory/$designname/report/$designname$powerrptfile
report_timing -path full -delay max -nworst 1 -max_paths 100 -significant_digits 2 -sort_by group  > $rootdirectory/$designname/report/$designname$timerptfile 

#save design
write -format ddc -hierarchy -output ./syn/$designname$ddcfile

#I dont know what is this...
set_svf -off