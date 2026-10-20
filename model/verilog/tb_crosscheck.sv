// Cross-check: replay vectors.txt (written by gen_vectors.py) against the hardware.
// Each line: data err sent exp_data exp_double   (all hex)

module tb_crosscheck;
   localparam int N_EXPECTED = 5000;   // must match N_VECTORS in gen_vectors.py

   logic [10:0] data_in, data_out, exp_data;
   logic [15:0] sent, received, err, exp_sent;
   logic        double_err, exp_double;
   int          errors = 0;
   int          fd, n, count = 0;

   encoder enc (.data(data_in), .cells(sent));
   assign received = sent ^ err;
   decoder dec (.cells(received), .data(data_out), .double_err(double_err));

   initial begin
      fd = $fopen("./vectors.txt", "r");
      if (fd == 0) begin
         $display("FAIL: could not open vectors.txt (run from the folder that contains it)");
         $finish;
      end

      // $fscanf returns the number of fields matched; 5 means a full line was read
      n = $fscanf(fd, "%h %h %h %h %h", data_in, err, exp_sent, exp_data, exp_double);
      while (n == 5) begin
         #1;   // let the combinational logic settle
         count++;

         // encoder output vs Python's encode()
         if (sent !== exp_sent) begin
            $display("FAIL (encoder) line %0d: data=%h sent=%h expected=%h",
                     count, data_in, sent, exp_sent);
            errors++;
         end

         // decoder outputs vs Python's decode()
         if (data_out !== exp_data || double_err !== exp_double) begin
            $display("FAIL (decoder) line %0d: err=%h data_out=%h exp=%h double_err=%b exp=%b",
                     count, err, data_out, exp_data, double_err, exp_double);
            errors++;
         end

         n = $fscanf(fd, "%h %h %h %h %h", data_in, err, exp_sent, exp_data, exp_double);
      end
      $fclose(fd);

      if (count != N_EXPECTED) begin
         $display("FAIL: read %0d vectors, expected %0d", count, N_EXPECTED);
         errors++;
      end

      if (errors == 0) $display("all %0d vectors passed", count);
      else             $display("FAIL: %0d errors in %0d vectors", errors, count);
      $finish;
   end
endmodule
