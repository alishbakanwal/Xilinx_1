*** fuji.v	Tue Mar 13 17:13:41 2012
--- fuji.v.old	Tue Mar 13 17:13:07 2012
***************
*** 290,305 ****
     input I;
  endmodule
  
- ///// component BIBUF ////
- (* BOX_TYPE="PRIMITIVE" *) // Verilog-2001
- module BIBUF (
-   IO,
-   PAD
- );
-    inout IO;
-    inout PAD;
- endmodule
- 
  ///// component BSCANE2 ////
  (* BOX_TYPE="PRIMITIVE" *) // Verilog-2001
  module BSCANE2 (
--- 290,295 ----

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
