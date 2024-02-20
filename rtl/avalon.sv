module avalon #(
  parameter DWIDTH      = 32,
  parameter MAX_PKT_LEN = 300,
  parameter RAM_N       = 2
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

  localparam ADDR_SZ     = $clog2(MAX_PKT_LEN * DWIDTH / RAM_N);
  localparam RAM_COUNTER = $clog2(RAM_N);

  // Avalon internal signals
  logic [RAM_COUNTER - 1:0]          current_ram;
  logic [RAM_N - 1:0][ADDR_SZ - 1:0] counter_inside_ram_block;
  logic                              sorting;

  // RAM signals
  logic [RAM_N - 1:0][ADDR_SZ - 1:0] addr_a;
  logic [RAM_N - 1:0][ADDR_SZ - 1:0] addr_b;
  logic [RAM_N - 1:0][DWIDTH - 1:0]  data_a;
  logic [RAM_N - 1:0][DWIDTH - 1:0]  data_b;
  logic [RAM_N - 1:0][DWIDTH - 1:0]  q_a;
  logic [RAM_N - 1:0][DWIDTH - 1:0]  q_b;
  logic [RAM_N - 1:0]                wren_a;
  logic [RAM_N - 1:0]                wren_b;

  // Sorting block signals
  logic [RAM_N - 1:0][ADDR_SZ - 1:0] sort_addr_a;
  logic [RAM_N - 1:0][ADDR_SZ - 1:0] sort_addr_b;
  logic [RAM_N - 1:0][DWIDTH - 1:0]  sort_data_a;
  logic [RAM_N - 1:0][DWIDTH - 1:0]  sort_data_b;
  logic [RAM_N - 1:0]                sort_wren_a;
  logic [RAM_N - 1:0]                sort_wren_b; 
  logic [RAM_N - 1:0]                done;

  // Sending signals 
  logic [RAM_N - 1:0][ADDR_SZ - 1:0] send_addr_a;
  logic [RAM_N - 1:0][ADDR_SZ - 1:0] send_addr_b;
  logic [RAM_COUNTER - 1:0]          smallest_index;
  logic [DWIDTH - 1:0]               smallest_value;
  logic [ADDR_SZ - 1:0]              max_index_of_last_ram;
  logic [RAM_N - 1:0]                available_ram;

  genvar i;
  generate
    for ( i = 0; i < RAM_N; i++ )
      begin : rams
        dual_port_ram #(
          .DWIDTH    ( DWIDTH     ),
          .AWIDTH    ( ADDR_SZ    )
        ) ram_inst0 (
          .address_a ( addr_a [i] ),
          .address_b ( addr_b [i] ),
          .clock     ( clk_i      ),
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
    for ( i = 0; i < RAM_N; i++ )
      begin : sorts
        bubble_sort #( 
          .DWIDTH        ( DWIDTH                       ), 
          .ADDR_SZ       ( ADDR_SZ                      )
        ) sort_inst0 (
          .address_a     ( sort_addr_a              [i] ),
          .address_b     ( sort_addr_b              [i] ),
          .clk_i         ( clk_i                        ),
          .data_a        ( sort_data_a              [i] ),
          .data_b        ( sort_data_b              [i] ),
          .wren_a        ( sort_wren_a              [i] ),
          .wren_b        ( sort_wren_b              [i] ),
          .q_a           ( q_a                      [i] ),
          .q_b           ( q_b                      [i] ),
          .done_o        ( done                     [i] ),
          .max_counter_i ( counter_inside_ram_block [i] ),
          .sorting_i     ( sorting                      )
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
          if ( snk_endofpacket_i )
            next_state = SORTING_S;
        end

        SORTING_S: begin
          if ( done[0] )
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
      if ( state != RECIEVING_S )
        current_ram <= '0;
      else if ( counter_inside_ram_block == '1 )
        current_ram <= current_ram + (RAM_COUNTER)'(1);
    end

  always_ff @( posedge clk_i )
    begin
      if ( state != RECIEVING_S )
        counter_inside_ram_block <= '0;
      else
        counter_inside_ram_block[current_ram] <= counter_inside_ram_block[current_ram] + (RAM_COUNTER)'(1);
    end

  always_ff @( posedge clk_i )
    begin
      if ( snk_endofpacket_i )
        max_index_of_last_ram <= counter_inside_ram_block;
    end

  always_comb
    begin
      src_valid_o         = 1'b0;
      src_startofpacket_o = 1'b0;
      src_endofpacket_o   = 1'b0;
      src_data_o          = '0;
      sorting             = 1'b0;
      addr_a              = '0;
      addr_b              = '0;
      data_a              = '0;
      data_b              = '0;
      wren_b              = '0;
      wren_a              = '0;

      case(state)
        IDLE_S: begin
          src_valid_o         = 1'b0;
          src_startofpacket_o = 1'b0;
          src_endofpacket_o   = 1'b0;
          snk_ready_o         = 1'b1;
        end

        RECIEVING_S: begin
          addr_a[current_ram] = counter_inside_ram_block[current_ram];
          data_a[current_ram] = snk_data_i;
          wren_a[current_ram] = snk_valid_i;
          src_valid_o         = 1'b0;
          src_startofpacket_o = 1'b0;
          src_endofpacket_o   = 1'b0;
          snk_ready_o         = 1'b1;
        end

        SORTING_S: begin
          sorting             = 1'b1;
          addr_a              = sort_addr_a;
          addr_b              = sort_addr_b;
          data_a              = sort_data_a;
          data_b              = sort_data_b;
          wren_a              = sort_wren_a;
          wren_b              = sort_wren_b;
          src_valid_o         = 1'b0;
          src_startofpacket_o = 1'b0;
          src_endofpacket_o   = 1'b0;
          snk_ready_o         = 1'b0;
        end

        SENDING_S: begin
          addr_a              = send_addr_a;
          src_valid_o         = 1'b1;
          src_startofpacket_o = send_addr_a == '0 ? 1'b1: 1'b0;
          src_endofpacket_o   = available_ram == '0 ? 1'b1: 1'b0;
          src_data_o          = smallest_value;
          snk_ready_o         = 1'b0;
        end

        default: begin
          wren_b              = 'x;
          wren_a              = 'x;
          src_valid_o         = 'x;
          src_startofpacket_o = 'x;
          src_endofpacket_o   = 'x;
          src_data_o          = 'x;
        end
      endcase
    end

    always_ff @( posedge clk_i )
      begin
        if ( state != SENDING_S )
          send_addr_a <= '0;
        else if ( src_ready_i )
          send_addr_a[smallest_index] <= send_addr_a[smallest_index] + (ADDR_SZ)'(1);
      end

    always_ff @( posedge clk_i )
      begin
        if ( state == IDLE_S )
          available_ram <= '0;
        else if ( state == RECIEVING_S )
          available_ram[current_ram] <= 1'b1;
        else if ( src_ready_i && state == SENDING_S )
          begin
            if ( send_addr_a[smallest_index] == '1 ||
                 ( smallest_index == RAM_N - 1 && send_addr_a[smallest_index] == max_index_of_last_ram ) )
              available_ram[smallest_index] <= 1'b0;
          end
      end

    always_comb
      begin
        smallest_value = '1;
        smallest_index = '0;

        for ( int i = 0; i < RAM_N; i++ )
          begin
            if ( q_a[i] <= smallest_value && available_ram[i] )
              begin
                smallest_value = q_a[i];
                smallest_index = (RAM_COUNTER)'(i);
              end
          end
      end
endmodule