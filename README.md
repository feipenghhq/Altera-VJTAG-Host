# Altera Virtual JTAG Host

This project implements an interface using Altera Virtual JTAG to access write on-chip memory in an FPGA design.
You can use Altera USB blaster to access your on-chip memory.

```text
+---------------+                +--------------------+     +-----------+     +---------+
| Host (PC)     |  USB-Blaster   |  Virtual JTAG TAP  |     |    bus    |     | On-Chip |
| vjtag_host.sh |--------------> |  (vjtag_interface) | --> | converter | --> | Memory  |
+---------------+                +--------------------+     +-----------+     +---------+
```

## How it work

- The Altera Virtual JTAG (VJTAG) megafunction exposes a TAP (Test Access Port) interface to the user.
- A custom finite state machine (FSM) decodes VJTAG commands and executes read/write operations
- The bus converter convert the request into output bus.
- The host program communicates via USB-Blaster using the Quartus JTAG API or Python-JTAG tools.

## Command

Each command transaction consists of several bytes:

```
Command (1 byte) - Address (2-4 byte) - Data (2-4 byte)
```

The number of address byte and number of data byte is configurable through parameters

### List of Commands

| Command            | CMD ID |
| ------------------ | ------ |
| IDLE               | 0x00   |
| Single Write       | 0x01   |
| Single Read        | 0x02   |
| Reset Assertion    | 0xFE   |
| Reset De-assertion | 0xFF   |

### Command details

| Command            | Format                        | Description                |
| ------------------ | ----------------------------- | -------------------------- |
| IDLE (Read back)   | `0x00`                        |
| Reset Assertion    | `0xFE`                        | Assert the `rst_n_out`.    |
| Reset De-assertion | `0xFF`                        | De-assert the `rst_n_out`. |
| Single Write       | `0x01 - Address - Write Data` | Single write.              |
| Single Read        | `0x02 - Address`              | Single read.               |

## Implementation

Implementation document can be found in [vjtag.md](./doc/vjtag.md)

Currently support the following standard bus protocol:

- Wishbone B4 pipeline protocol: [vjtag2wb.sv](rtl/vjtag/vjtag2wb.sv)

## RTL File

| File                      | Description                                                            |
| ------------------------- | ---------------------------------------------------------------------- |
| `rtl/vjtag/vjtag_ip.v`    | Altera Virtual JTAG IP.                                                |
| `rtl/vjtag/vjtag_ctrl.sv` | Virtual JTAG control. Decode the command and convert it to bus request |
| `rtl/vjtag/vjtag2wb.sv`   | Virtual JTAG to wishbone interface                                     |

## VJTAG Tool

A tcl script [vjtag_host.tcl](tools/VJTAG/vjtag_host.tcl) is created to interact with the target FPGA to transfer data
between the host machine and the FPGA. Quartus need to be installed in order to use the tool.

### Config file

A config file [config.json](tools/VJTAG/config.json) defines necessary information for the design.

```json
"instance_id": 0               // The VJTAG instance id in the design.
                               // Search for 'sld_instance_index' in the synthesis report to get the value
"addr_byte": 2                 // number of addr byte
"data_byte": 2                 // number of data byte
```

### Script usage

```shell
# Show help message
./vjtag_host.sh -h

# Enter interactive shell
./vjtag_host.sh

# Program a ram/hex file at given address. addr can be omitted if address start at 0
./vjtag_host.sh file [addr]
```

#### Command in interactive shell mode

```bash
> help                            # print help message
> exit                            # exit the command
> read    <address>               # read date at <address>
> write   <address> <data>        # write <data> to <address>
> program <address> <file>        # program a RAM or continuous memory space starting at <address> using content in the <file>.
```

## References

**Altera Virtual JTAG**

- [Intel Virtual JTAG User Guide](https://www.intel.com/content/www/us/en/docs/programmable/683297/)

**Altera TCL programming**

- [Intel Quartus Prime Standard Edition User Guide: Scripting](https://www.intel.com/content/www/us/en/docs/programmable/683325/18-1/command-line-scripting.html)
- [Intel TCL Commands and Packages](https://www.intel.in/content/www/in/en/programmable/quartushelp/current/index.htm#tafs/tafs/tafs.htm)