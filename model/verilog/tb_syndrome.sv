
module tb_syndrome;
   logic [15:0] cells;
   logic [3:0]  s;
   logic        odd;
   int errors = 0;


   syndrome dut (.cells(cells), .s(s), .odd(odd));

   localparam logic [15:0] GOOD = 16'h695A;

   initial begin
      $dumpfile("tb_syndrome_wave.vcd");
      $dumpvars(0, tb_syndrome);

      cells = GOOD;
      #1;
      // 1. no error: check s == 0 and odd == 0
      if (s !== 4'd0 || odd !== 1'b0) begin
         $error("clean word: s=%b odd%b", s, odd);
         errors++;
      end

      // 2. for each i in 0..15: flip cell [i], wait, check s == i and odd == 1
      for (int i = 0; i < 16; i++) begin
         cells = GOOD ^ (16'b1 << i);
         #1;
         if (s !== 4'(i) || odd !== 1'b1) begin
            $error("cell %0d: s=%b odd=%b", i, s, odd);
            errors++;
         end
      end

      if (errors == 0) $display("all tests passed");
      else $display("there were %0d errors", errors);

      $finish;
   end
endmodule // tb_syndrome
