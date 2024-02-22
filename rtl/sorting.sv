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

  // Avalon internal signals
  logic [ADDR_SZ - 1:0] counter_inside_ram_block;
  logic                 sorting;
  logic [ADDR_SZ - 1:0] send_addr_a;

  // RAM signals
  logic [ADDR_SZ - 1:0] addr_a;
  logic [ADDR_SZ - 1:0] addr_b;
  logic [DWIDTH - 1:0]  data_a;
  logic [DWIDTH - 1:0]  data_b;
  logic [DWIDTH - 1:0]  q_a;
  logic [DWIDTH - 1:0]  q_b;
  logic                 wren_a;
  logic                 wren_b;

  // Sorting block signals
  logic [ADDR_SZ - 1:0] sort_addr_a;
  logic [ADDR_SZ - 1:0] sort_addr_b;
  logic [DWIDTH - 1:0]  sort_data_a;
  logic [DWIDTH - 1:0]  sort_data_b;
  logic                 sort_wren_a;
  logic                 sort_wren_b;
  logic [DWIDTH - 1:0]  sort_q_a;
  logic [DWIDTH - 1:0]  sort_q_b;  
  logic                 done;

  dual_port_ram #(
    .DWIDTH    ( DWIDTH  ),
    .AWIDTH    ( ADDR_SZ )
  ) ram_inst0 (
    .address_a ( addr_a  ),
    .address_b ( addr_b  ),
    .clock     ( clk_i   ),
    .data_a    ( data_a  ),
    .data_b    ( data_b  ),
    .wren_a    ( wren_a  ),
    .wren_b    ( wren_b  ),
    .q_a       ( q_a     ),
    .q_b       ( q_b     )
  );  

  bubble_sort #( 
    .DWIDTH        ( DWIDTH      ), 
    .ADDR_SZ       ( ADDR_SZ     )
  ) sort_inst0 (
    .address_a     ( sort_addr_a ),
    .address_b     ( sort_addr_b ),
    .clk_i         ( clk_i       ),
    .data_a        ( sort_data_a ),
    .data_b        ( sort_data_b ),
    .wren_a        ( sort_wren_a ),
    .wren_b        ( sort_wren_b ),
    .q_a           ( sort_q_a    ),
    .q_b           ( sort_q_b    ),
    .done_o        ( done        ),
    .max_counter_i ( fullness    ),
    .sorting_i     ( sorting     )
  );

  typedef enum logic [1:0] { IDLE_S,
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
          if ( snk_endofpacket_i )
            next_state = SORTING_S;
        end

        SORTING_S: begin
          if ( done )
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

  always_comb
    begin
      src_valid_o         = 1'b0;
      src_startofpacket_o = 1'b0;
      src_endofpacket_o   = 1'b0;
      src_data_o          = '0;
      snk_ready_o         = 1'b0;
      addr_a              = '0;
      addr_b              = '0;
      data_a              = '0;
      data_b              = '0;
      wren_b              = '0;
      wren_a              = '0;
      sort_q_a            = '0;
      sort_q_b            = '0;

      case(state)
        IDLE_S: begin
          snk_ready_o = 1'b1;
        end

        RECIEVING_S: begin
          addr_a      = counter_inside_ram_block;
          data_a      = snk_data_i;
          wren_a      = snk_valid_i;
          snk_ready_o = 1'b1;
        end

        SORTING_S: begin
          addr_a   = sort_addr_a;
          addr_b   = sort_addr_b;
          data_a   = sort_data_a;
          data_b   = sort_data_b;
          wren_a   = sort_wren_a;
          wren_b   = sort_wren_b;
          sort_q_a = q_a;
          sort_q_b = q_a;
        end

        SENDING_S: begin
          addr_a              = send_addr_a;
          src_valid_o         = 1'b1;
          src_data_o          = q_a;
          src_startofpacket_o = send_addr_a == '0;
          src_endofpacket_o   = send_addr_a == counter_inside_ram_block;
        end

        default: begin
          src_valid_o         = 'x;
          src_startofpacket_o = 'x;
          src_endofpacket_o   = 'x;
          src_data_o          = 'x;
          snk_ready_o         = 'x;
          addr_a              = 'x;
          addr_b              = 'x;
          data_a              = 'x;
          data_b              = 'x;
          wren_b              = 'x;
          wren_a              = 'x;
          sort_q_a            = 'x;
          sort_q_b            = 'x;
        end
      endcase
    end

  always_ff @( posedge clk_i )
    begin
      if ( state != SENDING_S )
        send_addr_a <= '0;
      else
        send_addr_a <= send_addr_a + (ADDR_SZ)'(1);
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S || send_addr_a == counter_inside_ram_block )
        counter_inside_ram_block <= '0;
      else if ( state == RECIEVING_S && snk_valid_i )
        counter_inside_ram_block <= counter_inside_ram_block + (ADDR_SZ)'(1);
    end
  
  always_ff @( posedge clk_i )
    begin
      if ( state == RECIEVING_S && snk_endofpacket_i )
        sorting <= 1'b1;
      else
        sorting <= 1'b0;
    end

endmodule