// Testbench for bist_sweep.
// Checks every cycle of the full sweep against an independent model of what
// (data, err, valid, is_pair) should be, then checks the end state and reset behaviour.

module tb_bist_sweep;
   localparam int TESTS_PER_DATA = 273;                      // t = 0..272
   localparam int N_DATA         = 2048;
   localparam int TOTAL          = N_DATA * TESTS_PER_DATA;  // clocks in a full sweep
   localparam int VALID_PER_DATA = 1 + 16 + 120;             // none + singles + pairs

   logic        clk;
   logic        rst;
   logic [10:0] data;
   logic [15:0] err;
   logic        valid, is_pair, done;

   int errors;
   int valid_count;

   bist_sweep dut (.clk(clk), .rst(rst), .data(data), .err(err), .valid(valid),
                   .is_pair(is_pair), .done(done));

   always #5 clk = ~clk;

   // ---------- reference model (written differently from the DUT) ----------
   function automatic logic [15:0] exp_err(int tt);
      int p, i, j;
      if (tt == 0) begin
         return 16'b0;
      end else if (tt <= 16) begin
         return 16'b1 << (tt - 1);
      end else begin
         p = tt - 17;
         i = p / 16;
         j = p % 16;
         return (16'b1 << i) | (16'b1 << j);
      end
   endfunction

   function automatic logic exp_valid(int tt);
      int p;
      if (tt <= 16) return 1'b1;
      p = tt - 17;
      return ((p / 16) < (p % 16));
   endfunction

   function automatic logic exp_is_pair(int tt);
      return (tt >= 17);
   endfunction

   // ---------- helpers ----------
   task automatic report(string what, int k);
      errors++;
      if (errors <= 10)
        $display("FAIL: %s at k=%0d (data=%0d t_exp=%0d): err=%h valid=%b is_pair=%b done=%b",
                 what, k, data, k % TESTS_PER_DATA, err, valid, is_pair, done);
   endtask

   // Call at a negedge. Applies reset across one posedge, releases at the next negedge.
   task automatic do_reset;
      rst = 1'b1;
      @(negedge clk);
      rst = 1'b0;
   endtask

   // ---------- test ----------
   initial begin
      clk = 1'b0;
      rst = 1'b1;
      errors = 0;
      valid_count = 0;

      do_reset;   // initial reset

      // Run part-way (data != 0, t != 0), then reset mid-run.
      // The main loop below starts at k = 0, so it also proves the reset worked.
      repeat (TESTS_PER_DATA * 5 + 40) @(negedge clk);
      do_reset;

      // Full sweep: check every cycle.
      for (int k = 0; k < TOTAL; k++) begin
         #1;   // let combinational outputs settle after the negedge
         if (data !== 11'(k / TESTS_PER_DATA))        report("data", k);
         if (err !== exp_err(k % TESTS_PER_DATA))     report("err", k);
         if (valid !== exp_valid(k % TESTS_PER_DATA)) report("valid", k);
         if (is_pair !== exp_is_pair(k % TESTS_PER_DATA)) report("is_pair", k);
         if (done !== 1'b0)                           report("done early", k);
         if (valid === 1'b1) valid_count++;
         @(negedge clk);
      end

      // End state: done set, counters frozen with t back at 0.
      #1;
      if (done !== 1'b1)  report("done not set", TOTAL);
      repeat (20) @(negedge clk);
      #1;
      if (done !== 1'b1)                              report("done dropped", TOTAL);
      if (data !== 11'(N_DATA - 1))                   report("data not frozen at 2047", TOTAL);
      if (err !== exp_err(0))                         report("err not frozen", TOTAL);
      if (valid !== exp_valid(0))                     report("valid not frozen", TOTAL);
      if (is_pair !== exp_is_pair(0))                 report("is_pair not frozen", TOTAL);

      if (valid_count != N_DATA * VALID_PER_DATA) begin
         errors++;
         $display("FAIL: valid_count=%0d expected %0d", valid_count, N_DATA * VALID_PER_DATA);
      end

      // Reset after done must restart the sweep.
      @(negedge clk);
      do_reset;
      #1;
      if (done !== 1'b0 || data !== 11'd0 || err !== 16'd0 || valid !== 1'b1)
        report("reset after done", TOTAL);

      if (errors == 0) $display("all tests passed (%0d cycles, %0d valid)", TOTAL, valid_count);
      else             $display("FAIL: %0d errors", errors);
      $finish;
   end
endmodule
