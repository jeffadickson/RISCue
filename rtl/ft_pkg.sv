package ft_pkg;
  typedef struct packed { logic [31:0] data; logic [38:0] repaired; logic corrected; logic uncorrectable; } ecc_result_t;
  // SECDED diagnostic syndrome (position 1..38; overall parity is separate).
  function automatic logic [5:0] ecc_syndrome(input logic [38:0] code);
    logic [5:0] value;integer k,pos;
    begin
      value=0;
      for(k=0;k<6;k=k+1)for(pos=1;pos<=38;pos=pos+1)
        if((pos&(1<<k))!=0)value[k]=value[k]^code[pos-1];
      ecc_syndrome=value;
    end
  endfunction
  // Fixed XOR trees implement the same shortened extended-Hamming 39/32 code.
  function automatic logic [38:0] ecc_encode(input logic [31:0] data);
    logic [38:0] c;
    begin
      c='0;
      c[2]=data[0]; c[6:4]=data[3:1]; c[14:8]=data[10:4]; c[30:16]=data[25:11]; c[37:32]=data[31:26];
      c[0]=^{c[2],c[4],c[6],c[8],c[10],c[12],c[14],c[16],c[18],c[20],c[22],c[24],c[26],c[28],c[30],c[32],c[34],c[36]};
      c[1]=^{c[2],c[5],c[6],c[9],c[10],c[13],c[14],c[17],c[18],c[21],c[22],c[25],c[26],c[29],c[30],c[33],c[34],c[37]};
      c[3]=^{c[4],c[5],c[6],c[11],c[12],c[13],c[14],c[19],c[20],c[21],c[22],c[27],c[28],c[29],c[30],c[35],c[36],c[37]};
      c[7]=^{c[8],c[9],c[10],c[11],c[12],c[13],c[14],c[23],c[24],c[25],c[26],c[27],c[28],c[29],c[30]};
      c[15]=^{c[16],c[17],c[18],c[19],c[20],c[21],c[22],c[23],c[24],c[25],c[26],c[27],c[28],c[29],c[30]};
      c[31]=^{c[32],c[33],c[34],c[35],c[36],c[37]};
      c[38]=^c[37:0];ecc_encode=c;
    end
  endfunction
  function automatic ecc_result_t ecc_decode(input logic [38:0] code);
    ecc_result_t r;logic [38:0] c;logic [5:0] syndrome;logic overall;
    begin
      r='0;c=code;overall=^code;
      syndrome[0]=^{code[0],code[2],code[4],code[6],code[8],code[10],code[12],code[14],code[16],code[18],code[20],code[22],code[24],code[26],code[28],code[30],code[32],code[34],code[36]};
      syndrome[1]=^{code[1],code[2],code[5],code[6],code[9],code[10],code[13],code[14],code[17],code[18],code[21],code[22],code[25],code[26],code[29],code[30],code[33],code[34],code[37]};
      syndrome[2]=^{code[3],code[4],code[5],code[6],code[11],code[12],code[13],code[14],code[19],code[20],code[21],code[22],code[27],code[28],code[29],code[30],code[35],code[36],code[37]};
      syndrome[3]=^{code[7],code[8],code[9],code[10],code[11],code[12],code[13],code[14],code[23],code[24],code[25],code[26],code[27],code[28],code[29],code[30]};
      syndrome[4]=^{code[15],code[16],code[17],code[18],code[19],code[20],code[21],code[22],code[23],code[24],code[25],code[26],code[27],code[28],code[29],code[30]};
      syndrome[5]=^{code[31],code[32],code[33],code[34],code[35],code[36],code[37]};
      if(overall)begin
        if(syndrome==0)begin c[38]=~c[38];r.corrected=1;end
        else if(syndrome<=38)begin c[syndrome-1]=~c[syndrome-1];r.corrected=1;end
        else r.uncorrectable=1;
      end else if(syndrome!=0)r.uncorrectable=1;
      r.data={c[37:32],c[30:16],c[14:8],c[6:4],c[2]};
      r.repaired=c;ecc_decode=r;
    end
  endfunction
  typedef struct packed {
    logic illegal,trap,mem,we,rd_we;
    logic [4:0] rd;
    logic [3:0] mask;
    logic [2:0] load_kind;
    logic [31:0] result,next_pc,addr,wdata,cause,tval;
  } exec_t;
  localparam logic [7:0] ST_FETCH=8'h00,ST_EXEC=8'h0f,ST_MEM=8'h33,ST_HALT=8'h3c;
  typedef struct packed {
    logic [7:0] state;
    logic [31:0] pc,insn;
    exec_t pending;
    logic [31:0] wait_count;
    logic fatal,trap;
    logic [31:0] cause,tval;
    logic [4:0] scrub;
  } control_t;
endpackage
