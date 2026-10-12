`timescale 1ns/1ps
module tb_python #(parameter bit RF_TMR=0,parameter bit FI_ENABLE=1);
 logic clk=0,rst_n=0;
 logic fi_valid=0;logic [3:0] fi_target=0;logic [31:0] fi_index=0;logic [511:0] fi_mask=0;
 wire fi_ack,halted,fatal,trap,corrected_event,disagreement_event,retire_valid,event_valid;
 wire [31:0] trap_cause,trap_value,pc,retire_pc,retire_insn,retire_result;
 wire [4:0] retire_rd;wire [15:0] sticky_flags,first_flags,last_flags;
 wire [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count;
 wire [31:0] first_pc,first_address,last_pc,last_address;
 rv32im_ft_soc #(.WORDS(8192),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE)) soc(.*);
endmodule
