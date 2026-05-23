`timescale 1ns /1ps
`default_nettype none

`include "uart_top.v"
`include "xmitt.v"
`include "rec.v"
`include "baud.v"

module tb_uart;

parameter baudr    = 9600;
parameter dw       = 8;
parameter clk_freq = 50000000;

localparam CLK_PERIOD_NS = 1000000000/clk_freq;

// SYSTEM SIGNALS

reg sys_clk;
reg sys_rst_l;

// TX INTERFACE

reg xmitH;
reg [dw-1:0] xmit_dataH;

wire uart_XMIT_dataH;
wire xmit_doneH;
wire xmit_active;

// RX INTERFACE

reg uart_REC_dataH;

wire [dw-1:0] rec_dataH;
wire rec_readyH;
wire rec_busy;

// DUT

top #(
    .baudr(baudr),
    .dw(dw),
    .clk_freq(clk_freq)
)
dut(
    .uart_XMIT_dataH(uart_XMIT_dataH),
    .xmit_doneH(xmit_doneH),
    .xmit_active(xmit_active),

    .rec_dataH(rec_dataH),
    .rec_readyH(rec_readyH),
    .rec_busy(rec_busy),

    .xmitH(xmitH),
    .xmit_dataH(xmit_dataH),

    .sys_clk(sys_clk),
    .sys_rst_l(sys_rst_l),

    .uart_REC_dataH(uart_REC_dataH)
);

// TB BAUD CLOCK

wire baud_clk_tb;

baud #(
    .baudr(baudr),
    .clk_freq(clk_freq)
)
tb_baud(
    .baud_clk(baud_clk_tb),
    .clk(sys_clk),
    .rst(sys_rst_l)
);

// CLOCK GENERATION
initial
begin
    sys_clk = 0;

    forever #(CLK_PERIOD_NS/2)
        sys_clk = ~sys_clk;
end

// VARIABLES

integer pass_cnt;
integer fail_cnt;

reg [9:0] expected_packet;
reg [9:0] captured_packet;

// RESET TASK

task reset_dut;

begin

    sys_rst_l = 0;

    xmitH = 0;
    xmit_dataH = 0;

    uart_REC_dataH = 1'b1;

    repeat(20)
        @(posedge sys_clk);

    if(uart_XMIT_dataH !== 1'b1)
    begin
        $display("FAIL_RESET_TX_IDLE");
        fail_cnt = fail_cnt + 1;
    end

    if(xmit_doneH !== 1'b0)
    begin
        $display("FAIL_RESET_DONE");
        fail_cnt = fail_cnt + 1;
    end

    if(xmit_active !== 1'b0)
    begin
        $display("FAIL_RESET_ACTIVE");
        fail_cnt = fail_cnt + 1;
    end

    if(rec_busy !== 1'b0)
    begin
        $display("FAIL_RESET_REC_BUSY");
        fail_cnt = fail_cnt + 1;
    end

    sys_rst_l = 1;

    repeat(20)
        @(posedge sys_clk);

end

endtask

// BUILD EXPECTED PACKET

task build_packet;

input [dw-1:0] data;

begin

    expected_packet = {1'b1,data,1'b0};

end

endtask

// TX CHECK TASK

task transmit_and_check;

input [dw-1:0] data;

integer i;

begin

    while(xmit_active)
        @(posedge sys_clk);

    build_packet(data);

    captured_packet = 10'b0;

    @(posedge sys_clk);

    xmit_dataH = data;
    xmitH = 1'b1;

    wait(xmit_active);

    @(posedge sys_clk);

    xmitH = 1'b0;

    wait(uart_XMIT_dataH == 1'b0);

    repeat(8)
        @(posedge baud_clk_tb);

    for(i = 0; i < 10; i = i + 1)
    begin

        captured_packet[i] = uart_XMIT_dataH;

        repeat(16)
            @(posedge baud_clk_tb);

    end

    wait(xmit_doneH);

    if(captured_packet === expected_packet)
    begin

        $display("PASS_TX DATA=%h PACKET=%b",
                    data,
                    captured_packet);

        pass_cnt = pass_cnt + 1;

    end
    else
    begin

        $display("FAIL_TX DATA=%h EXPECTED=%b GOT=%b",
                    data,
                    expected_packet,
                    captured_packet);

        fail_cnt = fail_cnt + 1;

    end

    repeat(10)
        @(posedge sys_clk);

end

endtask

// SEND SERIAL DATA

task send_serial_data;

input [dw-1:0] data;

integer i;

begin

    uart_REC_dataH = 1'b1;

    repeat(16)
        @(posedge baud_clk_tb);

    uart_REC_dataH = 1'b0;

    repeat(16)
        @(posedge baud_clk_tb);

    for(i = 0; i < dw; i = i + 1)
    begin

        uart_REC_dataH = data[i];

        repeat(16)
            @(posedge baud_clk_tb);

    end

    uart_REC_dataH = 1'b1;

    repeat(16)
        @(posedge baud_clk_tb);

end

endtask

// RX CHECK TASK

task receive_and_check;

input [dw-1:0] data;

begin

    fork

    begin

        send_serial_data(data);

    end

    begin

        wait(rec_readyH);

        if(rec_dataH === data)
        begin

            $display("PASS_RX EXPECTED=%h RECEIVED=%h",
                        data,
                        rec_dataH);

            pass_cnt = pass_cnt + 1;

        end
        else
        begin

            $display("FAIL_RX EXPECTED=%h RECEIVED=%h",
                        data,
                        rec_dataH);

            fail_cnt = fail_cnt + 1;

        end

    end

    join

    repeat(10)
        @(posedge sys_clk);

end

endtask

// FALSE START TEST

task false_start_test;

begin

    uart_REC_dataH = 1'b1;

    repeat(16)
        @(posedge baud_clk_tb);

    uart_REC_dataH = 1'b0;

    repeat(4)
        @(posedge baud_clk_tb);

    uart_REC_dataH = 1'b1;

    repeat(32)
        @(posedge baud_clk_tb);

    if(rec_busy == 0)
    begin

        $display("PASS_FALSE_START");

        pass_cnt = pass_cnt + 1;

    end
    else
    begin

        $display("FAIL_FALSE_START");

        fail_cnt = fail_cnt + 1;

    end

end

endtask

// CONTINUOUS TX TEST

task continuous_tx_test;

begin

    @(posedge sys_clk);

    xmit_dataH = 8'hA5;
    xmitH = 1'b1;

    wait(xmit_doneH);

    @(posedge sys_clk);

    xmit_dataH = 8'h3C;

    wait(xmit_doneH);

    @(posedge sys_clk);

    xmitH = 1'b0;

    $display("PASS_CONTINUOUS_TX");

    pass_cnt = pass_cnt + 1;

end

endtask

// TX RESET DURING START

task tx_reset_during_start;

begin

    @(posedge sys_clk);

    xmit_dataH = 8'hAA;
    xmitH = 1'b1;

    wait(dut.Tx.st == 1);

    @(posedge sys_clk);

    sys_rst_l = 0;

    @(posedge sys_clk);

    if(dut.Tx.st == 0)
    begin

        $display("PASS_TX_START_RESET");

        pass_cnt = pass_cnt + 1;

    end
    else
    begin

        $display("FAIL_TX_START_RESET");

        fail_cnt = fail_cnt + 1;

    end

    sys_rst_l = 1;
    xmitH = 0;

    repeat(10)
        @(posedge sys_clk);

end

endtask

// TX RESET DURING DATA

task tx_reset_during_data;

begin

    @(posedge sys_clk);

    xmit_dataH = 8'h55;
    xmitH = 1'b1;

    wait(dut.Tx.st == 2);

    @(posedge sys_clk);

    sys_rst_l = 0;

    @(posedge sys_clk);

    if(dut.Tx.st == 0)
    begin

        $display("PASS_TX_DATA_RESET");

        pass_cnt = pass_cnt + 1;

    end
    else
    begin

        $display("FAIL_TX_DATA_RESET");

        fail_cnt = fail_cnt + 1;

    end

    sys_rst_l = 1;
    xmitH = 0;

    repeat(10)
        @(posedge sys_clk);

end

endtask

// TX RESET DURING STOP

task tx_reset_during_stop;

begin

    @(posedge sys_clk);

    xmit_dataH = 8'hF0;
    xmitH = 1'b1;

    wait(dut.Tx.st == 3);

    @(posedge sys_clk);

    sys_rst_l = 0;

    @(posedge sys_clk);

    if(dut.Tx.st == 0)
    begin

        $display("PASS_TX_STOP_RESET");

        pass_cnt = pass_cnt + 1;

    end
    else
    begin

        $display("FAIL_TX_STOP_RESET");

        fail_cnt = fail_cnt + 1;

    end

    sys_rst_l = 1;
    xmitH = 0;

    repeat(10)
        @(posedge sys_clk);

end

endtask

// RX RESET DURING DATA

task rx_reset_during_data;

begin

    fork

    begin

        send_serial_data(8'h5A);

    end

    begin

        wait(dut.Rx.st == 2);

        @(posedge sys_clk);

        sys_rst_l = 0;

        @(posedge sys_clk);

        if(dut.Rx.st == 0)
        begin

            $display("PASS_RX_DATA_RESET");

            pass_cnt = pass_cnt + 1;

        end
        else
        begin

            $display("FAIL_RX_DATA_RESET");

            fail_cnt = fail_cnt + 1;

        end

        sys_rst_l = 1;

    end

    join

end

endtask

// RANDOM TESTS

task random_tests;

integer i;
reg [7:0] rand_data;

begin

    for(i = 0; i < 20; i = i + 1)
    begin

        rand_data = $random;

        transmit_and_check(rand_data);

    end

end

endtask

// MAIN TEST

initial
begin

    pass_cnt = 0;
    fail_cnt = 0;

    reset_dut();

    // TX TESTS

    transmit_and_check(8'h00);
    transmit_and_check(8'hFF);
    transmit_and_check(8'hAA);
    transmit_and_check(8'h55);
    transmit_and_check(8'hA5);
    transmit_and_check(8'h3C);

    // RANDOM TESTS

    random_tests();

    // RX TESTS

    receive_and_check(8'h00);
    receive_and_check(8'hFF);
    receive_and_check(8'hAA);
    receive_and_check(8'h55);
    receive_and_check(8'hA5);
    receive_and_check(8'h3C);

    // SPECIAL TESTS

    false_start_test();

    continuous_tx_test();

    // RESET TESTS

    tx_reset_during_start();

    tx_reset_during_data();

    tx_reset_during_stop();

    rx_reset_during_data();

    // RESULTS

    $display("================================");

    $display("UART VERIFICATION COMPLETED");

    $display("PASS COUNT = %0d", pass_cnt);

    $display("FAIL COUNT = %0d", fail_cnt);

    $display("================================");

    repeat(50)
        @(posedge sys_clk);

    $finish;

end

// WATCHDOG

initial
begin

    #500000000;

    $display("WATCHDOG TIMEOUT");

    $finish;

end

// DUMP WAVES

initial
begin

    $dumpfile("dump.vcd");
    $dumpvars(0,tb_uart);

end

endmodule
