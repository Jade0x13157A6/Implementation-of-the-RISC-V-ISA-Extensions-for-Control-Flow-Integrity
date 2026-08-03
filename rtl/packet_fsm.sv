`timescale 1ns/1ps

module packet_fsm (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [31:0] packet_i,

  output logic [1:0]  state_o,
  output logic [23:0] label_o,
  output logic        error_o
);

  localparam logic [7:0] CMD_SET  = 8'h01;
  localparam logic [7:0] CMD_JUMP = 8'h02;
  localparam logic [7:0] CMD_LPAD = 8'h03;

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CHECK = 2'b01,
    ERROR = 2'b10
  } state_e;

  state_e state_q;
  state_e state_d;

  logic [23:0] label_q;
  logic [7:0]  command;
  logic [23:0] data;

  assign command = packet_i[31:24];
  assign data    = packet_i[23:0];

  always_comb begin
    state_d = state_q;

    unique case (state_q)
      IDLE: begin
        if (command == CMD_JUMP) begin
          state_d = CHECK;
        end
      end

      CHECK: begin
        if ((command == CMD_LPAD) && (data == label_q)) begin
          state_d = IDLE;
        end else begin
          state_d = ERROR;
        end
      end

      ERROR: begin
        state_d = ERROR;
      end

      default: begin
        state_d = ERROR;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      label_q <= 24'h000000;
    end else begin
      state_q <= state_d;

      if ((state_q == IDLE) && (command == CMD_SET)) begin
        label_q <= data;
      end
    end
  end

  assign state_o = state_q;
  assign label_o = label_q;
  assign error_o = (state_q == ERROR);

endmodule : packet_fsm
