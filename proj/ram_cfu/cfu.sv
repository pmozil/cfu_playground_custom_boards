`timescale 1ns/1ps

typedef enum {
  MEM_STATE_INIT = 1,
  MEM_STATE_READ_PENDING = 2,
  MEM_STATE_WRITE_PENDING = 3,
  MEM_STATE_BURST_READ_PENDING = 4,
  MEM_STATE_BURST_WRITE_PENDING = 5
} ram_ctrl_state;

module RAM_ctrl (
 // Wishbone RAM bus control wires
  output wire[29:0] cfu_ram_adr,
  output wire[31:0] cfu_ram_dat_mosi,
  output wire[3:0] cfu_ram_sel,
  output wire cfu_ram_cyc,
  output wire cfu_ram_stb,
  output wire cfu_ram_we,
  output wire[2:0] cfu_ram_cti,
  output wire[1:0] cfu_ram_bte,
  input  wire[31:0] cfu_ram_dat_miso,
  input  wire cfu_ram_ack,
  input  wire cfu_ram_err,

 // User-defined wires
  input  reg [3:0] byte_enable,
  input  reg [31:0] wdata,
  output reg [31:0] rdata,
  input  reg [29:0] address,
  input  reg read_req,
  input  reg write_req,
  input  reg burst_mode,
  output reg acknowledge,
  output ram_ctrl_state cur_state,

  input  reset,
  input  clk
);
  ram_ctrl_state next_state;

  logic ram_cyc;
  logic ram_stb;
  logic ram_we ;
  logic ram_cti;
  logic ram_bte;

  logic has_err = cfu_ram_err;

  // assign cfu_ram_cyc = ram_cyc;
  assign cfu_ram_cyc = 1;
  assign cfu_ram_stb = ram_stb;
  assign cfu_ram_we  = ram_we;
  assign cfu_ram_cti = ram_cti;
  assign cfu_ram_bte = ram_bte;
  assign acknowledge = cfu_ram_ack & cur_state != MEM_STATE_INIT;
  
  assign cfu_ram_adr = address;
  assign cfu_ram_sel = byte_enable;
  assign cfu_ram_dat_mosi = wdata;
  
  always_comb begin
    next_state = MEM_STATE_INIT;

    case (cur_state)
      MEM_STATE_INIT: begin
          if (read_req) next_state = burst_mode ? MEM_STATE_BURST_READ_PENDING : MEM_STATE_READ_PENDING;
          else if (write_req) next_state = burst_mode ? MEM_STATE_BURST_WRITE_PENDING : MEM_STATE_WRITE_PENDING;
      end

      MEM_STATE_WRITE_PENDING: begin
      next_state = (acknowledge | has_err) ? MEM_STATE_INIT :
        MEM_STATE_WRITE_PENDING;
      end

      MEM_STATE_READ_PENDING: begin
      next_state = (acknowledge | has_err) ? MEM_STATE_INIT :
        MEM_STATE_READ_PENDING;
      end

      MEM_STATE_BURST_WRITE_PENDING: begin
      next_state = (acknowledge | has_err) ? MEM_STATE_INIT :
        MEM_STATE_BURST_WRITE_PENDING;
      end

      MEM_STATE_BURST_READ_PENDING: begin
      next_state = (acknowledge | has_err) ? MEM_STATE_INIT :
        MEM_STATE_BURST_READ_PENDING;
      end
    
      default: begin
      end
    endcase
  end

  always_comb begin
    // ram_cyc = 0;
    ram_stb = 0;
    ram_we  = 0;
    ram_cti = 0;
    ram_bte = 0;

    case (cur_state)
      // TODO: Add burst mode handling
      MEM_STATE_WRITE_PENDING: begin
        // ram_cyc = 1;
        ram_stb = 1;
        ram_we  = 1;
      end

      MEM_STATE_READ_PENDING: begin
        // ram_cyc = 1;
        ram_stb = 1;
        ram_we  = 0;
      end

      default: begin
      end
    endcase
    end

    always_ff @(negedge clk or posedge reset) begin
      if (reset) begin
        cur_state <= MEM_STATE_INIT;
      end else begin
        cur_state <= next_state;
        case (next_state)
          MEM_STATE_READ_PENDING: begin
            if (cfu_ram_ack) rdata <= cfu_ram_dat_miso;
            else rdata <= rdata;
          end

          MEM_STATE_BURST_READ_PENDING: begin
            if (cfu_ram_ack) rdata <= cfu_ram_dat_miso;
            else rdata <= rdata;
          end

          default: begin
          end
        endcase
      end
  end

endmodule


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
  logic [31:0] write_data;
  logic [31:0] read_data;
  logic [29:0] address;
  logic [3:0] byte_enable;
  logic read_req = 0;
  logic write_req = 0;
  logic burst_mode = 0;
  logic acknowledge;
  ram_ctrl_state cur_ram_state;

  RAM_ctrl ram_ctrl (
   .cfu_ram_adr(cfu_ram_adr),
   .cfu_ram_dat_mosi(cfu_ram_dat_mosi),
   .cfu_ram_sel(cfu_ram_sel),
   .cfu_ram_cyc(cfu_ram_cyc),
   .cfu_ram_stb(cfu_ram_stb),
   .cfu_ram_we(cfu_ram_we),
   .cfu_ram_cti(cfu_ram_cti),
   .cfu_ram_bte(cfu_ram_bte),
   .cfu_ram_dat_miso(cfu_ram_dat_miso),
   .cfu_ram_ack(cfu_ram_ack),
   .cfu_ram_err(cfu_ram_err),

   .byte_enable(byte_enable),
   .wdata(write_data),
   .rdata(read_data),
   .address(address),
   .read_req(read_req),
   .write_req(write_req),
   .burst_mode(burst_mode),
   .acknowledge(acknowledge),
   .cur_state(cur_ram_state),

   .reset(reset),
   .clk(clk)
  );

  localparam InputOffset = $signed(9'd128);

  // SIMD multiply step:
  wire signed [15:0] prod_0, prod_1, prod_2, prod_3;
  // assign prod_0 =  ($signed(cmd_payload_inputs_0[7 : 0]) + InputOffset)
  //     * $signed(cmd_payload_inputs_1[7 : 0]);
  // assign prod_1 =  ($signed(cmd_payload_inputs_0[15: 8]) + InputOffset)
  //     * $signed(cmd_payload_inputs_1[15: 8]);
  // assign prod_2 =  ($signed(cmd_payload_inputs_0[23:16]) + InputOffset)
  //     * $signed(cmd_payload_inputs_1[23:16]);
  // assign prod_3 =  ($signed(cmd_payload_inputs_0[31:24]) + InputOffset)
  //     * $signed(cmd_payload_inputs_1[31:24]);

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
    PIPELINE_STATE_EXEC_1_ADD,
    PIPELINE_STATE_FN_DONE
  } fetch_multiply_state;

  fetch_multiply_state cur_state = PIPELINE_STATE_INIT;
  fetch_multiply_state next_state;

  always_comb begin
  case (cur_state)
    PIPELINE_STATE_INIT: begin
      if (cmd_valid) next_state = |cmd_payload_function_id[9:3] ?
          PIPELINE_STATE_EXEC_0 :
          PIPELINE_STATE_EXEC_1_FETCH_VAL;
      else next_state = PIPELINE_STATE_INIT;
    end

    PIPELINE_STATE_EXEC_0: begin
      next_state = PIPELINE_STATE_INIT;
    end

    PIPELINE_STATE_EXEC_1_FETCH_VAL: begin
      if (acknowledge) next_state = PIPELINE_STATE_EXEC_1_FETCH_FILTER;
      // next_state = PIPELINE_STATE_EXEC_1_FETCH_FILTER;
    end

    PIPELINE_STATE_EXEC_1_FETCH_FILTER: begin
      if (acknowledge) next_state = PIPELINE_STATE_EXEC_1_ADD;
      // next_state = PIPELINE_STATE_EXEC_1_ADD;
    end

    PIPELINE_STATE_EXEC_1_ADD: begin
      next_state = PIPELINE_STATE_INIT;
    end
     
    default: begin
    end
  endcase
  end


  // Only not ready for a command when we have a response.
  assign cmd_ready = cur_state == PIPELINE_STATE_INIT;

  always_ff @(negedge clk or posedge reset) begin
  cur_state <= next_state;

  if (reset) begin
    rsp_payload_outputs_0 <= 32'b0;
    rsp_valid <= 1'b0;
    cur_state <= PIPELINE_STATE_INIT;
  end else if (rsp_valid) begin
    // Waiting to hand off response to CPU.
    rsp_valid <= ~rsp_ready;
  end else if (cmd_valid) begin
    rsp_valid <= (
      cur_state == PIPELINE_STATE_EXEC_1_ADD |
      cur_state == PIPELINE_STATE_EXEC_0
    );

    case (cur_state)
    PIPELINE_STATE_EXEC_0: rsp_payload_outputs_0 <= 32'b0;

    PIPELINE_STATE_EXEC_1_FETCH_VAL: begin
      address <= cmd_payload_inputs_0[31:2];
      read_req <= 1;
      byte_enable <= 4'b1111;

      if (acknowledge) begin
        matrix_vals <= read_data;
        read_req <= 0;
      end
      // matrix_vals <= cmd_payload_inputs_0;
    end

    PIPELINE_STATE_EXEC_1_FETCH_FILTER: begin
      address <= cmd_payload_inputs_1[31:2];
      read_req <= 1;
      byte_enable <= 4'b1111;

      if (acknowledge) begin
        filter_vals <= read_data;
        read_req <= 0;
      end
      // filter_vals <= cmd_payload_inputs_1;
    end

    PIPELINE_STATE_EXEC_1_ADD: rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;

    default: begin
    end
    endcase
  end
  end
endmodule
