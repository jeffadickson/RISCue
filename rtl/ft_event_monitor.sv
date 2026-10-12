// Error observation recorder. Counters count new detector observations, not unique particles.
module ft_event_monitor #(parameter bit FI_ENABLE=0)(
 input logic clk,rst_n,input logic [15:0] flags,
 input logic [31:0] observation_pc,observation_address,
 input logic fi_valid,input logic [3:0] fi_target,input logic [511:0] fi_mask,
 output logic fi_ack,output logic event_valid,output logic [15:0] sticky_flags,
 output logic [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count,
 output logic [31:0] first_pc,first_address,last_pc,last_address,
 output logic [15:0] first_flags,last_flags,
 output logic report_disagreement
);
 typedef struct packed {
  logic [15:0] previous,sticky;
  logic [31:0] corrected,uncorrectable,disagreement,fatal;
  logic [31:0] fpc,faddr,lpc,laddr;
  logic [15:0] fflags,lflags;
  logic first_valid;
 } report_t;
 (* keep = "true", DONT_TOUCH = "TRUE" *) report_t report0,report1,report2;
 report_t voted,next;logic [15:0] effective,new_flags;
 function automatic logic [31:0] increment(input logic [31:0] value);
  increment=(value==32'hffffffff)?value:value+1;
 endfunction
 always @* begin
  voted=(report0&report1)|(report0&report2)|(report1&report2);next=voted;
  report_disagreement=(report0!=report1)||(report0!=report2);
  effective=flags;if(report_disagreement)effective[15]=1;
  new_flags=effective&~voted.previous;next.previous=effective;
  next.sticky=voted.sticky|effective;event_valid=(new_flags!=0);
  if(event_valid)begin
   next.lpc=observation_pc;next.laddr=observation_address;next.lflags=new_flags;
   if(!voted.first_valid)begin next.first_valid=1;next.fpc=observation_pc;next.faddr=observation_address;next.fflags=new_flags;end
   if(new_flags[0]||new_flags[8])next.corrected=increment(voted.corrected);
   if(new_flags[1]||new_flags[9]||new_flags[11])next.uncorrectable=increment(voted.uncorrectable);
   if(new_flags[2]||new_flags[10]||new_flags[15])next.disagreement=increment(voted.disagreement);
   if(|(new_flags&16'h08fa))next.fatal=increment(voted.fatal);
  end
  fi_ack=FI_ENABLE&&fi_valid&&fi_target>=12&&fi_target<=14;
  sticky_flags=voted.sticky;corrected_count=voted.corrected;uncorrectable_count=voted.uncorrectable;
  disagreement_count=voted.disagreement;fatal_count=voted.fatal;
  first_pc=voted.fpc;first_address=voted.faddr;first_flags=voted.fflags;
  last_pc=voted.lpc;last_address=voted.laddr;last_flags=voted.lflags;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin report0<='0;report1<='0;report2<='0;end
  else begin
   report0<=next;report1<=next;report2<=next;
   if(fi_ack)case(fi_target)
    12:report0<=next^fi_mask[$bits(report_t)-1:0];
    13:report1<=next^fi_mask[$bits(report_t)-1:0];
    14:report2<=next^fi_mask[$bits(report_t)-1:0];
   endcase
  end
 end

`ifdef FORMAL
 reg formal_past=0;
 always @(posedge clk)begin
  formal_past<=1;
  if(formal_past && rst_n && $past(rst_n))begin
   assert((sticky_flags & $past(sticky_flags))==$past(sticky_flags));
   assert(corrected_count >= $past(corrected_count));
   assert(uncorrectable_count >= $past(uncorrectable_count));
   assert(disagreement_count >= $past(disagreement_count));
   assert(fatal_count >= $past(fatal_count));
   assert(sticky_flags==($past(sticky_flags)|$past(effective)));
   assert(corrected_count==($past(new_flags[0]||new_flags[8])?increment($past(corrected_count)):$past(corrected_count)));
   assert(uncorrectable_count==($past(new_flags[1]||new_flags[9]||new_flags[11])?increment($past(uncorrectable_count)):$past(uncorrectable_count)));
   assert(disagreement_count==($past(new_flags[2]||new_flags[10]||new_flags[15])?increment($past(disagreement_count)):$past(disagreement_count)));
   assert(fatal_count==($past(|(new_flags&16'h08fa))?increment($past(fatal_count)):$past(fatal_count)));
   if($past(event_valid))begin
    assert(last_pc==$past(observation_pc));assert(last_address==$past(observation_address));assert(last_flags==$past(new_flags));
    if(!$past(voted.first_valid))begin
     assert(first_pc==$past(observation_pc));assert(first_address==$past(observation_address));assert(first_flags==$past(new_flags));
    end
   end else begin
    assert(last_pc==$past(last_pc));assert(last_address==$past(last_address));assert(last_flags==$past(last_flags));
   end

   if($past(voted.first_valid))begin
    assert(first_pc==$past(first_pc));assert(first_address==$past(first_address));assert(first_flags==$past(first_flags));
   end
   if(!$past(fi_ack))assert(report0==report1 && report0==report2);
  end
  if(rst_n)begin
   assert(event_valid==(new_flags!=0));
   if(report_disagreement)assert(effective[15]);
  end
 end
`endif
endmodule
