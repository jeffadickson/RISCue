// Diagnostic-only periodic coherent snapshot; not part of the protected CPU.
module riscue_status_uart #(parameter integer CLOCK_HZ=10000000)(
 input logic clk,rst_n,halted,fatal,trap,retire_valid,
 input logic [31:0] pc,cause,tval,corrected_count,uncorrectable_count,disagreement_count,fatal_count,
 input logic [15:0] flags,output logic tx
);
 logic [31:0] period,retired,packet[0:9];
 logic active,ready;logic [6:0] position;logic [7:0] data;
 integer field_number,digit;integer i;
 function automatic logic [7:0] hex_char(input logic [3:0] value);
  hex_char=(value<10)?8'h30+value:8'h61+(value-10);
 endfunction
 always @*begin
  data=8'h20;field_number=0;digit=0;
  case(position)
   0:data="R";1:data="I";2:data="S";3:data="C";4:data="u";5:data="e";6:data=" ";
   97:data=8'h0d;98:data=8'h0a;
   default:if(position>=7&&position<97)begin
    field_number=(position-7)/9;digit=(position-7)%9;
    if(digit<8)data=hex_char(packet[field_number][31-digit*4 -:4]);
   end
  endcase
 end
 riscue_uart_tx #(.CLOCK_HZ(CLOCK_HZ)) uart(.clk(clk),.rst_n(rst_n),.valid(active),.data(data),.ready(ready),.tx(tx));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   period<=0;retired<=0;position<=0;active<=0;
   for(i=0;i<10;i=i+1)packet[i]<=0;
  end else begin
   if(retire_valid)retired<=retired+1;
   period<=(period==CLOCK_HZ-1)?0:period+1;
   if(!active&&period==CLOCK_HZ-1)begin
    packet[0]<=pc;packet[1]<=cause;packet[2]<=tval;packet[3]<={16'd0,flags};
    packet[4]<=corrected_count;packet[5]<=uncorrectable_count;packet[6]<=disagreement_count;
    packet[7]<=fatal_count;packet[8]<=retired;packet[9]<={29'd0,trap,fatal,halted};
    active<=1;position<=0;
   end else if(active&&ready)begin
    if(position==98)begin active<=0;position<=0;end else position<=position+1;
   end
  end
 end
endmodule
