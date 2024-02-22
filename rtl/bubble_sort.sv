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
  input  logic [ADDR_SZ - 1:0] max_counter_i
);

  logic                 counter;
  logic [ADDR_SZ - 1:0] max_addr;
  logic [ADDR_SZ - 1:0] outer_counter;
  logic [ADDR_SZ - 1:0] iteration_counter;
  logic [DWIDTH - 1:0]  less_data;
  logic [DWIDTH - 1:0]  more_data;

  always_ff @( posedge clk_i )
    begin
      if ( max_addr == (ADDR_SZ)'(1) )
        done_o <= 1'b1;
      else
        done_o <= 1'b0;
    end

  always_comb 
    begin
      data_a = q_a;
      data_b = q_b;

      if ( q_a > q_b )
        begin
          data_a = q_b;
          data_b = q_a;
        end
    end

  // check if current ram is not full
  always_ff @( posedge clk_i )
    begin
      if ( sorting_i )
        max_addr <= max_counter_i;
      else if ( counter == max_addr )
        max_addr <= max_addr - (ADDR_SZ)'(1);
    end
  
  always_ff @( posedge clk_i )
    begin
      if ( !counter )
        begin
          wren_b <= 1'b1;
          wren_a <= 1'b1;
        end
      else 
        begin
          wren_b <= 1'b0;
          wren_a <= 1'b0;
        end
    end

  // address buses hold same values for 2 clk cycles: reading on first and writing on second
  always_ff @( posedge clk_i )
    begin
      if ( sorting_i )
        counter <= 1'b1;
      else
        counter <= counter + 1'b1;
    end
  
  always_ff @( posedge clk_i )
    begin
      if ( sorting_i || outer_counter == max_addr )
        outer_counter <= '0;
      else if ( counter )
        outer_counter <= outer_counter + (ADDR_SZ)'(1);
    end

  assign address_a = outer_counter;
  assign address_b = outer_counter + (ADDR_SZ)'(1);

endmodule