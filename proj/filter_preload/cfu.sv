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
  // ------------------------------
  // Finite automata states
  // ------------------------------

  typedef enum {
    PIPELINE_STATE_INIT,
    PIPELINE_STATE_EXEC_CONV_FETCH_VAL,
    PIPELINE_STATE_EXEC_CONV_FETCH_FILTER,
    PIPELINE_STATE_EXEC_CONV_ADD,
    PIPELINE_STATE_EXEC_CONV_CALC_COORDS,
    // This is here because every state after this one is the final one for
    // the CFU. This means that after this, the cfu should go back to
    // PIPELINE_STATE_INIT, thus should be ready for the next command
    PIPELINE_STATE_EXEC_CONV_DONE = 'hFF,
    PIPELINE_STATE_EXEC_SET_ZEROES,
    PIPELINE_STATE_EXEC_SET_FILTER_DIMS,
    PIPELINE_STATE_EXEC_SET_IMAGE_DIMS,
    PIPELINE_STATE_EXEC_SET_INPUT_CHANNEL_SHAPE,
    PIPELINE_STATE_EXEC_SET_IMAGE_COORDS,
    PIPELINE_STATE_EXEC_SET_FILTER_INPUT_STRIDE,
    PIPELINE_STATE_EXEC_SET_BATCH_OUT_CHANNEL,
    PIPELINE_STATE_EXEC_SET_IMAGE_FILTER_ADR
  } fetch_multiply_state;

  fetch_multiply_state cur_state = PIPELINE_STATE_INIT;
  fetch_multiply_state next_state;

  // ------------------------------
  // Wishbone RAM interface variables
  // ------------------------------

  assign cfu_ram_sel = 4'b1111;
  assign cfu_ram_cti = 0;
  assign cfu_ram_bte = 0;
  assign cfu_ram_we = 0;

  // ------------------------------
  // Convolution setup
  // ------------------------------
  reg [8:0] InputOffset = $signed(9'd128);
  reg [31:0] cur_input_depth = 0;

  // ------------------------------
  // Filter shape
  // ------------------------------
  reg [31:0] filter_base = 0;
  reg [15:0] filter_width = 1;
  reg [15:0] filter_height = 1;
  reg [15:0] filter_input_depth = 1;
  reg [15:0] out_channel = 0;

  reg [15:0] cur_filter_x = 0;
  reg [15:0] cur_filter_y = 0;
  reg [31:0] cur_filter_adr = 0;

  assign cur_filter_adr = 
    filter_base + 
    ((out_channel * filter_height + cur_filter_y) * filter_width + cur_filter_x) * filter_input_depth
    + cur_input_depth;

  // ------------------------------
  // Image shape
  // ------------------------------
  reg [31:0] image_base = 0;
  reg [15:0] batch = 0;
  reg [15:0] image_width = 1;
  reg [15:0] image_height = 1;
  reg [15:0] input_channel_depth = 1;

  reg [15:0] cur_image_x = 0;
  reg [15:0] cur_image_y = 0;
  reg [31:0] cur_image_adr = 0;

  assign cur_image_adr = 
      image_base +
      (((batch * image_height + cur_image_y + cur_filter_y) *
        image_width + cur_image_x + cur_filter_x) *
        input_channel_depth + cur_input_depth);

  wire [3:0] add_select = '1;
  // I should do generate for here, but i'm too lazy to google the syntax, hehe
  assign add_select[0] = (cur_image_x + cur_filter_x < image_width) & (cur_filter_x < filter_width) & (cur_input_depth     < input_channel_depth);
  assign add_select[1] = (cur_image_x + cur_filter_x < image_width) & (cur_filter_x < filter_width) & (cur_input_depth + 1 < input_channel_depth);
  assign add_select[2] = (cur_image_x + cur_filter_x < image_width) & (cur_filter_x < filter_width) & (cur_input_depth + 2 < input_channel_depth);
  assign add_select[3] = (cur_image_x + cur_filter_x < image_width) & (cur_filter_x < filter_width) & (cur_input_depth + 3 < input_channel_depth);


  // SIMD multiply step:
  wire signed [15:0] prod_0, prod_1, prod_2, prod_3;

  reg [31:0] matrix_vals = 0;
  reg [31:0] filter_vals = 0;

  assign prod_0 =  add_select[0] ? (($signed(matrix_vals[7 : 0]) + $signed(InputOffset))
      * $signed(filter_vals[7 : 0])) : 0;
  assign prod_1 =  add_select[1] ? (($signed(matrix_vals[15: 8]) + $signed(InputOffset))
      * $signed(filter_vals[15: 8])) : 0;
  assign prod_2 =  add_select[2] ? (($signed(matrix_vals[23:16]) + $signed(InputOffset))
      * $signed(filter_vals[23:16])) : 0;
  assign prod_3 =  add_select[3] ? (($signed(matrix_vals[31:24]) + $signed(InputOffset))
      * $signed(filter_vals[31:24])) : 0;

  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3;

  always_comb begin
    next_state = cur_state;

    case (cur_state)
      default: next_state = PIPELINE_STATE_INIT;

      PIPELINE_STATE_INIT: begin
          if (cmd_valid) begin
              case (cmd_payload_function_id[9:3])
                  7'd0: next_state = PIPELINE_STATE_EXEC_CONV_FETCH_VAL;
                  7'd1: next_state = PIPELINE_STATE_EXEC_SET_ZEROES;
                  7'd2: next_state = PIPELINE_STATE_EXEC_SET_FILTER_DIMS;
                  7'd3: next_state = PIPELINE_STATE_EXEC_SET_IMAGE_DIMS;
                  7'd4: next_state = PIPELINE_STATE_EXEC_SET_INPUT_CHANNEL_SHAPE;
                  7'd5: next_state = PIPELINE_STATE_EXEC_SET_IMAGE_COORDS;
                  7'd6: next_state = PIPELINE_STATE_EXEC_SET_IMAGE_FILTER_ADR;
                  7'd7: next_state = PIPELINE_STATE_EXEC_SET_FILTER_INPUT_STRIDE;
                  7'd8: next_state = PIPELINE_STATE_EXEC_SET_BATCH_OUT_CHANNEL;
                  default: next_state = PIPELINE_STATE_INIT;
              endcase
          end else next_state = PIPELINE_STATE_INIT;
      end

      PIPELINE_STATE_EXEC_CONV_FETCH_VAL: begin
        if (cfu_ram_ack) next_state = PIPELINE_STATE_EXEC_CONV_FETCH_FILTER;
        if (cfu_ram_err) next_state = PIPELINE_STATE_EXEC_CONV_FETCH_VAL;
      end

      PIPELINE_STATE_EXEC_CONV_FETCH_FILTER: begin
        if (cfu_ram_ack) next_state = PIPELINE_STATE_EXEC_CONV_ADD;
        if (cfu_ram_err) next_state = PIPELINE_STATE_EXEC_CONV_FETCH_FILTER;
      end

      PIPELINE_STATE_EXEC_CONV_ADD: begin
        next_state = PIPELINE_STATE_EXEC_CONV_CALC_COORDS;
      end

      PIPELINE_STATE_EXEC_CONV_CALC_COORDS: begin
        if (
            (cur_filter_y >= filter_height) |
            ((cur_image_y + cur_filter_y) >= image_height)
        ) next_state = PIPELINE_STATE_EXEC_CONV_DONE;
        else next_state = PIPELINE_STATE_EXEC_CONV_FETCH_VAL;
      end
    endcase
  end


  // Only not ready for a command when we have a response.
  assign cmd_ready = cur_state == PIPELINE_STATE_INIT;

  always @(negedge clk or posedge reset or posedge cfu_ram_ack) begin

    if (reset) begin
      cur_filter_x <= 0;
      cur_filter_y <= 0;
      cur_input_depth <= 0;
      rsp_payload_outputs_0 <= 32'b0;

      rsp_valid <= 1'b0;
      cur_state <= PIPELINE_STATE_INIT;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      cur_state <= next_state;
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      cur_state <= next_state;
      rsp_valid <= (next_state >= PIPELINE_STATE_EXEC_CONV_DONE);

      case (cur_state)
      PIPELINE_STATE_EXEC_SET_ZEROES: begin
        rsp_payload_outputs_0 <= 32'b0;
        cur_filter_x <= '0;
        cur_filter_y <= '0;
      end

      PIPELINE_STATE_EXEC_SET_INPUT_CHANNEL_SHAPE: begin
        input_channel_depth <= cmd_payload_inputs_0;
        InputOffset <= cmd_payload_inputs_1;
      end

      PIPELINE_STATE_EXEC_SET_FILTER_INPUT_STRIDE: begin
        filter_input_depth <= cmd_payload_inputs_0;
      end

      PIPELINE_STATE_EXEC_SET_BATCH_OUT_CHANNEL: begin
          batch       <= cmd_payload_inputs_0;
          out_channel <= cmd_payload_inputs_1;
      end

      PIPELINE_STATE_EXEC_SET_FILTER_DIMS: begin
        filter_width <= cmd_payload_inputs_0;
        filter_height <= cmd_payload_inputs_1;
      end

      PIPELINE_STATE_EXEC_SET_IMAGE_COORDS: begin
        cur_image_x <= cmd_payload_inputs_0;
        cur_image_y <= cmd_payload_inputs_1;
      end

      PIPELINE_STATE_EXEC_SET_IMAGE_DIMS: begin
        image_width <= cmd_payload_inputs_0;
        image_height <= cmd_payload_inputs_1;
      end

      PIPELINE_STATE_EXEC_SET_IMAGE_FILTER_ADR: begin
        image_base  <= cmd_payload_inputs_0;
        filter_base <= cmd_payload_inputs_1;
      end

      PIPELINE_STATE_EXEC_CONV_FETCH_VAL: begin
          // cfu_ram_adr <= cmd_payload_inputs_0[31:2];
          cfu_ram_adr <= cur_image_adr[31:2];

          if (cfu_ram_ack) begin
            matrix_vals <= cfu_ram_dat_miso;
            cfu_ram_cyc <= 0;
            cfu_ram_stb <= 0;
          end else begin
            cfu_ram_cyc <= 1;
            cfu_ram_stb <= 1;
          end
      end

      PIPELINE_STATE_EXEC_CONV_FETCH_FILTER: begin
          // cfu_ram_adr <= cmd_payload_inputs_1[31:2];
          cfu_ram_adr <= cur_filter_adr[31:2];

          if (cfu_ram_ack) begin
            filter_vals <= cfu_ram_dat_miso;
            cfu_ram_cyc <= 0;
            cfu_ram_stb <= 0;
          end else begin
            cfu_ram_cyc <= 1;
            cfu_ram_stb <= 1;
          end
      end

      PIPELINE_STATE_EXEC_CONV_ADD: begin
        rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;

        cfu_ram_cyc <= 0;
        cfu_ram_stb <= 0;

        if (cur_input_depth + 4 < input_channel_depth) begin
          cur_input_depth <= cur_input_depth + 4;
        end else if ( ((cur_filter_x + 1) < filter_width) & ((cur_image_x + cur_filter_x + 1) < image_width) ) begin
          cur_input_depth <= 0;
          cur_filter_x <= cur_filter_x + 1;
        end else begin
          cur_input_depth <= 0;
          cur_filter_x <= 0;
          cur_filter_y <= cur_filter_y + 1;
        end
      end

      PIPELINE_STATE_EXEC_CONV_DONE: begin
        cur_input_depth <= 0;
        cur_filter_x <= 0;
        cur_filter_y <= 0;
      end

      default: begin
      end
      endcase
    end else begin
      rsp_valid <= 1;
      cur_state <= PIPELINE_STATE_INIT;
    end
  end
endmodule
