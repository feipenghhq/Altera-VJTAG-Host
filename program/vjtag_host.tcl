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

# Usage:
# quartus_stp -t vjtag_host.tcl

set usbblaster ""
set device ""

# setup USB blaster, select device, and open device
proc setup_blaster {} {
    global usbblaster
    global device
    # List all available programming hardware, and select the USB-Blaster.
    foreach hardware_name [get_hardware_names] {
        #puts "Found Hardware: $hardware_name"
        if {[string match "USB-Blaster*" $hardware_name]} {
            set usbblaster $hardware_name
        }
    }
    puts "Selected Hardware: $usbblaster"

    # List all devices on the chain, and select the first device on the chain.
    foreach device_name [get_device_names -hardware_name $usbblaster] {
        #puts "Found Device: $device_name"
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
    device_virtual_dr_shift -instance_index $instance_id -length $length -dr_value $value -no_captured_dr_value -value_in_hex
}

# Sent reset assertion request
proc send_rst_assert_cmd {} {
    set_vir 0xFE
    set_vdr 1 0
}

proc send_rst_deassert_cmd {} {
    set_vir 0xFF
    set_vdr 1 0
}

proc send_write_cmd {word length} {
    set_vir 0x2
    set_vdr $length $word
}


# Close device
proc close {} {
    catch {device_unlock}
    catch {close_device}
}

set instance_id 0
set AW 16
set DW 16

setup_blaster
device_lock -timeout 10000
send_rst_assert_cmd
send_rst_deassert_cmd
send_write_cmd 00040001 32
send_write_cmd 0004FF11 32
device_unlock
close