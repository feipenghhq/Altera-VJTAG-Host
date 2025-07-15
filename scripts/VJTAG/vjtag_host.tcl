# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: VJTAG Host
# Author: Heqing Huang
# Date Created: 07/12/2025
#
# -------------------------------------------------------------------
# Tcl file to interact with the Virtual JTAG Host
# -------------------------------------------------------------------

set Usage {
------------------------------------------------------------------------------------------------------------------------
Script to use Altera VJTAG to communicate with the target FPGA from the host machine.
Provide a interactive shell to interact with the target FPGA chip.

Usage:
  quartus_stp -t vjtag_host.tcl

Supported commands:
  help                   # print help message
  exit                   # exit the command
  read    <addr>         # read date at <address>
  write   <addr> <data>  # write <data> to <address>
  program <addr> <file>  # program a RAM or continuous memory space starting at <address> using content
                         # in the <file>. the address of the subsequence data will be calculated automatically

Config file:
  A config file is used to provide information about the target device for the script.

  instance_id: 0         # The VJTAG instance ID.
                         # Can be found in synthesis report by searching for parameter 'sld_instance_index'
  addr_width: 16         # number of addr byte
  data_width: 16         # number of data byt

------------------------------------------------------------------------------------------------------------------------
}


package require json

#--------------------------------------
# Global Variable
#--------------------------------------

set usbblaster ""
set device ""
set instance_id 0
set addr_width 0
set data_width 0

#--------------------------------------
# Procedure to interact with VJTAG
#--------------------------------------

# setup USB blaster, select device, and open device
proc setup_blaster {} {
    global usbblaster
    global device
    # List all available programming hardware, and select the USB-Blaster.
    foreach hardware_name [get_hardware_names] {
        if {[string match "USB-Blaster*" $hardware_name]} {
            set usbblaster $hardware_name
        }
    }
    puts "Selected Hardware: $usbblaster"
    # List all devices on the chain, and select the first device on the chain.
    foreach device_name [get_device_names -hardware_name $usbblaster] {
        if {[string match "@1*" $device_name]} {
            set device $device_name
        }
    }
    puts "Selected Device: $device"
    # open device
    open_device -hardware_name $usbblaster -device_name $device
}

# Set VIR register
proc set_vir {value} {
    global instance_id
    device_virtual_ir_shift -instance_index $instance_id -ir_value $value -no_captured_ir_value
}

# Set VDR register
proc set_vdr {length value} {
    global instance_id
    device_virtual_dr_shift -instance_index $instance_id -length $length -dr_value $value -value_in_hex -no_captured_dr_value
}

# Read VDR register
proc read_vdr {length value} {
    global instance_id
    return [device_virtual_dr_shift -instance_index $instance_id -length $length -dr_value $value -value_in_hex]
}

# Close device
proc close {} {
    catch {device_unlock}
    catch {close_device}
}

#------------------------------------------------
# Procedure for sending specific command
#------------------------------------------------

# CMD: reset assertion
proc cmd_rst_assert {} {
    set_vir 0xFE
    set_vdr 1 0
}

# CMD: reset de-assertion
proc cmd_rst_deassert {} {
    set_vir 0xFF
    set_vdr 1 0
}

# CMD: write
# Example: send_write_cmd 0004FF11 32
proc cmd_write {word length} {
    set_vir 0x2
    set_vdr $length $word
}

# CMD: read
# Example: send_read_cmd 0004 16 0000 16
proc cmd_read {word length dummy read_length} {
    # send read request
    set_vir 0x1
    set_vdr $length $word
    # read return data back
    set_vir 0x0
    return [read_vdr $read_length $dummy]
}

#------------------------------------------------
# Procedure for interactive script
#------------------------------------------------

# read the config file
proc read_config {} {
    global instance_id
    global addr_width
    global data_width
    # Read JSON file converted from YAML
    set fh [open "config.json" r]
    set json_data [read $fh]
    #close $fh

    set dict_data [::json::json2dict $json_data]
    set instance_id [dict get $dict_data instance_id]
    set addr_width [dict get $dict_data addr_width]
    set data_width [dict get $dict_data data_width]
    puts "VJTAG Config:"
    puts "  - VJTAG Host instance ID: $instance_id"
    puts "  - Addr Width (bit): $addr_width"
    puts "  - Data Width (bit): $data_width"
}

# process exit command
proc process_exit {} {
    close
    exit
}

proc process_write {addr data} {
    device_lock -timeout 10000
    global addr_width
    global data_width
    scan $addr %i addr
    scan $data %i data
    set length [expr $addr_width + $data_width]
    set word [expr {($addr << $addr_width) | $data}]
    set word [format "%0*X" [expr $length / 4] $word]
    cmd_write $word $length
    device_unlock
}

proc process_read {addr} {
    device_lock -timeout 10000
    global addr_width
    global data_width
    scan $addr %i addr
    set addr [format "%0*X" [expr $addr_width / 4] $addr]
    set dummy [format "%0*X" [expr $addr_width / 4] 0]
    set data [cmd_read $addr $addr_width $dummy $data_width]
    device_unlock
    puts "Received $data"
    return data
}

proc process_program {addr file} {
    global addr_width
    global data_width

    device_lock -timeout 10000
    puts "Assert reset"
    cmd_rst_assert

    puts "Programming File :$file. Starting address: $addr"
    set fp [open $file r]
    while {[gets $fp data] >= 0} {
        # convert binary to decimal
        if {[regexp {^[01]+$} $data]} {
            set data [expr 0b$data]
        }
        # write the data
        scan $addr %i addr
        scan $data %i data
        set length [expr $addr_width + $data_width]
        set word [expr {($addr << $addr_width) | $data}]
        set word [format "%0*X" [expr $length / 4] $word]
        cmd_write $word $length

        # advance the address
        set addr [expr $addr + [expr $addr_width/8]]
    }

    puts "De-assert reset"
    cmd_rst_deassert
    device_unlock
}

# the main interpreter procedure
proc interpreter {} {
    global Usage
    setup_blaster
    puts "\nWelcome to VJTAG interactive shell. Please enter commands"
    while {1} {
        puts -nonewline "> "
        flush stdout
        gets stdin input
        set fields [split $input]
        set cmd  [lindex $fields 0]
        set addr [lindex $fields 1]
        set data [lindex $fields 2]
        set file [lindex $fields 2]
        switch -- $cmd {
            "help"    {puts "$Usage"}
            "exit"    {process_exit}
            "write"   {process_write    $addr $data}
            "read"    {process_read $addr}
            "program" {process_program $addr $file}
            default {puts "Unsupported command. You can type help to see all the available commands"}
        }
    }
}

#------------------------------------------------
# Main Procedure
#------------------------------------------------
proc main {} {
    read_config
    interpreter
}

main

#------------------------------------------------
# Sanity Check
#------------------------------------------------

proc sanity_check {} {
    setup_blaster
    device_lock -timeout 10000
    cmd_rst_assert
    cmd_rst_deassert
    cmd_write 00040001 32
    cmd_write 0004FF11 32
    set result [cmd_read 0008 16 0000 16]
    puts "$result"
    device_unlock
    close
}
