module avalon #(
  parameter DWIDTH      = 10,
  parameter MAX_PKT_LEN = 10
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

  localparam ADDR_SZ              = ( 10000 / DWIDTH );
  localparam CTR_SZ               = $clog2(MAX_PKT_LEN);
  localparam NUMBER_OF_RAM_BLOCKS = ( DWIDTH * MAX_PKT_LEN + 1023 ) / 1024;
  localparam RAM_COUNTER          = $clog2(NUMBER_OF_RAM_BLOCKS);

  // Avalon internal signals
  logic [DWIDTH - 1:0]                              data_to_write;
  logic [RAM_COUNTER - 1:0]                         current_ram_block;
  logic [ADDR_SZ - 1:0]                             counter_inside_ram_block;

  // RAM signals
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][ADDR_SZ - 1:0] addr_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][ADDR_SZ - 1:0] addr_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  data_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  data_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  q_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  q_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0]                wren_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0]                wren_b;

  // FIFO signals
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][ADDR_SZ - 1:0] fifo_addr_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][ADDR_SZ - 1:0] fifo_addr_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  fifo_data_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  fifo_data_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  fifo_q_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  fifo_q_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0]                fifo_wren_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0]                fifo_wren_b;

  // Sorting block signals
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][ADDR_SZ - 1:0] sort_addr_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][ADDR_SZ - 1:0] sort_addr_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  sort_data_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  sort_data_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  sort_q_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0][DWIDTH - 1:0]  sort_q_b;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0]                sort_wren_a;
  logic [NUMBER_OF_RAM_BLOCKS - 1:0]                sort_wren_b;  

  genvar i;
  generate
    for ( i = 0; i < NUMBER_OF_RAM_BLOCKS; i++ )
      begin
        ram ram_inst0 (
          .address_a ( addr_a [i] ),
          .address_b ( addr_b [i] ),
          .clock     ( clk_i  [i] ),
          .data_a    ( data_a [i] ),
          .data_b    ( data_b [i] ),
          .wren_a    ( wren_a [i] ),
          .wren_b    ( wren_b [i] ),
          .q_a       ( q_a    [i] ),
          .q_b       ( q_b    [i] )
        );
      end    
  endgenerate

  generate

    for ( i = 0; i < NUMBER_OF_RAM_BLOCKS; i++ )
      begin
        bubble_sort #( 
          .DWIDTH        ( DWIDTH                         ), 
          .CTR_SZ        ( CTR_SZ                         ), 
          .MAX_PKT_LEN   ( MAX_PKT_LEN                    )
        ) sort (
          .address_a     ( sort_addr_a [i]                ),
          .address_b     ( sort_addr_b [i]                ),
          .clk_i         ( sort_clk_i  [i]                ),
          .data_a        ( sort_data_a [i]                ),
          .data_b        ( sort_data_b [i]                ),
          .wren_a        ( sort_wren_a [i]                ),
          .wren_b        ( sort_wren_b [i]                ),
          .q_a           ( sort_q_a    [i]                ),
          .q_b           ( sort_q_b    [i]                ),
          .inner_counter ( counter_inside_ram_block       )
        );
      end
  endgenerate

  typedef enum logic [2:0] { IDLE_S,
                             RECIEVING_S,
                             SORTING_S,
                             SENDING_S } state_t;
  state_t state, next_state;

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
            next_state = RECIEVING_S;
          else if ( snk_ready_o && src_startofpacket_o )
            next_state = SENDING_S;
        end

        RECIEVING_S: begin
          if ( snk_endofpacket_i && src_startofpacket_o )
            next_state = SORTING_S;
          else if ( snk_endofpacket_i )
            next_state = IDLE_S;
        end

        SORTING_S: begin
          if ( sorted )
            next_state = SENDING_S;
        end

        SENDING_S: begin
          if ( src_endofpacket_o )
            next_state = IDLE_S;
        end

        default: begin
          next_state = state_t'('x);
        end
      endcase
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S || src_endofpacket_o || snk_endofpacket_i )
        counter <= '0;
      else if ( ( state == SENDING_S && src_ready_i ) ||
                ( state == RECIEVING_S && snk_valid_i ) )
        counter <= counter + (CTR_SZ)'(1);
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S || src_endofpacket_o || snk_endofpacket_i || counter == 2**ADDR_SZ )
        counter_inside_ram_block <= '0;
      else if ( ( state == SENDING_S && src_ready_i ) ||
                ( state == RECIEVING_S && snk_valid_i ) )
        counter_inside_ram_block <= counter_inside_ram_block + (ADDR_SZ)'(1);
    end
  
  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S || src_endofpacket_o || snk_endofpacket_i )
        current_ram_block <= '0;
      else if ( counter == 2**ADDR_SZ )
        current_ram_block <= current_ram_block + (RAM_COUNTER)'(1);
    end
  
  always_ff @( posedge clk_i )
    begin
      if ( state == RECIEVING_S && snk_valid_i )
        data_to_write <= snk_data_i;
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
          snk_ready_o         = 1'b1;
        end

        RECIEVING_S: begin
          addr_a                    = counter;
          data_a[current_ram_block] = data_to_write;
          wren_a[current_ram_block] = 1'b1;
          src_valid_o               = 1'b0;
          src_startofpacket_o       = 1'b0;
          src_endofpacket_o         = 1'b0;
          snk_ready_o               = 1'b1;
        end

        SORTING_S: begin
          src_valid_o         = 1'b0;
          src_startofpacket_o = 1'b0;
          src_endofpacket_o   = 1'b0;
          snk_ready_o         = 1'b0;
        end

        SENDING_S: begin
          src_valid_o         = 1'b1;
          src_startofpacket_o = counter == (CTR_SZ)'(0) ? 1'b1: 1'b0;
          src_endofpacket_o   = counter == (CTR_SZ)'(MAX_PKT_LEN) ? 1'b1: 1'b0;
          src_data_o          = data_buf[counter];
          snk_ready_o         = 1'b0;
        end

        default: begin
          src_valid_o         = 'x;
          src_startofpacket_o = 'x;
          src_endofpacket_o   = 'x;
          src_data_o          = 'x;
        end
      endcase
    end
endmodule