# Fused QKᵀ–Softmax RTL Engine

This repository contains a memory‑efficient, fully quantized RTL implementation of a fused **QKᵀ–Softmax** hardware engine designed for edge FPGA/ASIC systems.  
It implements a **three‑pass streaming architecture** that reduces on‑chip memory from O(N²) to O(N), supported by lookup‑table (LUT)‑based exponential and reciprocal units for hardware‑friendly softmax normalization.

---

## Architecture Overview

### **High‑Level Architecture Block Diagram**
![Architecture_block_diagram](https://github.com/CRN4X/fused-softmax-engine/blob/main/assets/architecture_block_diagram.png)

---

### **RTL Implementation Workflow**
![RTL_workflow](https://github.com/CRN4X/fused-softmax-engine/blob/main/assets/RTL_workflow.png)

---

## How to Use

### **1. Generate Quantized Q and K Matrices**
Run the Python script to generate Q, K, and Kᵀ matrices from BERT-base-uncased embeddings and quantize them to INT8:
```cd data
python generate_data.py
```

This will create the following files:
```
Q_matrix_fixed_scale.txt
K_matrix_fixed_scale.txt
```
These matrices are used as input stimuli for RTL simulation.

### **2. Run RTL Simulation**
Open ```Vivado 2024.2```
Create a new project targeting ```Kintex UltraScale+ KCU116``
Add all .v source files from src/ and the .xdc file from constraints/
Set testbench.v as the top module
Launch behavioral simulation to verify functionality using generated binary matrices
Confirm MAE < 2% compared to FP32 reference (verified via waveform or log output)


### **3. Synthesize and Implement**
Run synthesis and implementation to gather hardware metrics:
```
Area (LUT/DSP/register utilization)
Power (dynamic, static, total)
Timing and frequency reports
On‑chip memory footprint
```

Expected metrics:
```
LUTs     : ~1586
DSPs     : 1
Registers: 3466
Memory   : 968 bytes
Power    : ~500 mW @ 100 MHz
Latency  : 4290 cycles per attention row
```


### **4. Evaluate Results**
Compare RTL results against FP32 reference using generated softmax outputs. You can visualize accuracy metrics using provided Python utilities or replicate MAE vs Softmax Width (Q0.x) curves.

Expected performance:

| Metric | Achieved | Target |
|---------|-----------|--------|
| MAE | 0.98% | < 2.0% |
| Effective Reciprocal Precision | 9-bit | ≥ 9-bit |
| Frequency | 100 MHz | ≥ 100 MHz |
| Dynamic Power | ~500 mW | ≤ 500 mW |

---

## Outputs

- Quantized Softmax Probabilities (INT8 Q0.8)  
- Functional verification outputs (from Vivado console)  
- Synthesis, timing, and power reports  

---

## Key Features

- Fully integer-based design (no floating-point operations)  
- Exponential and reciprocal LUT implementation  
- Running-max stability tracking for numerical precision  
- Streamed computation with O(N) memory buffering  
- Edge‑friendly power and memory efficiency  

