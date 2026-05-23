module uart_transmitter #(parameter width=8)(clk,sys_rst_l,xmitH,xmit_dataH,uart_xmit_dataH,xmit_doneH,xmit_active);

  input clk,sys_rst_l,xmitH;
  input [width-1:0] xmit_dataH;
  output reg uart_xmit_dataH;
  output reg xmit_doneH;
  output reg xmit_active;

  localparam integer count=16;

  localparam idle=2'd0;
  localparam start=2'd1;
  localparam data=2'd2;
  localparam stop=2'd3;

  reg[1:0]  state;
  reg[$clog2(count)-1:0] clk_count;
  reg[2:0] bit_index;
  reg[width-1:0] tx_data;

  //FSM

  always@(posedge clk or negedge sys_rst_l)
     begin
       if(!sys_rst_l)
         begin
           state<=idle;
           clk_count<=0;
           bit_index<=0;
           tx_data<=0;
           uart_xmit_dataH<=1;
           xmit_doneH<=1;
           xmit_active<=0;
         end
       else
         begin
           //check if xmitH is high
           case(state)
             idle:
                   begin
                     uart_xmit_dataH<=1;
                     bit_index<=0;
                     xmit_active<=0;
                     clk_count<=0;
                     xmit_doneH<=1;
                     if(xmitH)
                       begin
                         tx_data<=xmit_dataH;
                         xmit_active<=1;
                         xmit_doneH<=0;
                         state<=start;
                       end
                   end
        //hold start bit for 1 baud interval
             start:
                     begin
                       uart_xmit_dataH<=0;  //start bit
                       if(clk_count<count-1)
                         begin
                         clk_count<=clk_count+1;
                         end
                       else
                         begin
                           clk_count<=0;
                           state<=data;
                         end
                     end

             //start the data transfer from transmitter

             data:
                  begin
                    uart_xmit_dataH<=tx_data[bit_index];
                    if(clk_count<count-1)
                      begin
                        clk_count<=clk_count+1;
                      end
                    else
                      begin
                        clk_count<=0;
                        if(bit_index<width-1)
                          begin
                            bit_index<=bit_index+1;
                          end
                        else
                          begin
                            bit_index<=0;
                            state<=stop;
                          end
                      end
                  end

           //stop bit held for one baud interval
             stop:
                   begin
                     uart_xmit_dataH<=1;
                     if(clk_count<count-1)
                        begin
                          clk_count<=clk_count+1;
                        end
                     else
                       begin
                         clk_count<=0;
                         xmit_active<=0;
                         xmit_doneH<=1;
                           if(xmitH)
                             begin
                               tx_data<=xmit_dataH;
                               bit_index<=0;
                               xmit_active<=1;
                               state<=start;
                             end
                            else
                             begin
                             state<=idle;
                             end
                       end
                   end


             //default
             default:
                   begin
                     state<=idle;
                     uart_xmit_dataH<=1;
                     clk_count<=0;
                     bit_index<=0;
                     xmit_doneH<=1;
                     xmit_active<=0;
                   end
           endcase
         end
     end
endmodule

