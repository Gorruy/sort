module top_tb;

  parameter NUMBER_OF_TEST_RUNS = 100;
  parameter TIMEOUT             = 10;
  parameter MAX_PKT_LEN         = 100;
  parameter DWIDTH              = 10;

  bit                  clk;
  logic                srst;

  logic [DWIDTH - 1:0] snk_data;            
  logic                snk_startofpacket;   
  logic                snk_endofpacket;     
  logic                snk_valid;           
  logic                snk_ready_o;           
  logic [DWIDTH - 1:0] src_data;            
  logic                src_startofpacket;   
  logic                src_endofpacket;     
  logic                src_valid;           
  logic                src_ready_i; 

  logic                srst_done;
  bit                  test_succeed;

  initial forever #5 clk = !clk;

  default clocking cb @( posedge clk );
  endclocking

  initial 
    begin
      srst      <= 1'b0;
      ##1;
      srst      <= 1'b1;
      ##1;
      srst      <= 1'b0;
      srst_done <= 1'b1;
    end      

 avalon #(
    .DWIDTH              ( DWIDTH              ),
    .MAX_PKT_LEN         ( MAX_PKT_LEN         )
  ) DUT (
    .clk_i               ( clk                 ),
    .srst_i              ( srst                ), 
    .snk_data_i          ( snk_data            ),
    .snk_startofpacket_i ( snk_startofpacket   ),
    .snk_endofpacket_i   ( snk_endofpacket     ),
    .snk_valid_i         ( snk_valid           ),
    .snk_ready_o         ( snk_ready_o         ),
    .src_data_o          ( src_data            ),
    .src_startofpacket_o ( src_startofpacket   ),
    .src_endofpacket_o   ( src_endofpacket     ),
    .src_valid_o         ( src_valid           ),
    .src_ready_i         ( src_ready_i         )
);

  typedef logic [DWIDTH - 1:0] data_t[$];

  mailbox #( data_t ) generated_data = new();
  mailbox #( data_t ) input_data     = new();
  mailbox #( data_t ) output_data    = new();

  task generate_data( mailbox #( data_t ) generated_data );

    data_t data;
    int    len;

    repeat ( NUMBER_OF_TEST_RUNS )
      begin
        data = {};
        len  = $urandom_range( MAX_PKT_LEN, 1 );

        for ( int i = 0; i < len; i++ )
          begin
            data.push_back( $urandom_range( 2**DWIDTH - 1, 0 ) );
          end

        generated_data.put(data);

      end

  endtask

  task send_data( mailbox #( data_t ) generated_data,
                  mailbox #( data_t ) input_data 
                );
    
      data_t exposed_data, gen_data;

      while ( generated_data.num() )
        begin
          @( posedge clk );
          generated_data.get( gen_data );

          snk_data          = gen_data.pop_back();
          snk_valid         = 1'b1;
          snk_startofpacket = 1'b1;
          snk_endofpacket   = 1'b0;

          while ( gen_data.size() != 1 )
            begin
              @( posedge clk );
              while ( !src_ready_i )
                begin
                  ##1;
                end
              snk_data          = gen_data.pop_back();
              snk_valid         = 1'b1;
              snk_startofpacket = 1'b0;
            end

          ##1;
          snk_data          = gen_data.pop_back();
          snk_valid         = 1'b1;
          snk_endofpacket   = 1'b1;
          ##1;
          snk_data          = '0;
          snk_valid         = 1'b0;
          snk_endofpacket   = 1'b0;

        end

  endtask

  task read_data( mailbox #( data_t) output_data );
    
    data_t data;
    int    timeout_counter;

    while ( timeout_counter != TIMEOUT + 1)
      begin
        @( posedge clk );
        data = {};

        if ( snk_startofpacket === 1'b1 )
          begin
            do 
              data.push_back( snk_data );
            while ( snk_endofpacket !== 1'b1 );

            timeout_counter = 0;
          end
        else 
          timeout_counter += 1;
      end
  endtask

  initial begin
    test_succeed = 1'b1;
    src_ready_i  = 1'b1;

    $display("Simulation started!");
    generate_data( generated_data );
    wait( srst_done === 1'b1 );

    fork
      send_data( generated_data, input_data );
    join
  end

endmodule 