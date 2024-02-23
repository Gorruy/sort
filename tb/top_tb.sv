`timescale 1 ps / 1 ps

module top_tb;

  parameter NUMBER_OF_TEST_RUNS = 5;
  parameter MAX_PKT_LEN         = 25;
  parameter TIMEOUT             = MAX_PKT_LEN**2 * 4 + 1;
  parameter DWIDTH              = 32;

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

 sorting #(
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
    
      data = {};
      len  = 1;
      data.push_back( $urandom_range( 20, 0 ) );
      generated_data.put(data);
      
      data = {};
      len  = MAX_PKT_LEN;
      for ( int i = 0; i < len; i++ )
        begin
          data.push_back( $urandom_range( 20, 0 ) );
        end

      generated_data.put(data);

      data = {};
      len  = MAX_PKT_LEN;
      for ( int i = 0; i < len; i++ )
        begin
          data.push_back( $urandom_range( 2**DWIDTH - 1, 2**DWIDTH - 1 ) );
        end

      generated_data.put(data);

  endtask

  task send_data( mailbox #( data_t ) generated_data,
                  mailbox #( data_t ) input_data 
                );
    
      data_t exposed_data, gen_data;

      while ( generated_data.num() )
        begin
          ##1;
          exposed_data = {};
          if ( snk_ready_o !== 1'b1 )
            begin
              continue;
            end

          generated_data.get( gen_data );

          snk_data          = gen_data.pop_back();
          snk_valid         = 1'b1;
          snk_startofpacket = 1'b1;
          snk_endofpacket   = gen_data.size() != 0 ? 1'b0 : 1'b1;

          exposed_data.push_back(snk_data);
          ##1;
          snk_startofpacket = 1'b0;

          while ( gen_data.size() > 1 )
            begin
              while ( !snk_ready_o )
                begin
                  ##1;
                end
              snk_data          = gen_data.pop_back();
              snk_valid         = 1'b1;

              exposed_data.push_back(snk_data);
              ##1;
            end

          if ( gen_data.size() == 0 )
            begin
              input_data.put(exposed_data);
              snk_valid         = 1'b0;
              snk_endofpacket   = 1'b0;
              continue;
            end

          snk_data          = gen_data.pop_back();
          snk_valid         = 1'b1;
          snk_endofpacket   = 1'b1;
          ##1;
          snk_valid         = 1'b0;
          snk_endofpacket   = 1'b0;

          exposed_data.push_back(snk_data);
          input_data.put(exposed_data);
        end

  endtask

  task read_data( mailbox #( data_t) output_data,
                  input int          with_ready_delay );
    
    data_t data;
    int    timeout_counter;
    int    src_ready_delay;

    while ( timeout_counter != TIMEOUT + 1)
      begin
        data = {};
        ##1;

        if ( src_startofpacket === 1'b1 && src_endofpacket !== 1'b1 )
          begin
            do begin
              ##1;
              if ( with_ready_delay )
                begin
                  src_ready_delay = $urandom_range(10, 1);
                  src_ready_i = 1'b0;
                  ##(src_ready_delay);
                  src_ready_i = 1'b1;
                end
              else 
                src_ready_i = 1'b1;

              if ( src_valid )
                begin
                  data.push_back(src_data);
                end
            end while ( src_endofpacket !== 1'b1 );

            if ( with_ready_delay )
              begin
                src_ready_delay = $urandom_range(10, 1);
                src_ready_i = 1'b0;
                ##(src_ready_delay);
                src_ready_i = 1'b1;
              end
            ##1;
            
            output_data.put(data);
            timeout_counter = 0;
          end
        else if ( src_startofpacket === 1'b1 && src_endofpacket === 1'b1 )
          begin
            data = {};
            timeout_counter = 0;
            src_ready_i = 1'b1;
            if ( src_valid )
              begin
                data.push_back(src_data);
                output_data.put(data);
              end
            ##1;
          end
        else 
          begin
            timeout_counter += 1;
          end

        src_ready_i = 1'b0;
      end

  endtask

  task compare_data( mailbox #( data_t) input_data,
                     mailbox #( data_t) output_data 
                   );

    data_t i_data;
    data_t o_data;
    while ( input_data.num() )
      begin
        input_data.get( i_data );
        output_data.get( o_data );

        if ( i_data.size() != o_data.size() )
          begin
            test_succeed = 1'b0;
            $display( "Transmition failed! read size:%d, write size:%d", o_data.size(), i_data.size() );
            return;
          end

        i_data.sort();
        if ( i_data !== o_data )
          begin
            test_succeed = 1'b0;
            $display( "Sorting failed! input:%p, output:%p", i_data, o_data );
            return;
          end
      end

  endtask


  initial begin
    test_succeed = 1'b1;
    src_ready_i  = 1'b0;

    $display("Simulation started!");
    generate_data( generated_data );
    wait( srst_done === 1'b1 );

    fork
      send_data( generated_data, input_data );
      read_data( output_data, 0 );
    join

    compare_data( input_data, output_data ); 

    if ( test_succeed )
      $display( "All tests passed!" );
    $stop();
  end

endmodule 