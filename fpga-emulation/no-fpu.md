# Disabling Floating-Point Support

Floating-point support can be disabled during FPGA synthesis using the NO_FPU_SUPPORT compilation macro. This reduces FPGA resource utilization and was used for the 2×2 POLARA configuration on the Alveo U280..

## CVA6

Modified file: ariane_pkg.sv

The RVF and RVD extensions are disabled when NO_FPU_SUPPORT is defined:

```systemverilog
`ifdef NO_FPU_SUPPORT
    localparam bit RVF = 1'b0;
    localparam bit RVD = 1'b0; 
`elsif PITON_ARIANE
    localparam bit RVF = riscv::IS_XLEN64;
    localparam bit RVD = riscv::IS_XLEN64;
```

## Ara

Modified file: ara_verilog_wrap.sv

The FPUSupport parameter is set to FPUSupportNone when NO_FPU_SUPPORT is enabled:

```systemverilog
`ifdef NO_FPU_SUPPORT
    parameter fpu_support_e FPUSupport = FPUSupportNone,
`else
    parameter fpu_support_e FPUSupport = FPUSupportHalfSingleDouble,
`endif
```