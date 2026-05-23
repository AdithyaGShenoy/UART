`include "baud.v"
`include "uart_transmitter.v"
`include "uart_receiver.v"

module uart_top #(

    parameter integer SYS_CLK_FREQ = 50000000,
    parameter integer BAUD_RATE    = 9600,
    parameter integer WIDTH        = 8

)(

    input sys_clk,
    input sys_rst_l,


    // TRANSMITTER INTERFACE

    input                  xmitH,
    input  [WIDTH-1:0]     xmit_dataH,

    output                 uart_tx,
    output                 xmit_doneH,
    output                 xmit_active,


    // RECEIVER INTERFACE

    input                  uart_rx,

    output [WIDTH-1:0]     rec_dataH,
    output                 rec_readyH,
    output                 rec_busy

);


// INTERNAL UART CLOCK

wire uart_clk;


// BAUD GENERATOR

u_baud #(

    .sys_clk_frequency(SYS_CLK_FREQ),
    .baud_rate(BAUD_RATE)

) baud_gen (

    .sys_clk(sys_clk),
    .sys_rst_l(sys_rst_l),

    .uart_clk(uart_clk)

);



// UART TRANSMITTER

uart_transmitter #(

    .width(WIDTH)

) transmitter (

    .clk(uart_clk),
    .sys_rst_l(sys_rst_l),

    .xmitH(xmitH),
    .xmit_dataH(xmit_dataH),

    .uart_xmit_dataH(uart_tx),

    .xmit_doneH(xmit_doneH),
    .xmit_active(xmit_active)

);



// UART RECEIVER

uart_receiver #(

    .width(WIDTH)

) receiver (

    .clk(uart_clk),
    .sys_rst_l(sys_rst_l),

    .uart_rec_dataH(uart_rx),

    .rec_dataH(rec_dataH),

    .rec_readyH(rec_readyH),
    .rec_busy(rec_busy)

);

endmodule
