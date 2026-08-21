# LDPC Latency Simulation

RTL modules used to simulate LDPC encoder and decoder latency in the POLARA L2 cache. Enabled with `SIMULATE_LDPC_LATENCY`.

Standalone testbenches verify data propagation and latency, ready/valid behavior, and backpressure handling.

## Components

### Encoder Simulator

[`ldpc_encoder_simulator.sv`](ldpc_encoder_simulator.sv) is used to validate the encoder placement in the L2 pipeline while preserving the original data format.

By default, the encoder is combinational. The `PIPELINE` parameter can enable a 1-cycle pipeline stage to evaluate the impact of encoder latency on the L2 datapath.

### L2 Delay Buffer

[`L2_delay_buffer.sv`](L2_delay_buffer.sv) introduces a configurable number of latency cycles while preserving the ready/valid handshake and propagating backpressure through the pipeline.

It is primarily used to simulate the latency of the LDPC decoder before integrating the actual decoder RTL.
