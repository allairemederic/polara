# LDPC Latency Simulation

These RTL modules evaluate the impact of ECC latency in the POLARA L2 cache before integrating the complete LDPC implementation.

The simulation is enabled with the `SIMULATE_LDPC_LATENCY` compilation macro.

## L2 Cache Architecture

Two models were evaluated:
- **NoC model:** adds one cycle before the L2 input and three cycles after its output
- **Datapath model:** adds four cycles to the L2 read path near the future decoder location


Detailed integration instructions are available for the [NoC model](integration/noc-delay.md) and the [datapath model](integration/datapath.md).

## RTL Components

### Encoder Simulator

[`ldpc_encoder_simulator.sv`](modules/encoder_simulator.sv) preserves the 144-bit L2 data format and validates the encoder insertion points.

The `PIPELINE` parameter selects a combinational implementation or adds one latency cycle.

### L2 Delay Buffer

[`L2_delay_buffer.sv`](modules/L2_delay_buffer.sv) adds a configurable number of cycles to a ready/valid interface.

When `DEBUG_L2_DELAY_BUFFER` is enabled, the module also provides hardware counters for:

- accepted transactions (`valid_i && ready_o`)
- input stall cycles (`valid_i && !ready_o`)
- output stall cycles (`valid_o && !ready_i`)

These counters can be monitored with an Integrated Logic Analyzer (ILA) to characterize buffer activity and backpressure.