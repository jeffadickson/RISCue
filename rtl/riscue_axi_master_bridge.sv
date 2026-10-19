// One outstanding AXI4-Lite transaction; capture the core's ECC-coded request.
// The bridge owns accepted payloads until response, even if core req drops.
module riscue_axi_master_bridge #(
 // Opt-in: retain the historical bridge exactly when disabled.
 parameter bit CHECKED_VOTER=0,
 parameter bit INTEGRITY_GUARD=0
)(
 input logic clk,rst_n,core_req,
 input logic [38:0] addr_code,wdata_code,ctrl_code,
 output logic core_ready,core_error,output logic [38:0] rdata_code,
 output logic corrected_event,disagreement_event,fatal,output wire idle,
 output logic [31:0] m_axi_awaddr,output logic [2:0] m_axi_awprot,
 output logic m_axi_awvalid,input logic m_axi_awready,
 output logic [31:0] m_axi_wdata,output logic [3:0] m_axi_wstrb,
 output logic m_axi_wvalid,input logic m_axi_wready,
 input logic [1:0] m_axi_bresp,input logic m_axi_bvalid,output logic m_axi_bready,
 output logic [31:0] m_axi_araddr,output logic [2:0] m_axi_arprot,
 output logic m_axi_arvalid,input logic m_axi_arready,
 input logic [31:0] m_axi_rdata,input logic [1:0] m_axi_rresp,
 input logic m_axi_rvalid,output logic m_axi_rready
);
 import ft_pkg::*;
 localparam logic [3:0] IDLE=4'b0000,READ_ADDR=4'b0011,READ_DATA=4'b0101,
  WRITE_DATA=4'b0110,WRITE_RESP=4'b1001,COMPLETE=4'b1010,WAIT_DROP=4'b1100;
 typedef struct packed {
  logic [3:0] phase;
  logic aw_done,w_done,error,corrected,dead;
  logic [31:0] address,data;
  logic [3:0] mask;
  logic [38:0] response;
 } bridge_t;
 (* keep="true",DONT_TOUCH="TRUE" *) bridge_t s0,s1,s2;
 bridge_t s,n;ecc_result_t da,dw,dc;
 wire record_bad=(s0!=s1)&&(s0!=s2)&&(s1!=s2);
 // Check the bitwise state voter against a whole-record matching pair.
 // An isolated replica upset is repaired as before. If no two complete
 // transaction records match, the existing fail-stop behavior still applies.
 // This is a *logical* checker, not guaranteed independent after synthesis.
 bridge_t whole_record_reference;
 wire voter_mismatch;
 assign whole_record_reference=(s0==s1)?s0:((s0==s2)?s0:s1);
 assign voter_mismatch=CHECKED_VOTER&&!record_bad&&(s!=whole_record_reference);
 // Independent stored transaction descriptor, encoded after clean input decode.
 // This checks corruption after capture, not a bad value generated upstream.
 logic [38:0] guard_addr,guard_data,guard_ctrl;
 ecc_result_t guard_a,guard_d,guard_c;
 wire guard_active=(s.phase==READ_ADDR)||(s.phase==READ_DATA)||
                   (s.phase==WRITE_DATA)||(s.phase==WRITE_RESP);
 wire guard_write=(s.phase==WRITE_DATA)||(s.phase==WRITE_RESP);
 wire guard_bad=INTEGRITY_GUARD&&guard_active&&(
      guard_a.uncorrectable||guard_d.uncorrectable||guard_c.uncorrectable||
      s.address!==(guard_a.data&32'hfffffffc)||
      (guard_write&&(s.data!==guard_d.data||s.mask!==guard_c.data[3:0]))||
      (guard_write!==guard_c.data[4])||guard_c.data[31:5]!=0||
      (!guard_write&&guard_c.data[3:0]!=0));
 assign guard_a=ecc_decode(guard_addr);
 assign guard_d=ecc_decode(guard_data);
 assign guard_c=ecc_decode(guard_ctrl);
 assign idle=(s.phase==IDLE)&&!fatal;
 assign s=(s0&s1)|(s0&s2)|(s1&s2);
 assign disagreement_event=(s0!=s1)||(s0!=s2);
 assign fatal=s.dead||record_bad||voter_mismatch||guard_bad;
 assign corrected_event=s.corrected;
 assign core_ready=rst_n&&!fatal&&s.phase==COMPLETE;
 assign core_error=s.error;
 assign rdata_code=s.response;
 assign m_axi_awaddr=s.address;
 assign m_axi_araddr=s.address;
  // Privileged, secure access; unified core bus supplies no instruction hint.
 assign m_axi_awprot=3'b001;
 assign m_axi_arprot=3'b001;
 assign m_axi_wdata=s.data;
 assign m_axi_wstrb=s.mask;
 assign m_axi_awvalid=rst_n&&!fatal&&s.phase==WRITE_DATA&&!s.aw_done;
 assign m_axi_wvalid=rst_n&&!fatal&&s.phase==WRITE_DATA&&!s.w_done;
 assign m_axi_arvalid=rst_n&&!fatal&&s.phase==READ_ADDR;
 assign m_axi_bready=rst_n&&!fatal&&s.phase==WRITE_RESP;
 assign m_axi_rready=rst_n&&!fatal&&s.phase==READ_DATA;
 always @(s or core_req or addr_code or wdata_code or ctrl_code or record_bad or m_axi_arready or m_axi_rvalid or m_axi_rdata or m_axi_rresp or m_axi_awready or m_axi_wready or m_axi_bvalid or m_axi_bresp) begin
  n=s;n.corrected=0;
  da=ecc_decode(addr_code);dw=ecc_decode(wdata_code);dc=ecc_decode(ctrl_code);
  if(record_bad||voter_mismatch||guard_bad)begin n.dead=1;end
  else if(!s.dead)case(s.phase)
   IDLE:if(core_req)begin
    if(da.uncorrectable||dc.uncorrectable||(dc.data[4]&&dw.uncorrectable))n.dead=1;
    else begin
     n.address=da.data&32'hfffffffc;n.data=dw.data;n.mask=dc.data[3:0];
     n.aw_done=0;n.w_done=0;n.error=0;n.response=ecc_encode(0);
     n.corrected=da.corrected||dc.corrected||(dc.data[4]&&dw.corrected);
     // Reject malformed controls locally, without issuing a bus transaction.
     if(dc.data[31:5]!=0||(!dc.data[4]&&dc.data[3:0]!=0))begin n.error=1;n.phase=COMPLETE;end
     else n.phase=dc.data[4]?WRITE_DATA:READ_ADDR;
    end
   end
   READ_ADDR:if(m_axi_arready)n.phase=READ_DATA;
   READ_DATA:if(m_axi_rvalid)begin
    n.response=ecc_encode(m_axi_rdata);n.error=(m_axi_rresp!=0);n.phase=COMPLETE;
   end
   WRITE_DATA:begin
    if(!s.aw_done&&m_axi_awready)n.aw_done=1;
    if(!s.w_done&&m_axi_wready)n.w_done=1;
    if(n.aw_done&&n.w_done)n.phase=WRITE_RESP;
   end
   WRITE_RESP:if(m_axi_bvalid)begin n.error=(m_axi_bresp!=0);n.phase=COMPLETE;end
   COMPLETE:n.phase=core_req?WAIT_DROP:IDLE;
   WAIT_DROP:if(!core_req)n.phase=IDLE;
   default:n.dead=1;
  endcase
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin s0<='0;s1<='0;s2<='0;guard_addr<='0;guard_data<='0;guard_ctrl<='0;end
  else begin
  s0<=n;s1<=n;s2<=n;
  if(INTEGRITY_GUARD&&s.phase==IDLE&&core_req&&!record_bad&&!s.dead&&
     !da.uncorrectable&&!dc.uncorrectable&&!(dc.data[4]&&dw.uncorrectable))begin
   guard_addr<=ecc_encode(da.data&32'hfffffffc);
   guard_data<=ecc_encode(dw.data);
   guard_ctrl<=ecc_encode(dc.data);
  end
 end
 end
endmodule
