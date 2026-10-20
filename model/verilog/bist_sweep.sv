// Test sequencer: steps through every (data, t) combination, one per clock.
//   t = 0        : no error
//   t = 1..16    : single flip of cell t-1
//   t = 17..272  : p = t-17, i = p[7:4], j = p[3:0]; real double error only if i < j
module bist_sweep (
                   input logic clk,
                   input logic rst,
                   output logic [10:0] data,
                   output logic [15:0] err,
                   output logic valid,      // 0 = skip this cycle (i >= j pair)
                   output logic is_pair,    // 1 = this test is a pair (expects double_err)
                   output logic done
                   );

   logic [8:0]                  t; // test index 0..272
   logic [7:0]                  p;
   assign p = 8'(t - 9'd17);

   always_ff @(posedge clk) begin
      if (rst) begin
         done <= 1'b0;
         t <= 9'd0;
         data <= 11'd0;
      end else if (!done) begin
         if (t == 9'd272) begin
            t <= 9'd0;
            if (data == 11'd2047) done <= 1'b1;
            else data <= data + 11'd1;
         end else
           t <= t + 9'd1;
      end
   end

   always_comb begin
      err = 16'b0;
      valid = 1'b1;
      is_pair = 1'b0;
      if (t == 9'd0) begin
         err = 16'b0;
      end else if (t <= 9'd16) begin
         err = 16'b1 << 4'(t - 9'd1);
      end else begin
         is_pair = 1'b1;
         valid = (p[7:4] < p[3:0]);
         err = (16'b1 << p[7:4]) | (16'b1 << p[3:0]);
      end
   end
endmodule
