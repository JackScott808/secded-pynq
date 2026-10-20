// parity cell 1 is the XOR of data cells: [3, 5, 7, 9, 11, 13, 15]
// parity cell 2 is the XOR of data cells: [3, 6, 7, 10, 11, 14, 15]
// parity cell 4 is the XOR of data cells: [5, 6, 7, 12, 13, 14, 15]
// parity cell 8 is the XOR of data cells: [9, 10, 11, 12, 13, 14, 15]
// parity cell 0 is the XOR of all 15 other cells
// DATA_POSITIONS = [3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
//                  [0, 1, 2, 3, 4,  5,  6,  7,  8,  9, 10]

module encoder(
               input logic [10:0] data,
               output logic [15:0] cells
               );

   logic                           p1, p2, p4, p8, p0;

   assign p1 = data[0] ^ data[1] ^ data[3] ^ data[4] ^ data[6] ^ data[8] ^ data[10];
   assign p2 = data[0] ^ data[2] ^ data[3] ^ data[5] ^ data[6] ^ data[9] ^ data[10];
   assign p4 = data[1] ^ data[2] ^ data[3] ^ data[7] ^ data[8] ^ data[9] ^ data[10];
   assign p8 = data[4] ^ data[5] ^ data[6] ^ data[7] ^ data[8] ^ data[9] ^ data[10];
   assign p0 = (^data) ^ p1 ^ p2 ^ p4 ^ p8;

   assign cells = {data[10:4], p8, data[3:1], p4, data[0], p2, p1, p0};

endmodule // encoder
