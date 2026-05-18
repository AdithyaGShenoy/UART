module uart_receiver #(parameter width=8)(clk,sys_rst_l,uart_rec_dataH,rec_dataH,rec_readyH,rec_busy);

  input clk,sys_rst_l,uart_rec_dataH;
  output reg [width-1:0] rec_dataH;
  output reg rec_readyH,rec_busy;

  localparam integer count=16;
  localparam idle=2'd0;
  localparam start=2'd1;
  localparam data=2'd2;
  localparam stop=2'd3;

  reg[1:0]state;
  reg[$clog2(count)-1:0] clk_count;
  reg[width-1:0] rx_data;
  reg[2:0] bit_index;

  reg rx_sync0;
  reg rx_sync1;
  //two flip flop synchronizer
  always@(posedge clk or negedge sys_rst_l)
  begin
    if(!sys_rst_l)
      begin
        rx_sync0<=1;
        rx_sync1<=1;
      end
    else
      begin
        rx_sync0<=uart_rec_dataH;
        rx_sync1<=rx_sync0;
      end
  end

  //fsm

  always@(posedge clk or negedge sys_rst_l)
    begin
      if(!sys_rst_l)
        begin
          state<=idle;
          clk_count<=0;
          bit_index<=0;
          rx_data<=0;
          rec_dataH<=0;
          rec_busy<=0;
          rec_readyH<=0;
        end
      else
        begin
          rec_readyH<=0;
          case(state)

            idle:
                  begin
                    clk_count<=0;
                    bit_index<=0;
                    rec_busy<=0;
                    if(rx_sync1==0)//check for start bit
                      begin
                        rec_busy<=1;
                        state<=start;
                      end
                  end

            start:
                  begin
                    if(clk_count<(count/2)-1)
                      begin
                        clk_count<=clk_count+1;
                      end
                    else
                      begin
                        clk_count<=0;
                        if(rx_sync1 == 0)//verify midpoint of start bit
                          begin
                            state<=data;
                          end
                        else
                          begin
                            state<=idle;
                          end
                      end
                  end
            data:
                  begin
                    if(clk_count<count-1)
                      begin
                        clk_count<=clk_count+1;
                      end
                    else
                      begin
                        clk_count<=0;
                        rx_data[bit_index]<=rx_sync1;//sample data
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
            stop:
                    begin
                      if(clk_count<count-1)
                        begin
                          clk_count<=clk_count+1;
                        end
                      else
                        begin
                          clk_count<=0;
                          if(rx_sync1==1) //check for stop bit
                            begin
                              rec_dataH<=rx_data;
                              rec_readyH<=1;
                              rec_busy<=0;
                            end

                          state<=idle;
                        end
                    end
            default:
                    begin
                    state <= idle;

                    clk_count <= 0;
                    bit_index <= 0;

                    rec_readyH <= 0;
                    rec_busy   <= 0;
                    end

            endcase
        end
    end

endmodule
