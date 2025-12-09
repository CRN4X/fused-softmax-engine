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
Run the following file from the data/ directory to generate Q and K matrices from BERT-base-uncased embeddings and quantize them to INT8:
```cd data
autoAiDataGeneration.ipynb file
```

This will create the following files:
```
Q_matrix_fixed_scale.txt
K_matrix_fixed_scale.txt
Q_float_normalized_fixed_scale
K_float_normalized_fixed_scale
```
The first two files are used as input to RTL Softmax engine and the last two to measure MAE%

### **2. Run RTL Simulation**
- Open ```Vivado 2024.2``` software application and create a new project targeting ```Kintex UltraScale+ KCU116```
- Add all the source files from src/ directory
- Add the testbench file ```top_qkt_softmax.sv``` from testbench/ directory and the input test vector text files from the data/ directory as simulation sources
- Also add XDC file from the constraints/ directory as constraints
- Launch behavioral simulation to verify functionality using generated binary matrices
- Confirm MAE < 2% compared to FP32 reference (verified via waveform or log output)


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
LUTs     : 1602
DSPs     : 1
Registers: 3477
Memory   : 584 bytes
Power    : 102 mW @ 100 MHz
Latency  : 4291 cycles per attention row
```


### **4. Evaluate Results**
Compare RTL results against FP32 reference using generated softmax outputs. You can visualize accuracy metrics using provided Python utilities or replicate MAE vs Softmax Width (Q0.x) curves.

Expected performance:

| Metric | Achieved | Target |
|---------|-----------|--------|
| MAE | 0.98% | < 2.0% |
| Effective Reciprocal Precision | 9-bit | ≥ 9-bit |
| Frequency | 100 MHz | ≥ 100 MHz |
| Dynamic Power | 102 mW | ≤ 500 mW |

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

