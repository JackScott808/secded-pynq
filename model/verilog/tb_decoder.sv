module tb_decoder;
   logic [10:0] data_in, data_out;
   logic [15:0] sent, received;
   logic [15:0] err;          // which cells to flip
   logic        double_err;
   int          errors = 0;

   encoder enc (.data(data_in), .cells(sent));
   assign received = sent ^ err;
   decoder dec (.cells(received), .data(data_out), .double_err(double_err));

   initial begin
      // test 1: no error, all 2048 data values
      err = 16'b0;
      for (int d = 0; d < 2048; d++) begin
         data_in = 11'(d);
         #1;
         // check data_out === data_in and double_err === 1'b0
         if (data_out !== data_in || double_err !== 1'b0) begin
            $display("FAIL at d=%0d", d);
            errors++;
         end
      end

      // test 2: every single flip of every data value
      for (int d = 0; d < 2048; d++) begin
         for (int i = 0; i < 16; i++) begin
            data_in = 11'(d);
            err = 16'b1 << i;
            #1;
            // same check
            if (data_out !== data_in || double_err !== 1'b0) begin
               $display("FAIL at d=%0d, i=%0d", d, i);
               errors++;
            end
         end
      end // for (int d = 0; d < 2048; d++)

      // test 3: every pair of flips, every data value
      for (int d = 0; d < 2048; d++) begin
         for (int i = 0; i < 16; i++) begin
            for (int j = i + 1; j < 16; j++) begin
               data_in = 11'(d);
               err = (16'b1 << i) | (16'b1 << j);
               #1;
               // check double_err === 1'b1 and the data output you chose
               if (double_err !== 1 || data_out !== {received[15:9], received[7:5], received[3]}) begin
                  $display("FAIL: at d=%0d, cell [i, j] = [%0d, %0d]", d, i, j);
                  errors++;
               end
            end
         end
      end
      // report
      if (errors == 0) $display("all tests passed");
      else $display("FAIL: %0d errors", errors);
      $finish;
   end
endmodule
