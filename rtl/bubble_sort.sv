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
  input  logic [DWIDTH - 1:0]  q_b,

  output logic                 done_o,
  input  logic                 sorting_i,
  input  logic [ADDR_SZ:0]     max_counter_i
);

  logic [1:0]           counter;
  logic [ADDR_SZ - 1:0] max_addr;
  logic [ADDR_SZ - 1:0] outer_counter;
  logic [DWIDTH:0]      compare;
  logic [DWIDTH - 1:0]  data_buf_a;
  logic [DWIDTH - 1:0]  data_buf_b;

  always_ff @( posedge clk_i )
    begin
      data_buf_a <= q_a;
      data_buf_b <= q_b;
    end

  always_ff @( posedge clk_i )
    compare <= (DWIDTH + 1)'(data_buf_a) - (DWIDTH + 1)'(data_buf_b);

  always_ff @( posedge clk_i )
    begin
      if ( max_addr == '0 && counter == '1 )
        done_o <= 1'b1;
      else
        done_o <= 1'b0;
    end

  always_comb
    begin
      data_a = q_b;
      data_b = q_a;

      if ( compare[DWIDTH] )
        begin
          data_a = q_a;
          data_b = q_b;
        end
    end

  // check if current ram is not full
  always_ff @( posedge clk_i )
    begin
      if ( sorting_i )
        max_addr <= (ADDR_SZ)'( max_counter_i - 2 );
      else if ( outer_counter == max_addr && counter == '1 )
        max_addr <= (ADDR_SZ)'( max_addr - 1 );
    end
  
  assign wren_a = counter == '1 && !sorting_i ? 1'b1 : 1'b0;
  assign wren_b = counter == '1 && !sorting_i ? 1'b1 : 1'b0;

  // address buses hold same values for 2 clk cycles: reading on first and writing on second
  always_ff @( posedge clk_i )
    begin
      if ( sorting_i || counter == '1 )
        counter <= 1'b0;
      else
        counter <= counter + 1'b1;
    end
  
  always_ff @( posedge clk_i )
    begin
      if ( sorting_i || outer_counter == max_addr && counter == '1 )
        outer_counter <= '0;
      else if ( counter == '1 )
        outer_counter <= outer_counter + (ADDR_SZ)'(1);
    end

  assign address_a = outer_counter;
  assign address_b = outer_counter + (ADDR_SZ)'(1);

endmodule