// Diagnostic-only 8N1 transmitter. No CPU bus connection.
module riscue_uart_tx #(parameter integer CLOCK_HZ=10000000, BAUD=115200)(
 input logic clk,rst_n,valid,input logic [7:0] data,
 output logic ready,tx
);
 localparam integer DIV=(CLOCK_HZ+BAUD/2)/BAUD;
 logic busy;logic [9:0] shift;logic [3:0] bit_index;
 logic [31:0] ticks;
 assign ready=!busy;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin busy<=0;tx<=1;shift<=10'h3ff;bit_index<=0;ticks<=0;end
  else if(!busy)begin
   tx<=1;
   if(valid)begin busy<=1;shift<={1'b1,data,1'b0};tx<=0;bit_index<=0;ticks<=DIV-1;end
  end else if(ticks!=0)ticks<=ticks-1;
  else if(bit_index==9)begin busy<=0;tx<=1;end
  else begin shift<={1'b1,shift[9:1]};tx<=shift[1];bit_index<=bit_index+1;ticks<=DIV-1;end
 end
endmodule
