module GATE_2_1(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h1;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_1_NOR(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h1;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_2(O, I1, I0);
output O;
input I1, I0;
defparam i.INIT=4'h2;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_4(O, I1, I0);
output O;
input I1, I0;
defparam i.INIT=4'h4;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_6(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h6;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_6_XOR(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h6;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_7(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h7;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_7_NAND(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h7;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_8(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h8;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_8_AND(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'h8;
LUT2 i (.I0(I0), .I1(I1), .O(O));

endmodule

module GATE_2_9(O, I1, I0);
output O;
input I1, I0;
wire n1;

defparam i.INIT=4'h9;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_9_XNOR(O, I1, I0);
output O;
input I1, I0;
wire n1;

defparam i.INIT=4'h9;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_11(O, I1, I0);
output O;
input I1, I0;
defparam i.INIT=4'hB;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_13(O, I1, I0);
output O;
input I1, I0;
defparam i.INIT=4'hD;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module MUX1(Z, A, B, S);
output Z;
input A, B, S;
wire sbar, n0, n1;

defparam i_0.INIT=8'hE4;
LUT3 i_0 (.I0(S), .I1(B), .I2(A), .O(Z));
endmodule

module GATE_2_14(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'hE;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module GATE_2_14_OR(O, I1, I0);
output O;
input I1, I0;

defparam i.INIT=4'hE;
LUT2 i (.I0(I0), .I1(I1), .O(O));
endmodule

module MAPBUF(O, I);
output O;
input I;
BUF i(.I(I), .O(O));
endmodule

module tricell(a, en, z);
input a, en;
output z;
BUFE i(.O(z), .E(en), .I(a));
endmodule

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
