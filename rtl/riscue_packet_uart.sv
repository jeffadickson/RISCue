// Native ECC-coded MMIO UART. Bus responses and FIFO metadata are TMR;
// queued bytes are SECDED. Serial sampler/serializer remain a lab boundary.
module riscue_packet_uart #(parameter integer CLOCK_HZ=10000000, BAUD=115200, DEPTH=64,parameter bit FI_ENABLE=0)(
 input logic clk,rst_n,rx,output wire tx,
 input logic req,input logic [38:0] addr_code,wdata_code,ctrl_code,
 output wire ready,error,output wire [38:0] rdata_code,
 output wire irq,fatal,corrected_event,disagreement_event,
 input logic fi_valid,input logic [1:0] fi_target,input logic [31:0] fi_index,
 input logic [511:0] fi_mask,output wire fi_ack
);
 import ft_pkg::*;
 localparam integer P=$clog2(DEPTH);
 localparam logic [P:0] CAPACITY=(P+1)'(DEPTH);
 initial if(DEPTH<2 || (1<<P)!=DEPTH)$fatal(1,"FIFO depth must be power of two");
 typedef struct packed {
  logic ready,error,dead,irq_enable;
  logic [31:0] response,crc,corrected,framing,overflow,watchdog_reload,watchdog;
  logic [P-1:0] rp,wp,tp,tq;
  logic [P:0] rc,tc;
 } state_t;
 (* keep="true",DONT_TOUCH="TRUE" *) state_t s0,s1,s2;
 state_t s,n;
 (* keep="true" *) logic [38:0] rx_fifo[0:DEPTH-1],tx_fifo[0:DEPTH-1];
 wire bad=(s0!=s1)&&(s0!=s2)&&(s1!=s2);
 assign s=(s0&s1)|(s0&s2)|(s1&s2);
 assign disagreement_event=(s0!=s1)||(s0!=s2);
 wire rv,frame_error,tx_ready;wire [7:0] byte_in;
 logic send,rx_write,tx_write,rx_repair,tx_repair,ce;
 logic [31:0] tx_data;ecc_result_t ac,wc,cc,rd,td;
 riscue_uart_rx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) receiver(.clk(clk),.rst_n(rst_n),.rx(rx),.valid(rv),.data(byte_in),.framing_error(frame_error));
 riscue_uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) transmitter(.clk(clk),.rst_n(rst_n),.valid(send),.data(td.data[7:0]),.ready(tx_ready),.tx(tx));
 assign ready=rst_n&&s.ready;assign error=s.error;
 assign rdata_code=ecc_encode(s.response);assign fatal=bad||s.dead;
 assign irq=s.irq_enable&&(s.rc!=0||s.framing!=0||s.overflow!=0||fatal);
 assign corrected_event=ce;
 wire fifo_fi=fi_target<2&&fi_index<DEPTH&&(fi_mask>>39)==0;
 wire state_fi=fi_target==2&&fi_index<3&&(fi_mask>>$bits(state_t))==0;
 assign fi_ack=FI_ENABLE&&rst_n&&fi_valid&&fi_mask!=0&&(state_fi||(fifo_fi&&!rx_write&&!rx_repair&&!tx_write&&!tx_repair));
 function automatic [31:0] crc_byte(input [31:0] crc,input [7:0] b);
  reg [31:0] v;integer i;begin v=crc^{24'd0,b};for(i=0;i<8;i=i+1)v=v[0]?(v>>1)^32'hedb88320:v>>1;crc_byte=v;end
 endfunction
 always @* begin
  n=s;ac=ecc_decode(addr_code);wc=ecc_decode(wdata_code);cc=ecc_decode(ctrl_code);
  rd=ecc_decode(rx_fifo[s.rp]);td=ecc_decode(tx_fifo[s.tp]);
  rx_write=0;tx_write=0;rx_repair=0;tx_repair=0;send=0;tx_data=0;ce=0;
  if(!req)n.ready=0;
  if(s.watchdog_reload!=0&&!s.dead)begin
   if(s.watchdog<=1)n.dead=1;else n.watchdog=s.watchdog-1;
  end
  if(!bad&&!s.dead)begin
   if(frame_error)n.framing=s.framing+1;
   if(rv)begin
    if(s.rc==CAPACITY)n.overflow=s.overflow+1;
    else begin rx_write=1;n.wp=s.wp+1'b1;n.rc=s.rc+1'b1;end
   end
   if(s.tc!=0&&tx_ready)begin
    if(td.uncorrectable)n.dead=1;
    else begin send=1;n.tp=s.tp+1'b1;n.tc=s.tc-1'b1;if(td.corrected)begin ce=1;tx_repair=1;end end
   end
   if(req&&!s.ready)begin
    n.ready=1;n.error=0;n.response=0;
    if(ac.uncorrectable||cc.uncorrectable||(cc.data[4]&&wc.uncorrectable))begin n.error=1;n.dead=1;end
    else if(ac.data[31:8]!=24'h100000||ac.data[1:0]!=0||cc.data[31:5]!=0||(!cc.data[4]&&cc.data[3:0]!=0)) n.error=1;
    else if(cc.data[4])begin
     if(cc.data[3:0]!=15)n.error=1;
     else case(ac.data[7:0])
      8'h08:if(s.tc==CAPACITY)n.error=1;else begin tx_write=1;tx_data=wc.data;n.tq=s.tq+1'b1;n.tc=n.tc+1'b1;end
      8'h0c:n.irq_enable=wc.data[0];
      8'h10:n.crc=wc.data;
      8'h14:n.crc=crc_byte(s.crc,wc.data[7:0]);
      8'h24:begin n.watchdog_reload=wc.data;n.watchdog=wc.data;end
      8'h28:n.watchdog=s.watchdog_reload;
      default:n.error=1;
     endcase
    end else case(ac.data[7:0])
     8'h00:n.response={16'd0,6'd0,s.tc==CAPACITY,s.rc!=0,8'd0};
     8'h04:if(s.rc==0)n.error=1;else if(rd.uncorrectable)begin n.error=1;n.dead=1;end
      else begin n.response=rd.data;n.rp=s.rp+1'b1;n.rc=n.rc-1'b1;if(rd.corrected)begin ce=1;rx_repair=1;end end
     8'h0c:n.response={31'd0,s.irq_enable};
     8'h10:n.response=s.crc;
     8'h18:n.response=s.corrected;
     8'h1c:n.response=s.framing;
     8'h20:n.response=s.overflow;
     8'h24:n.response=s.watchdog_reload;
     default:n.error=1;
    endcase
    if(ac.corrected||cc.corrected||(cc.data[4]&&wc.corrected))ce=1;
   end
  end
  if(ce)n.corrected=s.corrected+1;
  if(bad)n.dead=1;
  if(n.dead)begin rx_write=0;tx_write=0;send=0;rx_repair=0;tx_repair=0;end
 end
 always @(posedge clk)begin
  if(!rst_n)begin s0<='0;s1<='0;s2<='0; end
  else begin
   s0<=n;s1<=n;s2<=n;
   if(rx_repair)rx_fifo[s.rp]<=rd.repaired;
   if(tx_repair)tx_fifo[s.tp]<=td.repaired;
   if(rx_write)rx_fifo[s.wp]<=ecc_encode({24'd0,byte_in});
   if(tx_write)tx_fifo[s.tq]<=ecc_encode(tx_data);
   // Lab injections are accepted only while no FIFO operation is occurring.
   if(fi_ack)begin
    if(fi_target==0&&!rx_write&&!rx_repair)rx_fifo[fi_index]<=rx_fifo[fi_index]^fi_mask[38:0];
    if(fi_target==1&&!tx_write&&!tx_repair)tx_fifo[fi_index]<=tx_fifo[fi_index]^fi_mask[38:0];
    if(fi_target>=2)case(fi_index)
     0:s0<=n^fi_mask[$bits(state_t)-1:0];1:s1<=n^fi_mask[$bits(state_t)-1:0];2:s2<=n^fi_mask[$bits(state_t)-1:0];
    endcase
   end
  end
 end
endmodule
