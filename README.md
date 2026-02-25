# FPGA ARC4 Decryption & Parallel Cracking Circuit
### Hardware Implementation of Stream Cipher Decryption and Parallel Brute-Force Key Search
## Overview

This project implements a complete hardware-based ARC4 (RC4) cryptographic engine on the Intel Cyclone V FPGA (DE1-SoC). The design supports:

- ARC4 state initialization
- Key-Scheduling Algorithm (KSA)
- Pseudo-Random Generation Algorithm (PRGA)
- Ciphertext decryption
- Brute-force key recovery
- Parallel key search acceleration

The system is written entirely in SystemVerilog, synthesized in Intel Quartus Prime, and verified through both RTL and post-synthesis simulation in ModelSim.

The final implementation includes a dual-core parallel cracking engine capable of searching the 24-bit key space approximately twice as fast as a single-core design.

## Key Features

- Full ARC4 decryption pipeline implemented in hardware
- On-chip memory architecture using M10K embedded RAM blocks
- Custom ready/enable microprotocol for variable-latency modules
- Brute-force 24-bit key search engine
- Parallel dual-core cracking architecture
- Comprehensive RTL and post-synthesis testbenches
- Live FPGA memory inspection using In-System Memory Content Editor
- Seven-segment display output of recovered keys

## Architecture

### High-Level System Diagram

High-Level System Diagram

    Ciphertext Memory (CT)
            │
            ▼
         ARC4 Core
     ┌───────────────┐
     │   init (S)    │
     │   ksa         │
     │   prga + xor  │
     └───────────────┘
            │
            ▼
     Plaintext Memory (PT)

For cracking mode:

           Ciphertext (shared)
                 │
        ┌────────┴────────┐
        ▼                 ▼
    Crack Core 1      Crack Core 2
    (even keys)        (odd keys)
        │                 │
        └──────► Shared Plaintext

## Technical Details

### ARC4 State Initialization

- Implements S[i] = i for i ∈ [0,255]
- Writes sequential values into on-chip RAM
- Controlled via a ready/enable handshake

### Key-Scheduling Algorithm (KSA)

Implements:

    j = (j + S[i] + key[i mod 3]) mod 256
    swap(S[i], S[j])

- 24-bit big-endian key
- Hardware-based swap operations
- Fully sequential FSM-based implementation
- Verified against reference software implementation

### Pseudo-Random Generation Algorithm (PRGA)

Generates keystream and performs decryption:

    pad[k] = S[(S[i] + S[j]) mod 256]
    plaintext[k] = ciphertext[k] XOR pad[k]

- Supports length-prefixed messages (Pascal-style encoding)
- Reads from ciphertext memory
- Writes decrypted output to plaintext memory

### Brute-Force KeyB Recovery Engine

The cracking module:
- Iterates through the full 24-bit key space
- Decrypts ciphertext for each candidate key
- Validates plaintext by checking printable ASCII range

Outputs:
- key
- key_valid
- Length-prefixed plaintext (if found)

If no valid key exists:
- Displays “------” on FPGA seven-segment displays

### Parallel Key Search (Dual-Core Cracker)

To accelerate search:
- Core 1 searches keys: 0, 2, 4, 6, ...
- Core 2 searches keys: 1, 3, 5, 7, ...
- Shared ciphertext memory
- Shared output plaintext memory
- First successful core terminates search

This achieves approximately 2× speedup over the single-core implementation.

## Memory Architecture

- 256 × 8-bit
- Implemented using Cyclone V M10K embedded SRAM
- Single-clock, synchronous write
- Accessible during FPGA runtime for debugging

Memories used:
- S — ARC4 internal state
- CT — Ciphertext input
- PT — Plaintext output

## Design Constraints

- Positive-edge triggered sequential logic only
- Active-low synchronous reset
- No combinational loops
- No latches
- No tristate logic
- Strict hierarchical memory naming for testbench access

## Verification Strategy

Each module was verified using:
- RTL simulation (behavioral)
- Post-synthesis netlist simulation
- Hierarchical memory inspection
- Reference software implementation comparison
- FPGA hardware validation

Testbenches include:
- Unit-level validation (init, ksa, prga)
- Integrated ARC4 validation
- rack module validation
- Parallel cracking validation

## Technologies Used

- SystemVerilog
- Intel Quartus Prime
- ModelSim
- Cyclone V FPGA (DE1-SoC)
- Embedded M10K memory blocks
- In-System Memory Content Editor

## Example Use Case

Using a known ciphertext stored in memory:
- Load encrypted message into CT memory
- Provide 24-bit key via switches
- ARC4 engine decrypts message into PT memory

For cracking mode:
- Load ciphertext
- System brute-forces entire key space
- Valid key automatically displayed on FPGA
- Decrypted plaintext stored in memory

## Learning Outcomes & Engineering Skills Demonstrated

- Hardware implementation of cryptographic algorithms
- FSM design for multi-phase algorithms
- Embedded memory design and debugging
- Hardware-software equivalence verification
- Handshake-based microprotocol design
- Parallel hardware architecture
- FPGA-based system integration
- Performance optimization via parallelism

## Future Improvements

- Expand to larger key sizes
- Pipeline KSA and PRGA for higher throughput
- Add more parallel cracking cores
- Integrate UART output for plaintext display
- Add hardware timer to benchmark cracking performance

## Repository Structure

- task1/      → State initialization
- task2/      → Key scheduling
- task3/      → ARC4 decryption
- task4/      → Single-core brute-force cracking
- task5/      → Dual-core parallel cracking

## Summary

This project demonstrates a complete end-to-end hardware implementation of a classical stream cipher and a scalable brute-force cryptanalysis engine. It highlights FPGA memory design, modular hardware architecture, handshake protocols, and parallel acceleration techniques.
