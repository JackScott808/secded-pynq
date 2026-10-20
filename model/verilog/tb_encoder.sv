module tb_encoder;
   logic [10:0] data;
   logic [15:0] cells;
   logic [3:0]  s;
   logic        odd;
   int          errors = 0;

   encoder enc (.data(data), .cells(cells));
   syndrome syn (.cells(cells), .s(s), .odd(odd));

   initial begin
      for (int d = 0; d < 2048; d++) begin // 2^11 = 2048
         data = 11'(d);
         #1;
         if (s !== 4'd0 || odd !== 1'b0) begin
            // report d, cells, s, odd and the count error
            $display("failed for d: %0d, s=%b, odd=%b", d, s, odd);
            errors++;
         end
         if ({cells[15:9], cells[7:5], cells[3]} !== {data[10:4], data[3:1], data[0]}) begin
            $display("data not placed correctly for d=%0d", d);
            errors++;
         end
      end
      // print the result using %0d for the count
      if (errors == 0)
        $display("all tests passed");
      else
        $display("FAIL: there were %0d errors", errors);
      $finish;
   end // initial begin
endmodule // tb_encoder
