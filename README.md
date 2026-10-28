# MIPS64 Pipelined Processor — Verilog & Vivado

A 64-bit MIPS-style pipelined processor implemented in Verilog HDL and developed using Xilinx Vivado. The project explores processor architecture, instruction execution, pipeline design, data forwarding, hazard handling, branching, jumping, and multiplication/division operations.

## Overview

The processor uses a five-stage instruction pipeline to organize instruction execution into separate stages. Pipeline registers transfer data and control signals between stages, allowing multiple instructions to be processed concurrently.

### Key Features

- 64-bit MIPS-style processor datapath
- Five-stage pipelined architecture
- Instruction fetch and decode
- Register file and ALU-based execution
- Instruction and data memory
- Pipeline register implementation
- Data forwarding for handling data dependencies
- Hazard detection for load-use dependencies
- Branch and jump control logic
- HI/LO register support for multiplication and division operations
- Verilog-based RTL design
- Testbench-based functional verification
- Simulation and synthesis using Xilinx Vivado

## Processor Architecture

The processor follows a five-stage pipeline:

| Stage | Name | Description |
|---|---|---|
| IF | Instruction Fetch | Fetches the instruction using the program counter (PC). |
| ID | Instruction Decode | Decodes the instruction and reads register operands. |
| EX | Execute | Performs ALU operations, evaluates branch conditions, and calculates addresses. |
| MEM | Memory Access | Performs data memory operations for load and store instructions. |
| WB | Write Back | Writes the result back into the register file. |

### Pipeline Flow

```text
       ┌────────────┐
       │ Instruction│
       │   Fetch    │
       │    (IF)    │
       └─────┬──────┘
             │
        IF/ID Register
             │
       ┌─────▼──────┐
       │ Instruction│
       │   Decode   │
       │    (ID)    │
       └─────┬──────┘
             │
        ID/EX Register
             │
       ┌─────▼──────┐
       │  Execute   │
       │    (EX)    │
       └─────┬──────┘
             │
       EX/MEM Register
             │
       ┌─────▼──────┐
       │   Memory   │
       │    (MEM)   │
       └─────┬──────┘
             │
       MEM/WB Register
             │
       ┌─────▼──────┐
       │ Write Back │
       │    (WB)    │
       └────────────┘
```

## Hazard Handling

The design includes mechanisms to handle dependencies and control-flow changes in the pipeline.

### Data Forwarding
Forwarding logic selects results from later pipeline stages when an instruction depends on a previous instruction's result. This reduces unnecessary pipeline stalls.

### Hazard Detection
Hazard detection logic identifies dependencies that require additional handling, including load-use hazards.

### Branching and Jumping
Branch and jump control logic updates the program counter according to control-flow instructions.

### Multiplication and Division
The design includes HI/LO-related logic for handling multiplication and division operations.

## Project Structure

The repository is organized around the processor RTL, supporting modules, testbench, and instruction-memory initialization files.

```text
MIPS/
├── RTL/
│   ├── mips64_top.v
│   ├── instr_mem.v
│   ├── Other processor modules
│   └── Pipeline and control modules
├── testbench/
│   └── tb_mips64_top.v
├── sw/
   └── hex/
     └── program.hex





