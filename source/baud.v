module u_baud #(parameter  sys_clk_frequency=50000000,baud_rate=9600) (input sys_clk,input sys_rst_l,output reg uart_clk);
localparam max_count=sys_clk_frequency/(baud_rate*32);
reg[$clog2(max_count-1):0] count;
always@(posedge sys_clk or negedge sys_rst_l)
 begin
   if(!sys_rst_l)
     begin
       count<=0;
       uart_clk<=0;
     end
    else if(count<max_count)
        begin
          count<=count+1;
        end
          else
        begin
           count<=0;
           uart_clk<=~uart_clk;
         end
  end
endmodule
