// Output port muxing, and Input port demuxing IP's for
//   VSS Partitioning flow. 

// Module names are deliberately long below, so that they don't clash 
//  with exisiting IP's or user modules. "vss_partition_flow_" needs 
//  to be thought of as a namespace or library name.

module vss_partition_flow_out_ports_mux(
  input fastclk, 
  reset, 
  A, B, C, D, 
  output reg out);
  
  reg [1:0] counter;
  always @(posedge fastclk) begin
    if (reset) 
      counter <= 4'b0000;
    else 
      counter <= counter + 1;
  end

  always @(*) begin
    case(counter) 
      4'd1: out = B;
      4'd2: out = C;
      4'd3: out = D;
      default: out = A;
    endcase
  end
endmodule

module vss_partitions_flow_in_ports_demux(
  input fastclk, 
  reset, 
  input in, 
  output reg A, B, C, D);
  
  reg [1:0] counter;
  
  always @(posedge fastclk) begin
    if (reset) 
      counter <= 4'b0;
    else
      counter <= counter + 1'b1;
    
    case(counter) 
      4'd1: A <= in;
      4'd2: B <= in;
      4'd3: C <= in;
      default: D <= in;
    endcase
  end

endmodule

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
