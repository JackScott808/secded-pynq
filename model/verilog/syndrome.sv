module syndrome(
                input logic [15:0] cells,
                output logic [3:0] s,
                output logic odd
                );

   // localparams for the 4 masks, four assigns
   localparam logic [15:0]   MASK_Q1 = 16'hAAAA;
   localparam logic [15:0]   MASK_Q2 = 16'hCCCC;
   localparam logic [15:0]   MASK_Q3 = 16'hF0F0;
   localparam logic [15:0]   MASK_Q4 = 16'hFF00;

   assign s[0] = ^(cells & MASK_Q1);
   assign s[1] = ^(cells & MASK_Q2);
   assign s[2] = ^(cells & MASK_Q3);
   assign s[3] = ^(cells & MASK_Q4);
   assign odd = ^cells;

endmodule // syndrome
