*** fuji.v	Mon Sep 24 16:24:47 2012
--- fuji.v.old	Sat Sep 22 19:28:04 2012
***************
*** 27628,27635 ****
     parameter real MEMREFCLK_PERIOD = 0.000;
     parameter real PHASEREFCLK_PERIOD = 0.000;
     parameter real REFCLK_PERIOD = 0.000;
-    parameter DQS_AUTO_RECAL = 1'b1;
-    parameter DQS_FIND_PATTERN = 3'b01;
     output DQSFOUND;
     output DQSOUTOFRANGE;
     output FINEOVERFLOW;
--- 27628,27633 ----

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
