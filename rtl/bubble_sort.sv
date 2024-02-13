module bubble_sort #(
  parameter DWIDTH      = 10,
  parameter ADDR_SZ     = 10
) (
  input  logic                 clk_i,
  
  output logic [ADDR_SZ - 1:0] address_a,
  output logic [ADDR_SZ - 1:0] address_b,
  output logic [DWIDTH - 1:0]  data_a,
  output logic [DWIDTH - 1:0]  data_b,
  output logic                 wren_a,
  output logic                 wren_b,

  input  logic [DWIDTH - 1:0]  q_a,
  input  logic [DWIDTH - 1:0]  q_b

  output logic                 done_sorting_o,
  input  logic                 snk_endofpacket_i,
);

  logic [ADDR_SZ - 1:0] inner_counter;
  logic [ADDR_SZ - 1:0] outer_counter;
  logic [DWIDTH - 1:0]  value;
  logic                 start;
  logic                 done;

  assign address_a = 2**ADDR_SZ - inner_counter;
  assign address_b = 2**ADDR_SZ - outer_counter;
  assign data_a    = q_a > q_b ? q_b : q_a;
  assign data_b    = q_a > q_b ? q_a : q_b;
  assign done      = outer_counter == '1;
  assign wren_a    = start ? 1'b1 : 1'b0;
  assign wren_b    = start ? 1'b1 : 1'b0;

  always_ff @( posedge clk_i )
    begin
      if ( start )
        inner_counter <= inner_counter + (ADDR_SZ)'(1);
      else 
        inner_counter <= '0;
    end

  always_ff @( posedge clk_i )
    begin
      if ( inner_counter == '1 )
        outer_counter <= outer_counter + (ADDR_SZ)'(1);
      else if ( !start )
        outer_counter <= '0;
    end

  always_ff @( posedge clk_i )
    begin
      if ( snk_endofpacket_i )
        start = 1'b1;
      else if ( sorted_o )
        start = 1'b0;
    end



endmodule