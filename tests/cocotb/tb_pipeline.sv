module tb_pipeline #(parameter bit RF_TMR=0,FI_ENABLE=1,parameter integer WORDS=1024);
 logic clk,rst_n,external_irq,fi_valid;
 logic [3:0] fi_target;logic [31:0] fi_index;logic [511:0] fi_mask;
 wire halted,fatal,trap,retire_valid,fi_ack,event_valid,corrected_event,disagreement_event;
 wire [31:0] first_pc,first_address,last_pc,last_address;wire [15:0] first_flags,last_flags;
 wire [31:0] pc,trap_cause,trap_value,retire_pc,retire_insn,retire_result;
 wire [4:0] retire_rd;
 wire [15:0] sticky_flags;
 wire [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count;
 riscue_pipeline_soc #(.WORDS(WORDS),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE)) soc(.*);
endmodule
