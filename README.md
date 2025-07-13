# Virtual JTAG Host

This project implements an interface using Altera Virtual JTAG to directly read and write on-chip memory in an FPGA design.
So you can use Altera USB blaster to access your on-chip memory system (e.g., BRAM, registers, etc.).

## Block Diagram

```text
    +---------------------+                 +---------------------+                 +---------------------+
    |     Host (PC)       |   USB-Blaster   |   Virtual JTAG TAP  |  Control FSM    |   On-Chip Memory    |
    |  vjtag_host.py      | --------------> |  (vjtag_interface)  | --------------> |    (Dual Port RAM)  |
    +---------------------+                 +---------------------+                 +---------------------+
```

## How it work

- The Virtual JTAG (VJTAG) megafunction exposes a TAP (Test Access Port) via USB-Blaster.
- A custom FSM inside the FPGA interprets JTAG commands as read/write instructions.
- Memory content is read from or written to on-chip RAM in real-time.
- The host program communicates via USB-Blaster using the Quartus JTAG API or Python-JTAG tools.

## VJtag Host Command

### Format

Each transaction consists of the following sequence.

```
Command (1-byte) - Address - Data (optional)
```

- Command indicates the bus operation.
- Address is the address of the transaction
- Data is the write data.
- Address, and Data length depends on the system and is configurable through parameter

### List of Commands

| Command            | CMD ID |
| ------------------ | ------ |
| Single Write       | 0x01   |
| Single Read        | 0x02   |
| Reset Assertion    | 0xFE   |
| Reset De-assertion | 0xFF   |

## Implementation

### Parameter

### Interface

### Design Implementation

#### VIR and VDR Registers

The control logic uses the Virtual Instruction Register (VIR) to select one of several Virtual Data Registers (VDR) to
hold the command, address, and the data to be put on the bus.

**Implemented VDR Registers**:

| VIR Value | VDR Index | Description                                                             |
| --------- | --------- | ----------------------------------------------------------------------- |
| 0         | VDR[0]    | Command Register: Specifies read/write operations and triggers actions. |
| 1         | VDR[1]    | Address Register: Specifies the target address in on-chip memory.       |
| 2         | VDR[2]    | Data Register: Holds data to be written or captures data to be read.    |

- FIXME: Need a new VDR to indicate the rdata is valid?. How does jtag know if the rdata is ready or not? Keep pulling?

#### Bus Access Process

After receiving all required values through VDR: the command, address, and write data (for write command).
The control logic generates a request to access the on-chip bus.

For write operations, the data in VDR[2] is written to the specified memory location.

For read operations, data from the memory is placed into VDR[2], where the host can read it back.

## References

- [Intel Virtual JTAG User Guide](https://www.intel.com/content/www/us/en/docs/programmable/683297/)
