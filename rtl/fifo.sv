module fifo #(
  parameter DWIDTH             = 32,
  parameter AWIDTH             = 4,
  parameter SHOWAHEAD          = 1,
  parameter REGISTER_OUTPUT    = 0
) (
  input  logic                clk_i,
  input  logic                srst_i,
  
  input  logic [DWIDTH - 1:0] data_i,
  input  logic                wrreq_i,
  input  logic                rdreq_i,

  output logic [DWIDTH - 1:0] q_o,
  output logic                empty_o,
  output logic                full_o,
  output logic [AWIDTH:0]     usedw_o,
  output logic                almost_full_o,
  output logic                almost_empty_o
);

  logic [AWIDTH - 1:0] rd_ptr;
  logic [AWIDTH - 1:0] wr_ptr;
  logic [AWIDTH - 1:0] read_address;

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
    .DWIDTH        ( DWIDTH                   ), 
    .ADDR_SZ       ( ADDR_SZ                  )
  ) sort_inst0 (
    .address_a     ( sort_addr_a              ),
    .address_b     ( sort_addr_b              ),
    .clk_i         ( clk_i                    ),
    .data_a        ( sort_data_a              ),
    .data_b        ( sort_data_b              ),
    .wren_a        ( sort_wren_a              ),
    .wren_b        ( sort_wren_b              ),
    .q_a           ( sort_q_a                 ),
    .q_b           ( sort_q_b                 ),
    .done_o        ( done                     ),
    .max_counter_i ( counter_inside_ram_block ),
    .sorting_i     ( sorting                  )
  );

  assign full_o = ( usedw_o == 2**AWIDTH );

  always_ff @( posedge clk_i )
    begin
      if ( srst_i )
        empty_o <= 1'b1;
      else
        empty_o <= ( usedw_o == '0 ) || ( usedw_o == (AWIDTH + 1)'(1) && rdreq_i );
    end

  always_comb
    begin
      read_address = rd_ptr - (AWIDTH)'(1);
      
      if ( rdreq_i && usedw_o > (AWIDTH)'(1) )
        read_address = rd_ptr + (AWIDTH)'(1);
      else if ( usedw_o >= (AWIDTH)'(1) )
        read_address = rd_ptr;
    end

  always_ff @( posedge clk_i )
    begin
      if ( srst_i )
        usedw_o <= '0;
      else 
        begin
          if ( wrreq_i && !full_o && !rdreq_i )
            usedw_o <= usedw_o + (AWIDTH + 1)'(1);
          if ( rdreq_i && !empty_o && !wrreq_i )
            usedw_o <= usedw_o - (AWIDTH + 1)'(1);
        end
    end

  always_ff @( posedge clk_i )
    begin
      if ( srst_i )
        rd_ptr <= '0;
      else if ( rdreq_i && !empty_o )
        rd_ptr <= rd_ptr + (AWIDTH)'(1);
    end

  always_ff @( posedge clk_i )
    begin
      if ( srst_i )
        wr_ptr <= '0;
      else if ( wrreq_i && !full_o )
        wr_ptr <= wr_ptr + (AWIDTH)'(1);
    end
  
endmodule