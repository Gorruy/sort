module sorting #(
  parameter DWIDTH      = 8,
  parameter MAX_PKT_LEN = 256
) (
  input  logic                clk_i,
  input  logic                srst_i,

  input  logic [DWIDTH - 1:0] snk_data_i,
  input  logic                snk_startofpacket_i,
  input  logic                snk_endofpacket_i,
  input  logic                snk_valid_i,

  output logic                snk_ready_o,
  output logic [DWIDTH - 1:0] src_data_o,
  output logic                src_startofpacket_o,
  output logic                src_endofpacket_o,
  output logic                src_valid_o,

  input  logic                src_ready_i
);    

  localparam ADDR_SZ = $clog2(MAX_PKT_LEN);

  logic [DWIDTH - 1:0] data;         
  logic                wrreq;        
  logic                rdreq;        
  logic [DWIDTH - 1:0] q;            
  logic                empty;        
  logic                full;  
  logic [ADDR_SZ:0]    usedw;

  logic [1:0]          valid;
  logic                start_of_sending;

  typedef enum logic [1:0] { IDLE_S,
                             RECIEVING_S,
                             SORTING_S,
                             SENDING_S } state_t;
  state_t state, next_state;

  fifo #(
    .DWIDTH          ( DWIDTH  ),
    .AWIDTH          ( ADDR_SZ ),
    .SHOWAHEAD       ( 1       ),
    .REGISTER_OUTPUT ( 0       )              
  ) fifo_inst (
    .clk_i           ( clk_i   ),
    .srst_i          ( srst_i  ),
  
    .data_i          ( data    ),
    .wrreq_i         ( wrreq   ),
    .rdreq_i         ( rdreq   ),
  
    .q_o             ( q       ),
    .empty_o         ( empty   ),
    .full_o          ( full    ),
    .usedw_o         ( usedw   )
  );

  always_ff @( posedge clk_i )
    begin
      if ( srst_i )
        state <= IDLE_S;
      else
        state <= next_state;
    end

  always_comb
    begin
      next_state = state;

      case (state)
        IDLE_S: begin
          if ( snk_startofpacket_i && snk_valid_i )
            begin
              if ( snk_endofpacket_i )
                next_state = SENDING_S;
              else
                next_state = RECIEVING_S;
            end
        end

        RECIEVING_S: begin
          if ( snk_endofpacket_i )
            next_state = SORTING_S;
        end

        SORTING_S: begin
          if ( done )
            next_state = SENDING_S;
        end

        SENDING_S: begin
          if ( src_endofpacket_o && src_ready_i )
            next_state = IDLE_S;
        end

        default: begin
          next_state = state_t'('x);
        end
      endcase
    end

  always_comb
    begin
      src_valid_o         = 1'b0;
      src_startofpacket_o = 1'b0;
      src_endofpacket_o   = 1'b0;
      src_data_o          = '0;
      snk_ready_o         = 1'b0;
      wrreq               = 1'b0;
      rereq               = 1'b0;
      data                = '0;

      case(state)
        IDLE_S: begin
          snk_ready_o = 1'b1;
          wrreq       = snk_startofpacket_i ? 1'b1 : 1'b0;
          data_a      = snk_data_i;
        end

        RECIEVING_S: begin
          snk_ready_o = 1'b1;
          wrreq       = snk_valid_i;
          data        = snk_data_i;
        end

        SORTING_S: begin
          snk_ready_o = 1'b0;
        end

        SENDING_S: begin
          rdreq               = 1'b1;
          src_valid_o         = valid[0];
          src_data_o          = q;
          src_startofpacket_o = start_of_sending;
          src_endofpacket_o   = usedw == (ADDR_SZ)'(1);
        end

        default: begin
          src_valid_o         = 'x;
          src_startofpacket_o = 'x;
          src_endofpacket_o   = 'x;
          src_data_o          = 'x;
          snk_ready_o         = 'x;
          wrreq               = 'x;
          rereq               = 'x;
          data                = 'x;
        end

      endcase
      
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S || state == SENDING_S && src_ready_i )
        start_of_sending <= 1'b0;
      else if ( state == SORTING_S && done )
        start_of_sending <= 1'b1;
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == SORTING_S && done )
        valid <= { 1'b0, 1'b1 };
      else 
        valid <= { valid[0], 1'b1 };
    end

endmodule