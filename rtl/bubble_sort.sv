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

  logic [1:0]           counter;
  logic                 in_process;
  logic [ADDR_SZ - 1:0] max_addr;
  logic [ADDR_SZ - 1:0] iteration_counter;

  assign done_o = in_process ? iteration_counter == max_addr - 1: 1'b0;

  always_comb
    begin
      data_a = '0;
      data_b = '0;
      if ( in_process )
        begin
          data_a = q_a < q_b ? q_a : q_b;
          data_b = q_a < q_b ? q_b : q_a;
        end
    end

  always_ff @( posedge clk_i )
    begin
      if ( sorting_i )
        in_process <= 1'b1;
      else
        in_process <= 1'b0;
    end

  // check if current ram is not full
  always_ff @( posedge clk_i )
    begin
      if ( sorting_i && !in_process )
        max_addr <= max_counter_i != '0 ? max_counter_i - (ADDR_SZ)'(1) : '1;
    end
  
  always_ff @( posedge clk_i )
    begin
      if ( in_process && counter[1] )
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
      if ( done_o )
        counter <= '0;
      else if ( !in_process )
        counter <= { 1'b1, 1'b0 };
      else
        { counter[0], counter[1] } <= { counter[1], counter[0] };
    end

  always_ff @( posedge clk_i )
    begin
      if ( !in_process )
        address_a <= '0;
      else if ( address_a == max_addr - iteration_counter - (ADDR_SZ)'(1) && counter[0] )
        address_a <= '0;
      else if ( counter[0] )
        address_a <= address_a + (ADDR_SZ)'(1);
    end

  always_ff @( posedge clk_i )
    begin
      if ( !in_process )
        iteration_counter <= '0;
      else if ( address_a == max_addr - iteration_counter - (ADDR_SZ)'(1) && counter[0] )
        iteration_counter <= iteration_counter + (ADDR_SZ)'(1);
    end

  always_ff @( posedge clk_i )
    begin
      if ( !in_process )
        address_b <= (ADDR_SZ)'(1);
      else if ( address_b == max_addr - iteration_counter && counter[0] )
        address_b <= (ADDR_SZ)'(1);
      else if ( counter[0] )
        address_b <= address_b + (ADDR_SZ)'(1);
    end


endmodule