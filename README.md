# IIR Butterworth Filter IP

Digital Implementation of 6th-Order Analog Butterworth Low-Pass Filter using Cascaded Second-Order Sections (SOS) with Wishbone B4 Interface.

![Verilog](https://img.shields.io/badge/Language-Verilog-blue)
![FPGA](https://img.shields.io/badge/Target-Cyclone%20II-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 🎯 Features

- **4-Stage Pipelined Architecture** for high Fmax
- **Q11.20 Fixed-Point** precision (32-bit data, 20 fractional bits)  
- **Hardware Saturation** prevents overflow wrap-around
- **Wishbone B4 Interface** for SoC integration
- **Runtime Configurable Coefficients** via register map
- **Overflow Detection** with sticky status flags
- **Self-Checking Testbench** with automated pass/fail

## 📁 Project Structure

```
FinalPJ/
├── IIR_3sec/                    # Enhanced version (recommended)
│   ├── iir_sos_pipeline.v       # 4-stage pipelined SOS module
│   ├── iir_top.v                # Top module (3 cascaded SOS)
│   ├── iir_wishbone.v           # Wishbone wrapper
│   ├── iir_wishbone.sdc         # Timing constraints (50 MHz)
│   └── iir_wishbone_tb.v        # Self-checking testbench
├── iir_sos.v                    # Basic SOS (non-pipelined)
├── iir_top.v                    # Basic top module
├── iir_wishbone.v               # Basic Wishbone wrapper
└── FinalPJ.qpf/.qsf             # Quartus project files
```

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────┐
│                     iir_wishbone                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                     iir_top                           │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐      │  │
│  │  │  SOS #1    │─▶│  SOS #2    │─▶│  SOS #3    │─▶ y  │  │
│  │  │ (Pipeline) │  │ (Pipeline) │  │ (Pipeline) │      │  │
│  │  └────────────┘  └────────────┘  └────────────┘      │  │
│  └──────────────────────────────────────────────────────┘  │
│                    Wishbone B4 Interface                    │
└────────────────────────────────────────────────────────────┘
```

## 📊 Synthesis Results (Cyclone II)

| Resource | Utilization |
|----------|-------------|
| Logic Elements | 655 LEs |
| Registers | 440 |
| Clock Frequency | 50 MHz |
| DSP Blocks | 0 (pure logic) |

## 🔧 Wishbone Register Map

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| 0x00 | X | R/W | Input sample |
| 0x04 | Y | R | Output sample |
| 0x08 | STATUS | R | Overflow flags (clear on read) |
| 0x10-0x20 | Section 1 | R/W | b0, b1, b2, a1, a2 |
| 0x24-0x34 | Section 2 | R/W | b0, b1, b2, a1, a2 |
| 0x38-0x48 | Section 3 | R/W | b0, b1, b2, a1, a2 |

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/iir-butterworth-filter.git
   ```

2. **Open in Quartus II**
   - Open `FinalPJ.qpf` in Quartus II
   - Use files from `IIR_3sec/` folder for synthesis

3. **Run Simulation**
   ```bash
   # Using ModelSim
   vlog IIR_3sec/*.v
   vsim -c iir_wishbone_tb -do "run -all"
   ```

## 📐 Filter Specifications

- **Type:** Butterworth Low-Pass
- **Order:** 6th (3 × 2nd-order sections)
- **Cutoff:** ~1% of sampling frequency (configurable)
- **Precision:** Q11.20 fixed-point

## 📄 License

This project is open source under the MIT License.

## 👤 Author

Solo IP Design & Verification Engineer - CE213 HDL Course Project
