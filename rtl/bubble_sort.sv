module bubble_sort #(
  parameter DWIDTH      = 10,
  parameter MAX_PKT_LEN = 10,
  parameter CTR_SZ      = 10
) (
  input  logic                     clk_i,
  input  logic                     srst_i,
  input  logic [MAX_PKT_LEN - 1:0] data_buf,
  input  logic [CTR_SZ - 1:0]      counter,
  input  logic                     snk_startofpacket_i,

  output logic                     sorted
);

  logic [CTR_SZ - 1:0] inner_counter;
  logic [DWIDTH - 1:0] value;

  always_comb
    begin
      inner_counter = counter - 1;
      value         = data_buf[counter];
      sorted        = 1'b0;

      if ( counter != '0 )
        begin
          do
            begin
              if ( data_buf[inner_counter] > value )
                begin
                  { data_buf[inner_counter], data_buf[inner_counter + 1] } = 
                  { data_buf[inner_counter + 1], data_buf[inner_counter] }
                end
              inner_counter -= 1;
            end 
          while ( inner_counter != '0 );
        end
        
      sorted = 1'b1;
    end

endmodule;