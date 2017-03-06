module CARRY2_INTERNAL(CO, O, CI, PROP, OI, COI, GEN);
output [1:0] CO;
output [1:0] O;
input CI, COI, GEN;
input [1:0] PROP;
input [1:0] OI;
assign O = OI;
assign CO[0] = COI;
assign CO[1] = PROP[1] ? COI : GEN;
endmodule

module CARRY2_INTERNAL_INIT(CO, O, CI, PROP, OI, COI, GEN);
output [1:0] CO;
output [1:0] O;
input CI, COI, GEN;
input [1:0] PROP;
input [1:0] OI;
assign O = OI;
assign CO[0] = COI;
assign CO[1] = GEN;
endmodule

module MAPBUF_1_3(G, P, S, I);
output G, P, S;
input I;
assign G = I;
assign P = I;
assign S = I;
endmodule

module MAPBUF_3_1(O, G, P, S);
output O;
input G, P, S;
assign O = G & P & S;
endmodule

module GATE_2_1(O, I1, I0);
output O;
input I1, I0;
assign O = !I1 & !I0;
endmodule

module GATE_2_1_NOR(O, I1, I0);
output O;
input I1, I0;
assign O = !I1 & !I0;
endmodule

module GATE_2_2(O, I1, I0);
output O;
input I1, I0;
assign O = !I1 & I0;
endmodule

module GATE_2_4(O, I1, I0);
output O;
input I1, I0;
assign O = I1 & !I0;
endmodule

module GATE_2_6(O, I1, I0);
output O;
input I1, I0;
assign O = I1 ^ I0;
endmodule

module GATE_2_6_XOR(O, I1, I0);
output O;
input I1, I0;
assign O = I1 ^ I0;
endmodule

module GATE_2_7(O, I1, I0);
output O;
input I1, I0;
assign O = !I1 | !I0;
endmodule

module GATE_2_7_NAND(O, I1, I0);
output O;
input I1, I0;
assign O = !I1 | !I0;
endmodule

module GATE_2_8(O, I1, I0);
output O;
input I1, I0;
assign O = I1 & I0;
endmodule

module GATE_2_8_AND(O, I1, I0);
output O;
input I1, I0;
assign O = I1 & I0;
endmodule

module GATE_2_9(O, I1, I0);
output O;
input I1, I0;
assign O = !(I1 ^ I0);
endmodule

module GATE_2_9_XNOR(O, I1, I0);
output O;
input I1, I0;
assign O = !(I1 ^ I0);
endmodule

module GATE_2_11(O, I1, I0);
output O;
input I1, I0;
assign O = !I1 | I0;
endmodule

module GATE_2_13(O, I1, I0);
output O;
input I1, I0;
assign O = I1 | !I0;
endmodule

module MUX1(Z, A, B, S);
output Z;
input A, B, S;
assign Z = !S & B | S & A;
endmodule

module GATE_2_14(O, I1, I0);
output O;
input I1, I0;
assign O = I1 | I0;
endmodule

module GATE_2_14_OR(O, I1, I0);
output O;
input I1, I0;
assign O = I1 | I0;
endmodule

module MAPBUF(O, I);
output O;
input I;
assign O = I;
endmodule

module tricell(a, en, z);
input a, en;
output z;

assign z = en ? a : 1'bz;

endmodule

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
