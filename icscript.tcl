#set variables
set rootdirectory "/research1/arnabbag/Projects/Synopsys"
set designname "<DesignName>"
set netlistfile "_netlist.v"
set sdffile "_sdf.sdf"
set sdcfile "_sdc.sdc"
set ddcfile "_ddc.ddc"
set mwextsn ".mw"
set gdsextsn ".gds2"
set utilrptfile "_util.rpt"
set maxtimerptfile "_maxtime.rpt"
set mintimerptfile "_mintime.rpt"
set phypowerrptfile "_phypower.rpt"
set pexspeffile "_extracted.spef"
set pexsdffile "_extracted.sdf"
set pexverilogfile "_extracted.v"

#set libraries
set search_path [list . "/designPackages/design_installer/scl/scl_pdk/stdlib/fs120/liberty/lib_flow_ss" "/designPackages/design_installer/scl/scl_pdk/stdlib/fs120/liberty/lib_flow_ff" $rootdirectory/lib/SCL]
set target_library tsl18fs120_scl_ff.db
set symbol_library ""
set synthetic_library ""
set link_library "* $target_library $synthetic_library"
set designer "Arnab Bag"

#set technology files
set_tlu_plus_files -max_tluplus /designPackages/scl_backend/layout/tlup/RCE_TS18SL_STAR_RCXT_4M1L_USG.tlup -min_tluplus /designPackages/scl_backend/layout/tlup/RCE_TS18SL_STAR_RCXT_4M1L_USG.tlup

#create MilkyWay Library
create_mw_lib  -technology /designPackages/scl_backend/layout/tffile/icc.tf   -mw_reference_library {/designPackages/scl_backend/fs120_scl} -bus_naming_style {[%d]}  ./phy/$designname$mwextsn

#open MilkyWay Library
open_mw_lib ./phy/$designname$mwextsn

#import previously generated netlist
import_designs -format verilog {./syn/$designname$netlistfile}

#import design constraints file
read_sdc  -version latest ./syn/$designname$sdcfile

#save MilkyWay Library
save_mw_cel -as $designname

#set power supply nets
set power "VDD"
set ground "VSS"
set powerPort "VDD"
set groundPort "VSS"
foreach net {VDD} {derive_pg_connection -power_net $net -power_pin $net -create_ports top}
foreach net {VSS} {derive_pg_connection -ground_net $net -ground_pin $net -create_ports top}
derive_pg_connection -tie

#create floorplan
create_floorplan -core_utilization 0.7 -control_type "aspect_ratio" -core_aspect_ratio 1.0 -row_core_ratio 1 -use_horizontal_row -start_first_row -left_io2core 5.0 -bottom_io2core 5.0 -right_io2core 5.0 -top_io2core 5.0

#create rectiliniar rings
create_rectilinear_rings -around core -nets {VDD VSS} -offset {0.5 0.5} -width {1 1} -space {0.5 0.5} -layers {M3 TOP_M}

#save MilkyWay Library
save_mw_cel -as $designname

#optimize placement
place_opt -power -area_recovery -effort high
place_opt -power -effort high

#save MilkyWay Library
save_mw_cel -as $designname

#pre-route power rails
preroute_standard_cells -nets {VDD VSS} -connect horizontal -extend_to_boundaries_and_generate_pins

#commit power plan
create_fp_placement
synthesize_fp_rail -power_budget "1000" -voltage_supply "1.2" -target_voltage_drop "250"  -output_dir "./report" -nets "VDD VSS" -create_virtual_rails "M1" -synthesize_power_plan -synthesize_power_pads -use_strap_ends_as_pads
commit_fp_rail

#save MilkyWay Library
save_mw_cel -as $designname

#synthesize clock tree
clock_opt -only_cts -no_clock_route
route_zrt_group -all_clock_nets -reuse_existing_global_route true
route_zrt_global
route_zrt_track 
clock_opt -fix_hold_all_clocks 
set_fix_hold [all_clocks]

#save MilkyWay Library
save_mw_cel -as $designname

#route the design
route_opt -initial_route_only
route_opt -skip_initial_route -effort low
insert_stdcell_filler -cell_with_metal "SHFILL1 SHFILL2 SHFILL3" -connect_to_power "VDD" -connect_to_ground "VSS"
route_opt -incremental -size_only -effort high

#run DRC and reroute
route_search_repair -rerun_drc -loop 10
route_zrt_eco -max_detail_route_iterations 5
verify_lvs -check_open_locator -check_short_locator

#insert filler cells
#insert_stdcell_filler -cell_without_metal "SHFILL128_RVT SHFILL64_RVT SHFILL3_RVT SHFILL2_RVT SHFILL1_RVT" -connect_to_power {VDD} -connect_to_ground {VSS}
insert_stdcell_filler -cell_without_metal "SHFILL1 SHFILL2 SHFILL3" -connect_to_power {VDD} -connect_to_ground {VSS}

#rerun DRC
verify_drc
verify_lvs

#generate reports
report_placement_utilization > $rootdirectory/$designname/report/$designname$utilrptfile
report_timing -max_paths 100 -delay max > $rootdirectory/$designname/report/$designname$maxtimerptfile  
report_timing -max_paths 100 -delay min > $rootdirectory/$designname/report/$designname$mintimerptfile
report_power > $rootdirectory/$designname/report/$designname$phypowerrptfile

#parasitic extraction
extract_rc -coupling_cap -routed_nets_only -incremental
write_parasitics -output $rootdirectory/$designname/report/$designname$pexspeffile -format SPEF
write_sdf $rootdirectory/$designname/report/$designname$pexsdffile
write_verilog $rootdirectory/$designname/report/$designname$pexverilogfile

#write stream
set_write_stream_options -output_pin {text geometry} -keep_data_type
write_stream -format gds2 -lib_name $designname$mwextsn $designname$gdsextsn
