module formal_monitor(input clk);
 reg started=0,injected=0;
 always @(posedge clk)started<=1;
 (* anyseq *) reg [15:0] flags;
 (* anyseq *) reg [31:0] pc,address;
 (* anyseq *) reg inject;
 (* anyconst *) reg [1:0] replica;
 (* anyconst *) reg [511:0] mask;
 wire fire=started&&inject&&!injected;
 wire report_disagreement;wire [15:0] sticky;
 always @*assume(replica<3);
 always @(posedge clk)if(fire)injected<=1;
 ft_event_monitor #(.FI_ENABLE(1)) dut(.clk(clk),.rst_n(started),.flags(flags),.observation_pc(pc),.observation_address(address),
 .report_disagreement(report_disagreement),.sticky_flags(sticky),
 .fi_valid(fire),.fi_target(4'd12+{2'b0,replica}),.fi_mask(mask));
 always @(posedge clk)begin
  cover(injected&&report_disagreement);
  cover(injected&&sticky[15]&&!report_disagreement);
 end
endmodule
