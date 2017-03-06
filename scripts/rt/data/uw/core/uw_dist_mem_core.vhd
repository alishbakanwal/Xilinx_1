<<<<<<< HEAD
version https://git-lfs.github.com/spec/v1
oid sha256:cb3771a7d0efc9becf829b847fd9cbe815488a4dc225ab9cede8f724163f1668
size 14054
=======
-------------------------------------------------------------------------------
-- $RCSfile: dist_mem_gen.vhd,v $
-- $Revision: 1.3 $
-- $Date: 2011/02/28 09:49:42 $
-- Title      : RTL Top level with generics
-- Project    : Distributed Memory Generator
-------------------------------------------------------------------------------
-- (c) Copyright 2006 - 2009 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- File       : dist_mem_gen.vhd
-- Author     : Xilinx, Inc.
-------------------------------------------------------------------------------
-- Description: This is the top level structure for the RTL Distributed Memory
-- core, including exposure of any generics that are implemented. These
-- generics are then wrapped in a structural wrapper.
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY uw_dist_mem_core IS
   GENERIC (
      UW_MEM_TYPE            : STRING  := "ROM";          -- ROM, SPRAM, DPRAM, SDPRAM; Default: ROM
      UW_ADDR_WIDTH          : INTEGER := 6;              -- Range: 4 - 16; Default: 6
      UW_DATA_WIDTH          : INTEGER := 16;             -- Range: 1 - 1024; Default: 16
      UW_MEM_DEPTH           : INTEGER := 64;             -- Range: 16 - 64K with multiples of 16; Default: 64
      UW_OUTPUT_OPTION       : STRING  := "Unregistered"; -- Registered, Unregistered; Default: Registered
      UW_RESET_TYPE          : STRING  := "Sync";         -- Sync, Async; Default: Sync
      UW_DEFAULT_DATA        : STRING  := "0";
      UW_MEM_INIT_FILE       : STRING  := "null.mif";
      UW_ELABORATION_DIR     : STRING  := "./";

      family_name      : STRING  := "virtex7"
      );

   PORT (
      -- Global Signal
      RESET                 : IN STD_LOGIC := '0';

      -- Write Port Signals (Not valid for ROM)
      WR_CLK                : IN  STD_LOGIC := '0';
      WR_EN                 : IN  STD_LOGIC := '0';
      -- Write Address for SPRAM, DPRAM and SDPRAM
      -- Read Address for ROM SPRAM
      ADDR                  : IN  STD_LOGIC_VECTOR(UW_ADDR_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
      WR_DATA               : IN  STD_LOGIC_VECTOR(UW_DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');

      -- Read Port Signals
      RD_CLK                : IN  STD_LOGIC := '0'; -- Available only for DPRAM/ADPRAM
      OUTPUT_REG_EN         : IN  STD_LOGIC := '0';
      DP_RD_ADDR            : IN  STD_LOGIC_VECTOR(UW_ADDR_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
      SP_RD_DATA            : OUT STD_LOGIC_VECTOR(UW_DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
      DP_RD_DATA            : OUT STD_LOGIC_VECTOR(UW_DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0')
      );

END uw_dist_mem_core;

-------------------------------------------------------------------------------

ARCHITECTURE rtl OF uw_dist_mem_core IS

   ------------------------------------------------------------------------------
   -- This function is used to implement an IF..THEN when such a statement is not
   -- allowed. 
   ------------------------------------------------------------------------------
    FUNCTION if_then_else (
      condition : boolean; 
      true_case : integer; 
      false_case : integer) 
    RETURN integer IS
      VARIABLE retval : integer := 0;
    BEGIN
      IF NOT condition THEN
        retval:=false_case;
      ELSE
        retval:=true_case;
      END IF;
      RETURN retval;
    END if_then_else;

   CONSTANT C_MEM_TYPE   : INTEGER := if_then_else((UW_MEM_TYPE = "ROM"), 0,
                                      if_then_else((UW_MEM_TYPE = "SPRAM"), 1,
                                      if_then_else((UW_MEM_TYPE = "DPRAM"), 2,
                                      if_then_else((UW_MEM_TYPE = "SDPRAM"), 4, 0))));
   CONSTANT C_RST_TYPE   : INTEGER := if_then_else((UW_RESET_TYPE = "Sync"), 0, 1);
   CONSTANT C_REG_OUT    : INTEGER := if_then_else((UW_OUTPUT_OPTION = "Registered"), 1, 0);
   CONSTANT C_NO_REG_OUT : INTEGER := if_then_else((UW_OUTPUT_OPTION = "Unregistered"), 1, 0);

   CONSTANT C_HAS_SPO    : INTEGER := if_then_else((C_MEM_TYPE < 3 AND C_NO_REG_OUT = 1), 1, 0);
   CONSTANT C_HAS_QSPO   : INTEGER := if_then_else((C_MEM_TYPE < 3 AND C_REG_OUT = 1), 1, 0);
   CONSTANT C_HAS_DPO    : INTEGER := if_then_else((C_MEM_TYPE > 1 AND C_NO_REG_OUT = 1), 1, 0);
   CONSTANT C_HAS_QDPO   : INTEGER := if_then_else((C_MEM_TYPE > 1 AND C_REG_OUT = 1), 1, 0);

   CONSTANT c_rom        : INTEGER := 0;
   CONSTANT c_sp_ram     : INTEGER := 1;
   CONSTANT c_dp_ram     : INTEGER := 2;
   CONSTANT c_sdp_ram    : INTEGER := 4;

   CONSTANT GND          : STD_LOGIC := '0';
   CONSTANT ADDR_ZEROS   : STD_LOGIC_VECTOR(UW_ADDR_WIDTH-1 DOWNTO 0) := (OTHERS => '0');


   SIGNAL wr_en_int : STD_LOGIC := '0';
   SIGNAL spo       : STD_LOGIC_VECTOR(UW_DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
   SIGNAL dpo       : STD_LOGIC_VECTOR(UW_DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
   SIGNAL qspo      : STD_LOGIC_VECTOR(UW_DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
   SIGNAL qdpo      : STD_LOGIC_VECTOR(UW_DATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
   
   component dist_mem_gen_v6_2_xst
      generic (
         c_family         : string  := "virtex5";
         c_addr_width     : integer := 6;
         c_default_data   : string  := "0";
         c_depth          : integer := 64;
         c_has_clk        : integer := 1;
         c_has_d          : integer := 1;
         c_has_dpo        : integer := 0;
         c_has_dpra       : integer := 0;
         c_has_i_ce       : integer := 0;
         c_has_qdpo       : integer := 0;
         c_has_qdpo_ce    : integer := 0;
         c_has_qdpo_clk   : integer := 0;
         c_has_qdpo_rst   : integer := 0;
         c_has_qdpo_srst  : integer := 0;
         c_has_qspo       : integer := 0;
         c_has_qspo_ce    : integer := 0;
         c_has_qspo_rst   : integer := 0;
         c_has_qspo_srst  : integer := 0;
         c_has_spo        : integer := 1;
         c_has_spra       : integer := 0;
         c_has_we         : integer := 1;
         c_mem_init_file  : string  := "null.mif";
         c_elaboration_dir : string := "./";
         c_mem_type       : integer := 1;
         c_pipeline_stages : integer := 0;
         c_qce_joined     : integer := 0;
         c_qualify_we     : integer := 0;
         c_read_mif       : integer := 0;
         c_reg_a_d_inputs : integer := 0;
         c_reg_dpra_input : integer := 0;
         c_sync_enable    : integer := 0;
         c_width          : integer := 16;
         c_parser_type    : integer := 1);
      port (
         a         : in  std_logic_vector(c_addr_width-1-(4*c_has_spra*boolean'pos(c_addr_width > 4)) downto 0) := (others => '0');
         d         : in  std_logic_vector(c_width-1 downto 0);
         dpra      : in  std_logic_vector(c_addr_width-1 downto 0);
         spra      : in  std_logic_vector(c_addr_width-1 downto 0);
         clk       : in  std_logic;
         we        : in  std_logic;
         i_ce      : in  std_logic;
         qspo_ce   : in  std_logic;
         qdpo_ce   : in  std_logic;
         qdpo_clk  : in  std_logic;
         qspo_rst  : in  std_logic;
         qdpo_rst  : in  std_logic;
         qspo_srst : in  std_logic;
         qdpo_srst : in  std_logic;
         spo       : out std_logic_vector(c_width-1 downto 0);
         dpo       : out std_logic_vector(c_width-1 downto 0);
         qspo      : out std_logic_vector(c_width-1 downto 0);
         qdpo      : out std_logic_vector(c_width-1 downto 0)); 
   end component;

BEGIN  -- rtl

  uw_dist_mem_core_inst : dist_mem_gen_v6_2_xst
    GENERIC MAP (
                 -- Family value will be updated by the Rodin synthesis tool
                 c_family          => family_name,
                 c_mem_type        => c_mem_type,
                 c_addr_width      => uw_addr_width,
                 c_width           => uw_data_width,
                 c_depth           => uw_mem_depth,

                 c_default_data    => uw_default_data,
                 c_mem_init_file   => uw_mem_init_file,
                 c_elaboration_dir => uw_elaboration_dir,

                 -- Clock is not available only for unregistered ROM output
                 c_has_clk         => if_then_else((uw_mem_type = "ROM" AND uw_output_option = "Unregistered"), 0, 1),

                 -- Dual Port Clock is available only for DPRAM and SDPRAM
                 c_has_qdpo_clk    => if_then_else((uw_mem_type = "DPRAM" OR uw_mem_type = "SDPRAM"), 1, 0),
                 c_has_qdpo_rst    => c_rst_type,
                 c_has_qdpo_srst   => if_then_else((c_rst_type = 0), 1, 0),
                 c_has_qspo_rst    => c_rst_type,
                 c_has_qspo_srst   => if_then_else((c_rst_type = 0), 1, 0),
		 
                 -- Input data is not available only for ROM
                 c_has_d           => if_then_else((uw_mem_type = "ROM"), 0, 1),
                 -- Write Enable is not available only for ROM
                 c_has_we          => if_then_else((uw_mem_type = "ROM"), 0, 1),
		 
                 c_has_spo         => c_has_spo,
                 c_has_qspo        => c_has_qspo,
                 c_has_dpo         => c_has_dpo,
                 c_has_qdpo        => c_has_qdpo,
                 -- Dual Port Read Address is available only for DPRAM and SDPRAM
                 c_has_dpra        => if_then_else((uw_mem_type = "DPRAM" OR uw_mem_type = "SDPRAM"), 1, 0),
                 c_has_qdpo_ce     => c_reg_out,
                 c_has_qspo_ce     => if_then_else((uw_mem_type /= "SDPRAM"), c_reg_out, 0),

                 c_has_i_ce        => 0,
                 c_has_spra        => 0, -- It is only for SRL based memory
                 c_pipeline_stages => 0,
                 c_qce_joined      => 0,
                 c_qualify_we      => 0,
                 c_read_mif        => if_then_else((uw_mem_init_file = "null.mif"), 0, 1),
                 c_reg_a_d_inputs  => 0,
                 c_reg_dpra_input  => 0,
                 c_sync_enable     => 0,
                 c_parser_type     => 0
                )
    port map (
              a           => addr,
              d           => wr_data,
              dpra        => dp_rd_addr,
              spra        => ADDR_ZEROS,
              clk         => wr_clk,
              we          => wr_en_int,
              i_ce        => GND,
              qspo_ce     => output_reg_en,
              qdpo_ce     => output_reg_en,
              qdpo_clk    => rd_clk,
              qspo_rst    => reset,
              qdpo_rst    => reset,
              qspo_srst   => reset,
              qdpo_srst   => reset,
              spo         => spo,
              dpo         => dpo,
              qspo        => qspo,
              qdpo        => qdpo
             );

   -- Tie WE to '0' for ROM
   gwe1: IF (c_mem_type = 0) GENERATE
     wr_en_int <= '0';
   END GENERATE gwe1;

   gwe2: IF (c_mem_type /= 0) GENERATE
     wr_en_int <= wr_en;
   END GENERATE gwe2;

   -- Registered output
   gsp_dout1: IF (c_mem_type < 3 AND c_reg_out = 1) GENERATE
     sp_rd_data <= qspo;
   END GENERATE gsp_dout1;

   -- Unregistered output
   gsp_dout2: IF (c_mem_type < 3 AND c_no_reg_out = 1) GENERATE
     sp_rd_data <= spo;
   END GENERATE gsp_dout2;

   -- Registered output
   gdp_dout1: IF (c_mem_type > 1 AND c_reg_out = 1) GENERATE
     dp_rd_data <= qdpo;
   END GENERATE gdp_dout1;

   -- Unregistered output
   gdp_dout2: IF (c_mem_type > 1 AND c_no_reg_out = 1) GENERATE
     dp_rd_data <= dpo;
   END GENERATE gdp_dout2;

end rtl;

-- XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
>>>>>>> d68cfb566fed6f983427010d388a4e39e9131875
