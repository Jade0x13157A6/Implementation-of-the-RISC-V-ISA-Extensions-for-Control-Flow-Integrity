`timescale 1ns/1ps

module packet_fsm_tb;

  localparam logic [7:0] CMD_SET  = 8'h01;
  localparam logic [7:0] CMD_JUMP = 8'h02;
  localparam logic [7:0] CMD_LPAD = 8'h03;

  localparam logic [1:0] STATE_IDLE  = 2'b00;
  localparam logic [1:0] STATE_CHECK = 2'b01;
  localparam logic [1:0] STATE_ERROR = 2'b10;

  logic        clk_i;
  logic        rst_ni;
  logic [31:0] packet_i;

  logic [1:0]  state_o;
  logic [23:0] label_o;
  logic        error_o;

  packet_fsm dut (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .packet_i (packet_i),
    .state_o  (state_o),
    .label_o  (label_o),
    .error_o  (error_o)
  );

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  task automatic send_packet(
    input logic [7:0]  command,
    input logic [23:0] data
  );
    begin
      @(negedge clk_i);
      packet_i = {command, data};

      @(posedge clk_i);
      #1;
    end
  endtask

  task automatic check_outputs(
    input logic [1:0]  expected_state,
    input logic [23:0] expected_label,
    input logic        expected_error,
    input string       test_name
  );
    begin
      if ((state_o !== expected_state) ||
          (label_o !== expected_label) ||
          (error_o !== expected_error)) begin
        $fatal(
          1,
          "FAIL: %s state=%0d label=0x%06h error=%0b",
          test_name,
          state_o,
          label_o,
          error_o
        );
      end

      $display(
        "PASS: %s state=%0d label=0x%06h error=%0b",
        test_name,
        state_o,
        label_o,
        error_o
      );
    end
  endtask

  initial begin
    $dumpfile("build/packet_fsm_tb.vcd");
    $dumpvars(0, packet_fsm_tb);

    rst_ni   = 1'b0;
    packet_i = 32'h00000000;

    repeat (2) @(posedge clk_i);
    #1;

    check_outputs(
      STATE_IDLE,
      24'h000000,
      1'b0,
      "reset"
    );

    @(negedge clk_i);
    rst_ni = 1'b1;

    @(posedge clk_i);
    #1;

    check_outputs(
      STATE_IDLE,
      24'h000000,
      1'b0,
      "reset release"
    );

    // LPAD in IDLE must not change the state.
    send_packet(CMD_LPAD, 24'h123456);
    check_outputs(
      STATE_IDLE,
      24'h000000,
      1'b0,
      "LPAD ignored in IDLE"
    );

    // SET stores the label while remaining in IDLE.
    send_packet(CMD_SET, 24'h123456);
    check_outputs(
      STATE_IDLE,
      24'h123456,
      1'b0,
      "SET stores label"
    );

    // Correct JUMP -> LPAD sequence.
    send_packet(CMD_JUMP, 24'h000000);
    check_outputs(
      STATE_CHECK,
      24'h123456,
      1'b0,
      "JUMP enters CHECK"
    );

    send_packet(CMD_LPAD, 24'h123456);
    check_outputs(
      STATE_IDLE,
      24'h123456,
      1'b0,
      "matching LPAD returns to IDLE"
    );

    // A mismatching LPAD must enter ERROR.
    send_packet(CMD_SET, 24'hABCDEF);
    check_outputs(
      STATE_IDLE,
      24'hABCDEF,
      1'b0,
      "SET updates label"
    );

    send_packet(CMD_JUMP, 24'h000000);
    check_outputs(
      STATE_CHECK,
      24'hABCDEF,
      1'b0,
      "second JUMP enters CHECK"
    );

    send_packet(CMD_LPAD, 24'hABC000);
    check_outputs(
      STATE_ERROR,
      24'hABCDEF,
      1'b1,
      "mismatching LPAD enters ERROR"
    );

    // ERROR must remain active and the label must not change.
    send_packet(CMD_SET, 24'h654321);
    check_outputs(
      STATE_ERROR,
      24'hABCDEF,
      1'b1,
      "ERROR remains locked"
    );

    // Reset must recover from ERROR.
    // Clear packet_i to prevent the previous SET packet from being
    // accepted again after reset is released.
    @(negedge clk_i);
    rst_ni   = 1'b0;
    packet_i = 32'h00000000;

    @(posedge clk_i);
    #1;

    check_outputs(
      STATE_IDLE,
      24'h000000,
      1'b0,
      "reset recovers from ERROR"
    );

    @(negedge clk_i);
    rst_ni = 1'b1;

    @(posedge clk_i);
    #1;

    check_outputs(
      STATE_IDLE,
      24'h000000,
      1'b0,
      "state remains IDLE after reset release"
    );

    // Any non-LPAD command in CHECK must enter ERROR.
    send_packet(CMD_SET, 24'hFEDCBA);
    check_outputs(
      STATE_IDLE,
      24'hFEDCBA,
      1'b0,
      "SET stores new label"
    );

    send_packet(CMD_JUMP, 24'h000000);
    check_outputs(
      STATE_CHECK,
      24'hFEDCBA,
      1'b0,
      "third JUMP enters CHECK"
    );

    send_packet(CMD_SET, 24'hFEDCBA);
    check_outputs(
      STATE_ERROR,
      24'hFEDCBA,
      1'b1,
      "non-LPAD command in CHECK enters ERROR"
    );

    $display("All CFI FSM tests passed.");

    #10;
    $finish;
  end

endmodule : packet_fsm_tb
