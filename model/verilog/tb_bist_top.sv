// Testbench for bist_top: two copies share a clock and reset.
//   dut_ok  : injection off -> must finish with PASS
//   dut_bad : injection on  -> must FAIL (proves the BIST can fail)
// LED order: led[0]=done, led[1]=pass, led[2]=fail, led[3]=heartbeat

module tb_bist_top;
   localparam int TOTAL = 2048 * 273;   // clocks in a full sweep

   logic clk;
   logic btn_rst;
   /* verilator lint_off UNUSEDSIGNAL */
   logic [3:0] led_ok, led_bad;         // led[3] (heartbeat) is too slow to check in simulation
   /* verilator lint_on UNUSEDSIGNAL */
   int errors;

   bist_top dut_ok  (.clk(clk), .btn_rst(btn_rst), .sw_inject(1'b0), .led(led_ok));
   bist_top dut_bad (.clk(clk), .btn_rst(btn_rst), .sw_inject(1'b1), .led(led_bad));

   always #4 clk = ~clk;   // 8 time units per clock, like 125 MHz

   task automatic chk(string what, logic got, logic exp);
      if (got !== exp) begin
         errors++;
         $display("FAIL: %s (got %b, expected %b)", what, got, exp);
      end
   endtask

   initial begin
      clk = 1'b0;
      btn_rst = 1'b1;
      errors = 0;

      repeat (5) @(negedge clk);
      btn_rst = 1'b0;                       // release; sweep starts about 2 clocks later

      // Early on: the injected copy must already have failed, the clean copy must not have.
      repeat (20) @(negedge clk);
      chk("bad: fail LED asserts quickly", led_bad[2], 1'b1);
      chk("ok: fail LED stays off",        led_ok[2],  1'b0);
      chk("ok: not done yet",              led_ok[0],  1'b0);
      chk("ok: pass not early",            led_ok[1],  1'b0);

      // Just before the end of the sweep: still running, no pass yet.
      repeat (TOTAL - 30) @(negedge clk);
      chk("ok: not done before the sweep ends", led_ok[0], 1'b0);
      chk("ok: no pass before the sweep ends",  led_ok[1], 1'b0);
      chk("ok: no fail during the sweep",       led_ok[2], 1'b0);

      // After the end: ok copy passes, injected copy fails.
      repeat (60) @(negedge clk);
      chk("ok: done",       led_ok[0],  1'b1);
      chk("ok: pass",       led_ok[1],  1'b1);
      chk("ok: no fail",    led_ok[2],  1'b0);
      chk("bad: done",      led_bad[0], 1'b1);
      chk("bad: no pass",   led_bad[1], 1'b0);
      chk("bad: fail",      led_bad[2], 1'b1);

      // Reset clears the result flags.
      btn_rst = 1'b1;
      repeat (6) @(negedge clk);
      chk("reset: ok done cleared",   led_ok[0],  1'b0);
      chk("reset: ok pass cleared",   led_ok[1],  1'b0);
      chk("reset: bad fail cleared",  led_bad[2], 1'b0);

      if (errors == 0) $display("all tests passed");
      else             $display("FAIL: %0d errors", errors);
      $finish;
   end
endmodule
