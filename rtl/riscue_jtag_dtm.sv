// Standard 5-bit JTAG TAP: IDCODE=1, DTMCS=0x10, DMI=0x11, BYPASS=0x1f.
// One bundled-data request at a time; payload held across toggle synchronizers.
module riscue_jtag_dtm #(parameter logic [31:0] IDCODE=32'h00000001)(
 input logic clk,rst_n,tck,tms,tdi,output logic tdo,
 output logic dmi_valid,dmi_write,output logic [6:0] dmi_addr,output logic [31:0] dmi_wdata,
 input logic [31:0] dmi_rdata
);
 localparam [3:0] RESET=0,IDLE=1,SELDR=2,CAPDR=3,SHIFTDR=4,EXIT1DR=5,PAUSEDR=6,EXIT2DR=7,UPDATEDR=8,
 SELIR=9,CAPIR=10,SHIFTIR=11,EXIT1IR=12,PAUSEIR=13,EXIT2IR=14,UPDATEIR=15;
 (* ASYNC_REG="TRUE" *) logic [1:0] tck_reset_pipe;
 always_ff @(posedge tck or negedge rst_n)
  if(!rst_n)tck_reset_pipe<=0;else tck_reset_pipe<={tck_reset_pipe[0],1'b1};
 wire tck_rst_n=tck_reset_pipe[1];
 logic tdo_next;
 logic [3:0] tap,next;
 logic [4:0] ir,ir_shift;
 logic [40:0] dr;
 logic [40:0] request_payload;
 logic req_toggle,rsp_toggle;
 (* ASYNC_REG="TRUE" *) logic req_meta,req_sync,rsp_meta,rsp_sync;
 logic req_seen;
 logic [31:0] response_payload;
 logic [1:0] sticky;
 logic pending;
 always_comb begin
  next=RESET;
  case(tap)
   RESET:next=tms?RESET:IDLE;IDLE:next=tms?SELDR:IDLE;
   SELDR:next=tms?SELIR:CAPDR;CAPDR:next=tms?EXIT1DR:SHIFTDR;
   SHIFTDR:next=tms?EXIT1DR:SHIFTDR;EXIT1DR:next=tms?UPDATEDR:PAUSEDR;
   PAUSEDR:next=tms?EXIT2DR:PAUSEDR;EXIT2DR:next=tms?UPDATEDR:SHIFTDR;
   UPDATEDR:next=tms?SELDR:IDLE;SELIR:next=tms?RESET:CAPIR;
   CAPIR:next=tms?EXIT1IR:SHIFTIR;SHIFTIR:next=tms?EXIT1IR:SHIFTIR;
   EXIT1IR:next=tms?UPDATEIR:PAUSEIR;PAUSEIR:next=tms?EXIT2IR:PAUSEIR;
   EXIT2IR:next=tms?UPDATEIR:SHIFTIR;UPDATEIR:next=tms?SELDR:IDLE;
  endcase
  tdo_next=tap==SHIFTIR?ir_shift[0]:tap==SHIFTDR?dr[0]:0;
 end
 always_ff @(negedge tck or negedge tck_rst_n)
  if(!tck_rst_n)tdo<=0;else tdo<=tdo_next;
 always_ff @(posedge tck or negedge tck_rst_n)begin
  if(!tck_rst_n)begin tap<=RESET;ir<=1;ir_shift<=1;dr<=0;request_payload<=0;req_toggle<=0;rsp_meta<=0;rsp_sync<=0;sticky<=0;pending<=0;end
  else begin
   tap<=next;rsp_meta<=rsp_toggle;rsp_sync<=rsp_meta;
   if(pending&&rsp_sync==req_toggle)pending<=0;
   case(tap)
    RESET:begin ir<=1;sticky<=0;end
    CAPIR:ir_shift<=5'b00001;
    SHIFTIR:ir_shift<={tdi,ir_shift[4:1]};
    UPDATEIR:ir<=ir_shift;
    CAPDR:case(ir)
     1:dr<={9'b0,IDCODE};
     5'h10:dr<={9'b0,32'h00001071|({30'b0,sticky}<<10)}; // idle=1, abits=7, version=1
     5'h11:begin
      dr<={request_payload[40:34],response_payload,(sticky!=0?sticky:pending&&rsp_sync!=req_toggle?2'b11:2'b00)};
      if(pending&&rsp_sync!=req_toggle)sticky<=3;
     end
     default:dr<=0;
    endcase
    SHIFTDR:case(ir)
     1,5'h10:dr<={9'b0,tdi,dr[31:1]};
     5'h11:dr<={tdi,dr[40:1]};
     default:dr<={40'b0,tdi};
    endcase
    UPDATEDR:begin
     if(ir==5'h10&&dr[16])sticky<=0;
     if(ir==5'h11&&dr[1:0]!=0&&sticky==0)begin
      if(pending&&rsp_sync!=req_toggle)sticky<=3;
      else if(dr[1:0]==3)sticky<=2;
      else begin request_payload<=dr;req_toggle<=~req_toggle;pending<=1;end
     end
    end
    default:begin end
   endcase
  end
 end
 assign dmi_valid=req_sync!=req_seen;
 assign dmi_write=request_payload[1:0]==2;
 assign dmi_addr=request_payload[40:34];assign dmi_wdata=request_payload[33:2];
 always_ff @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin req_meta<=0;req_sync<=0;req_seen<=0;rsp_toggle<=0;response_payload<=0;end
  else begin
   req_meta<=req_toggle;req_sync<=req_meta;
   if(dmi_valid)begin response_payload<=dmi_rdata;req_seen<=req_sync;rsp_toggle<=req_sync;end
  end
 end
endmodule
