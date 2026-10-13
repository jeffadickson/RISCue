// Laboratory control plane. Stop-and-wait fixed packets; CRC checked before effects.
// This monitor/serial transport is not part of the core's radiation containment claim.
module riscue_serial_monitor #(parameter integer CLOCK_HZ=10000000,BAUD=115200,WORDS=1024,TIMEOUT=100000,parameter bit FI_ENABLE=0)(
 input wire clk,rst_n,uart_rx,output wire uart_tx,
 output reg running,cpu_resetn,halt_request,output reg [31:0] boot_pc,
 input wire core_quiescent,core_bridge_idle,core_fatal,memory_fatal,memory_idle,
 input wire [31:0] pc,trap_cause,trap_value,retired_count,
 input wire [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count,last_error_address,
 input wire [5:0] last_error_syndrome,
 output reg req,output wire [38:0] addr_code,wdata_code,ctrl_code,
 input wire ready,error,bridge_idle,bridge_fatal,input wire [38:0] rdata_code,
 output reg memory_reset,output wire scrub_enable,
 output reg fi_valid,output wire [3:0] fi_target,output wire [31:0] fi_index,
 output wire [511:0] fi_mask,input wire fi_ack
);
 import ft_pkg::*;
 localparam integer GAP=(CLOCK_HZ/BAUD)*40;
 localparam [3:0] RECEIVE=0,DISPATCH=1,BUS_WAIT=2,BUS_DROP=3,STOP_WAIT=4,START_WAIT=5,RECOVER_WAIT=6,FI_WAIT=7,RESPOND=8,SEND=9;
 reg [3:0] state;reg [159:0] packet,last_packet,reply,cached_reply;
 reg [4:0] rx_index,tx_index;reg [31:0] gap_ticks,wait_ticks;
 reg cache_valid,cache_result,locked;reg [7:0] status;reg [31:0] result0,result1;
 wire rx_valid,rx_error,tx_ready;wire [7:0] rx_data;
 wire [7:0] command=packet[31:24];wire [31:0] address=packet[63:32],data=packet[95:64],aux=packet[127:96];
 wire [7:0] sequence_id=packet[23:16];
 ecc_result_t decoded;
 assign addr_code=ecc_encode(address);assign wdata_code=ecc_encode(data);
 assign ctrl_code=ecc_encode(command==3?32'h1f:32'd0);
 assign fi_target=8;assign fi_index=address>>2;assign fi_mask={473'd0,aux[6:0],data};
 assign scrub_enable=running&&!memory_reset;
 riscue_uart_rx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) rx(.clk(clk),.rst_n(rst_n),.rx(uart_rx),.valid(rx_valid),.data(rx_data),.framing_error(rx_error));
 riscue_uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) tx(.clk(clk),.rst_n(rst_n),.valid(state==SEND),.data(reply[tx_index*8+:8]),.ready(tx_ready),.tx(uart_tx));
 function automatic [31:0] crc(input [111:0] bytes);
  reg [31:0] c;integer i,j;begin c=32'hffffffff;
   for(i=0;i<14;i=i+1)begin c=c^{24'd0,bytes[i*8+:8]};for(j=0;j<8;j=j+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;end
   crc=~c;
  end
 endfunction
 function automatic [159:0] response(input [7:0] seq,code,input [31:0] a,d,x);
  reg [159:0] f;begin f={32'd0,x,d,a,code,seq,16'ha55a};f[159:128]=crc(f[127:16]);response=f;end
 endfunction
 always @* decoded=ecc_decode(rdata_code);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=RECEIVE;packet<=0;last_packet<=0;reply<=0;cached_reply<=0;rx_index<=0;tx_index<=0;gap_ticks<=0;wait_ticks<=0;
   cache_valid<=0;cache_result<=0;locked<=0;status<=0;result0<=0;result1<=0;
   running<=0;cpu_resetn<=0;halt_request<=1;boot_pc<=0;req<=0;memory_reset<=0;fi_valid<=0;
  end else begin
   fi_valid<=0;
   case(state)
    RECEIVE:begin
     if(rx_error||(rx_index!=0&&gap_ticks>=GAP))begin rx_index<=0;gap_ticks<=0;end
     else if(rx_valid)begin
      gap_ticks<=0;
      if(rx_index==0)begin if(rx_data==8'ha5)begin packet[7:0]<=rx_data;rx_index<=1;end end
      else if(rx_index==1)begin
       if(rx_data==8'h5a)begin packet[15:8]<=rx_data;rx_index<=2;end
       else if(rx_data!=8'ha5)rx_index<=0;
      end else begin
       packet[rx_index*8+:8]<=rx_data;
       if(rx_index==19)begin rx_index<=0;state<=DISPATCH;end else rx_index<=rx_index+1;
      end
     end else if(rx_index!=0)gap_ticks<=gap_ticks+1;
    end
    DISPATCH:begin
     status<=0;result0<=0;result1<=0;wait_ticks<=0;cache_result<=1;state<=RESPOND;
     if(packet[159:128]!=crc(packet[127:16]))begin status<=2;cache_result<=0;end
     else if(cache_valid&&sequence_id==last_packet[23:16])begin
      cache_result<=0;
      if(packet==last_packet)begin reply<=cached_reply;tx_index<=0;state<=SEND;end else status<=8;
     end else case(command)
      0:begin result0<=32'h52495343;result1<=WORDS*4;end
      1:case(address)
       0:begin result0<=pc;result1<={26'd0,locked,FI_ENABLE,memory_fatal,core_fatal,cpu_resetn,running};end
       1:begin result0<=corrected_count;result1<=uncorrectable_count;end
       2:begin result0<=disagreement_count;result1<=fatal_count;end
       3:begin result0<=last_error_address;result1<={26'd0,last_error_syndrome};end
       4:begin result0<=trap_cause;result1<=trap_value;end
       5:result0<=retired_count;
       default:status<=3;
      endcase
      2,3:begin
       if(running||!bridge_idle||!memory_idle||locked)status<=4;
       else if(address[1:0]!=0||address/4>=WORDS)status<=3;
       else begin req<=1;state<=BUS_WAIT;end
      end
      4:begin
       if(running||!bridge_idle||!core_bridge_idle||!memory_idle||locked)status<=4;
       else if(memory_fatal)status<=5;
       else if(address[0]||address>=WORDS*4)status<=3;
       else begin boot_pc<=address;cpu_resetn<=0;halt_request<=1;state<=START_WAIT;end
      end
      5:begin halt_request<=1;state<=STOP_WAIT;end
      6:begin
       if(!FI_ENABLE)status<=7;
       else if(running||!bridge_idle||!memory_idle||locked)status<=4;
       else if(address[1:0]!=0||address/4>=WORDS||aux[31:7]!=0||{aux[6:0],data}==0)status<=3;
       else begin fi_valid<=1;state<=FI_WAIT;end
      end
      7:begin
       if(running||!bridge_idle||!memory_idle||locked)status<=4;
       else begin memory_reset<=1;state<=RECOVER_WAIT;end
      end
      default:status<=1;
     endcase
    end
    BUS_WAIT:begin
     wait_ticks<=wait_ticks+1;
     if(ready)begin
      req<=0;status<=(error||decoded.uncorrectable)?5:0;result0<=decoded.data;state<=BUS_DROP;wait_ticks<=0;
     end else if(bridge_fatal||wait_ticks>=TIMEOUT)begin req<=0;locked<=1;status<=6;state<=RESPOND;end
    end
    BUS_DROP:begin
     wait_ticks<=wait_ticks+1;
     if(bridge_idle&&memory_idle)state<=RESPOND;
     else if(wait_ticks>=TIMEOUT)begin locked<=1;status<=6;state<=RESPOND;end
    end
    STOP_WAIT:begin
     wait_ticks<=wait_ticks+1;
     if((!cpu_resetn||core_quiescent||core_fatal)&&core_bridge_idle&&memory_idle)begin running<=0;result0<=pc;state<=RESPOND;end
     else if(wait_ticks>=TIMEOUT)begin status<=6;state<=RESPOND;end
    end
    START_WAIT:begin
     wait_ticks<=wait_ticks+1;
     if(wait_ticks==3)begin running<=1;cpu_resetn<=1;halt_request<=0;state<=RESPOND;end
    end
    RECOVER_WAIT:begin
     wait_ticks<=wait_ticks+1;
     if(wait_ticks==3)begin memory_reset<=0;state<=RESPOND;end
    end
    FI_WAIT:begin status<=fi_ack?0:7;state<=RESPOND;end
    RESPOND:begin
     reply<=response(sequence_id,status,address,result0,result1);tx_index<=0;state<=SEND;
     if(cache_result)begin cached_reply<=response(sequence_id,status,address,result0,result1);last_packet<=packet;cache_valid<=1;end
    end
    SEND:if(tx_ready)begin if(tx_index==19)begin state<=RECEIVE;gap_ticks<=0;end else tx_index<=tx_index+1;end
    default:begin locked<=1;halt_request<=1;state<=RECEIVE;end
   endcase
  end
 end
endmodule
