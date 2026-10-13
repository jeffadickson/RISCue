// Center-sampled 8N1 receiver with synchronized input and framing detection.
module riscue_uart_rx #(parameter integer CLOCK_HZ=10000000,BAUD=115200)(
 input wire clk,rst_n,rx,output reg valid,output reg [7:0] data,output reg framing_error
);
 localparam integer DIV=(CLOCK_HZ+BAUD/2)/BAUD;
 initial if(DIV<4)$fatal(1,"UART requires at least four clocks per bit");
 (* ASYNC_REG="TRUE" *) reg [1:0] sync_rx;
 reg [1:0] phase;reg [31:0] ticks;reg [2:0] bit_index;reg [7:0] shift;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin sync_rx<=3;phase<=0;ticks<=0;bit_index<=0;shift<=0;valid<=0;data<=0;framing_error<=0;end
  else begin
   sync_rx<={sync_rx[0],rx};valid<=0;framing_error<=0;
   case(phase)
    0:if(!sync_rx[1])begin phase<=1;ticks<=DIV/2-1;end
    1:if(ticks!=0)ticks<=ticks-1;else if(sync_rx[1])phase<=0;else begin phase<=2;ticks<=DIV-1;bit_index<=0;end
    2:if(ticks!=0)ticks<=ticks-1;else begin
     shift[bit_index]<=sync_rx[1];ticks<=DIV-1;
     if(bit_index==7)phase<=3;else bit_index<=bit_index+1;
    end
    3:if(ticks!=0)ticks<=ticks-1;else begin
     phase<=0;if(sync_rx[1])begin data<=shift;valid<=1;end else framing_error<=1;
    end
   endcase
  end
 end
endmodule
