`timescale 1ns/1ps

module Cfu (
  input         cmd_valid,
  output        cmd_ready,
  input  [9:0]  cmd_payload_function_id,
  input  [31:0] cmd_payload_inputs_0,
  input  [31:0] cmd_payload_inputs_1,
  output reg    rsp_valid,
  input         rsp_ready,
  output reg [31:0]   rsp_payload_outputs_0,
  input     reset,
  input     clk,
  output wire[29:0] cfu_ram_adr,
  output wire[31:0] cfu_ram_dat_mosi,
  output wire[3:0] cfu_ram_sel,
  output wire cfu_ram_cyc,
  output wire cfu_ram_stb,
  output wire cfu_ram_we,
  output wire[2:0] cfu_ram_cti,
  output wire[1:0] cfu_ram_bte,
  input wire[31:0] cfu_ram_dat_miso,
  input wire cfu_ram_ack,
  input wire cfu_ram_err
);
  localparam InputOffset = $signed(9'd128);

  // SIMD multiply step:
  wire signed [15:0] prod_0, prod_1, prod_2, prod_3;

  logic [31:0] matrix_vals = 0;
  logic [31:0] filter_vals = 0;

  assign prod_0 =  ($signed(matrix_vals[7 : 0]) + InputOffset)
      * $signed(filter_vals[7 : 0]);
  assign prod_1 =  ($signed(matrix_vals[15: 8]) + InputOffset)
      * $signed(filter_vals[15: 8]);
  assign prod_2 =  ($signed(matrix_vals[23:16]) + InputOffset)
      * $signed(filter_vals[23:16]);
  assign prod_3 =  ($signed(matrix_vals[31:24]) + InputOffset)
      * $signed(filter_vals[31:24]);

  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3;

  typedef enum {
    PIPELINE_STATE_INIT,
    PIPELINE_STATE_EXEC_0,
    PIPELINE_STATE_EXEC_1_FETCH_VAL,
    PIPELINE_STATE_EXEC_1_FETCH_FILTER,
    PIPELINE_STATE_EXEC_1_ADD
  } fetch_multiply_state;

  fetch_multiply_state cur_state = PIPELINE_STATE_INIT;
  fetch_multiply_state next_state;

  assign cfu_ram_sel = 4'b1111;
  assign cfu_ram_cti = 0;
  assign cfu_ram_bte = 0;
  assign cfu_ram_we = 0;

  always_comb begin
    next_state = cur_state;

    case (cur_state)
      PIPELINE_STATE_INIT: begin
          if (cmd_valid) begin
            if (|cmd_payload_function_id[9:3]) next_state = PIPELINE_STATE_EXEC_0;
            else next_state = PIPELINE_STATE_EXEC_1_FETCH_VAL;
          end
      end

      PIPELINE_STATE_EXEC_0: begin
        next_state = PIPELINE_STATE_INIT;
      end

      PIPELINE_STATE_EXEC_1_FETCH_VAL: begin
        if (cfu_ram_ack) next_state = PIPELINE_STATE_EXEC_1_FETCH_FILTER;
        if (cfu_ram_err) next_state = PIPELINE_STATE_EXEC_1_FETCH_VAL;
      end

      PIPELINE_STATE_EXEC_1_FETCH_FILTER: begin
        if (cfu_ram_ack) next_state = PIPELINE_STATE_EXEC_1_ADD;
        if (cfu_ram_err) next_state = PIPELINE_STATE_EXEC_1_FETCH_FILTER;
      end

      PIPELINE_STATE_EXEC_1_ADD: begin
        next_state = PIPELINE_STATE_INIT;
      end
       
      default: begin
      end
    endcase
  end


  // Only not ready for a command when we have a response.
  // assign cmd_ready = (cur_state == PIPELINE_STATE_INIT) & ;
  // logic ready;
  assign cmd_ready = cur_state == PIPELINE_STATE_INIT;

  always_ff @(negedge clk or posedge reset) begin
    cur_state <= next_state;

    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
      cur_state <= PIPELINE_STATE_INIT;
      // ready <= 1;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
      // ready <= 1;
    end else if (cmd_valid) begin
      // ready <= 0;
      rsp_valid <= (
        (cur_state == PIPELINE_STATE_EXEC_0) |
        (cur_state == PIPELINE_STATE_EXEC_1_ADD)
      );

      case (cur_state)
      PIPELINE_STATE_EXEC_0: rsp_payload_outputs_0 <= 32'b0;

      PIPELINE_STATE_EXEC_1_FETCH_VAL: begin
          cfu_ram_adr <= cmd_payload_inputs_0[31:2];

          cfu_ram_cyc <= 1;
          cfu_ram_stb <= 1;

          if (cfu_ram_ack) begin
            matrix_vals <= cfu_ram_dat_miso;
          end
      end

      PIPELINE_STATE_EXEC_1_FETCH_FILTER: begin
          cfu_ram_adr <= cmd_payload_inputs_1[31:2];

          cfu_ram_cyc <= 1;
          cfu_ram_stb <= 1;

          if (cfu_ram_ack) begin
            filter_vals <= cfu_ram_dat_miso;
          end
      end

      PIPELINE_STATE_EXEC_1_ADD: begin
        rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;

        cfu_ram_cyc <= 0;
        cfu_ram_stb <= 0;
      end

      default: begin
        cfu_ram_cyc <= 0;
        cfu_ram_stb <= 0;
      end
      endcase
    end
  end
endmodule
