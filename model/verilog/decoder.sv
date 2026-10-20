module decoder(
               input logic [15:0]  cells,
               output logic [10:0] data,
               output logic        double_err
               );

   logic [3:0]                     s;
   logic                           odd;
   /* verilator lint_off UNUSEDSIGNAL */
   logic [15:0]                    mask, corrected; // parity cells and cell 0 are corrected but not needed
   /* verilator lint_on UNUSEDSIGNAL */

   syndrome syn (.cells(cells), .s(s), .odd(odd));

   assign mask = odd ? (16'b1 << s) : 16'b0;
   assign corrected = cells ^ mask;
   assign double_err = ~odd && (s != 4'd0);
   assign data = {corrected[15:9], corrected[7:5], corrected[3]};
endmodule // decoder
