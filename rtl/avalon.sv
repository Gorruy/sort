module avalon #(
  parameter DWIDTH = 10,
  parameter MAX_PKT_LEN
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
)

  localparam CTR_SZ = $clog2(DWIDTH);

  logic [DWIDTH - 1:0] data_buf;
  logic [CTR_SZ - 1:0] counter;

  enum logic [2:0] { IDLE_S,
                     RECIEVING_S,
                     SENDING_S } state, next_state;

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
          if ( snk_startofpacket_i && src_ready_i )
            next_state = RECIEVING_S;
          else if ( src_ready_o && src_startofpacket_o )
            next_state = SENDING_S;
        end

        RECIEVING_S: begin
          if ( snk_endofpacket_i && src_startofpacket_o )
            next_state = SENDING_S;
          else if ( snk_endofpacket_i )
            next_state = IDLE_S;
        end

        SENDING_S: begin
          if ( src_endofpacket_o )
            next_state = IDLE_S;
        end
      endcase
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S )
        counter <= '0;
      else if ( state == RECIEVING_S )
        counter <= counter + (CTR_SZ)'(1);
    end

  always_comb
    begin
      src_valid_o         = 1'b0;
      src_startofpacket_o = 1'b0;
      src_endofpacket_o   = 1'b0;
      src_data_o          = '0;

      case(state)
        IDLE_S: begin
          src_valid_o         = 1'b0;
          src_startofpacket_o = 1'b0;
          src_endofpacket_o   = 1'b0;
        end

        RECIEVING_S: begin
          src_valid_o         = 1'b0;
          src_startofpacket_o = 1'b0;
          src_endofpacket_o   = 1'b0;
        end

        SENDING_S: begin
          src_valid_o         = 1'b1;
          src_startofpacket_o = counter == (CTR_SZ)'(0) ? 1'b1: 1'b0;
          src_endofpacket_o   = counter == (CTR_SZ)'(CTR_MAX) ? 1'b1: 1'b0;
          src_data_o          = data_buf[counter];
        end
      endcase
    end
endmodule