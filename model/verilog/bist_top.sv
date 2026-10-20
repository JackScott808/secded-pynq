// Built-in self-test top level for the PYNQ-Z2.
//
//   bist_sweep -> data, err        (what to test)
//   encoder    -> sent             (valid codeword)
//   sent ^ err -> received         (inject the error pattern)
//   decoder    -> dec_data, double_err
//   checker    -> fail_now         (compare against what the code guarantees)
//
// LEDs:  led[0] = done      led[1] = pass      led[2] = fail (sticky)     led[3] = heartbeat
// BTN0 restarts the sweep. SW0 flips one output bit to prove the BIST can fail.
module bist_top (
                 input  logic       clk,        // 125 MHz
                 input  logic       btn_rst,    // BTN0, active high
                 input  logic       sw_inject,  // SW0: 1 = deliberately corrupt data_out
                 output logic [3:0] led
                 );

   // ---------- synchronise the asynchronous inputs (2 flip-flops each) ----------
   logic [1:0] rst_sync, inj_sync;
   always_ff @(posedge clk) begin
      rst_sync <= {rst_sync[0], btn_rst};
      inj_sync <= {inj_sync[0], sw_inject};
   end

   logic rst, inject;
   assign rst    = rst_sync[1];
   assign inject = inj_sync[1];

   // ---------- test generation and the code under test ----------
   logic [10:0] data, dec_data, data_out, exp_data;
   logic [15:0] err, sent, received;
   logic        valid, is_pair, done, double_err, fail_now;

   bist_sweep sweep (.clk(clk), .rst(rst), .data(data), .err(err),
                     .valid(valid), .is_pair(is_pair), .done(done));

   encoder enc (.data(data), .cells(sent));

   assign received = sent ^ err;

   decoder dec (.cells(received), .data(dec_data), .double_err(double_err));

   // fault injection: flip bit 0 of the decoder's data output
   assign data_out = dec_data ^ {10'b0, inject};

   // ---------- checker ----------
   // Singles and no-error: data corrected, no double-error flag.
   // Pairs: double-error flag set, data passed through uncorrected (the received data cells).
   assign exp_data = is_pair ? {received[15:9], received[7:5], received[3]} : data;
   assign fail_now = valid && ((double_err != is_pair) || (data_out != exp_data));

   // ---------- result registers ----------
   // fail_q is one cycle behind the test; failed is one more. done_q is delayed by
   // one cycle so that when it rises, `failed` already includes the last test.
   logic        fail_q, done_q, failed;
   logic [26:0] hb;

   always_ff @(posedge clk) begin
      if (rst) begin
         fail_q <= 1'b0;
         done_q <= 1'b0;
         failed <= 1'b0;
         hb     <= 27'd0;
      end else begin
         fail_q <= fail_now;
         done_q <= done;
         failed <= failed | fail_q;
         hb     <= hb + 27'd1;
      end
   end

   //             led[3]  led[2]  led[1]            led[0]
   assign led = {hb[26], failed, done_q & ~failed, done_q};
endmodule
