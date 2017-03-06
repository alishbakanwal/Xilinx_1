<<<<<<< HEAD
version https://git-lfs.github.com/spec/v1
oid sha256:cc1394ae8073bef9f21983eeec7054c6318ec3c374f1ee5c3265dd66a7b295cd
size 7915
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

ENTITY uw_dist_mem IS
   GENERIC (
      UW_MEM_TYPE            : STRING  := "ROM";          -- ROM, SPRAM, DPRAM, SDPRAM; Default: ROM
      UW_ADDR_WIDTH          : INTEGER := 6;              -- Range: 4 - 16; Default: 6
      UW_DATA_WIDTH          : INTEGER := 16;             -- Range: 1 - 1024; Default: 16
      UW_MEM_DEPTH           : INTEGER := 64;             -- Range: 16 - 64K with multiples of 16; Default: 64
      UW_OUTPUT_OPTION       : STRING  := "Unregistered"; -- Registered, Unregistered; Default: Registered
      UW_RESET_TYPE          : STRING  := "Sync";         -- Sync, Async; Default: Sync
      UW_DEFAULT_DATA        : STRING  := "0";
      UW_MEM_INIT_FILE       : STRING  := "null.mif";
      UW_ELABORATION_DIR     : STRING  := "./"
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

END uw_dist_mem;

-------------------------------------------------------------------------------

ARCHITECTURE rtl OF uw_dist_mem IS

component uw_dist_mem_core

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
end component ;

BEGIN  -- rtl

  uw_dist_mem_inst : uw_dist_mem_core
    generic map (
      uw_mem_type => uw_mem_type,
      uw_addr_width => uw_addr_width,     
      uw_data_width  => uw_data_width,   
      uw_mem_depth =>  uw_mem_depth,    
      uw_output_option => uw_output_option,  
      uw_reset_type => uw_reset_type,       
      uw_default_data  => uw_default_data, 
      uw_mem_init_file => uw_mem_init_file, 
      uw_elaboration_dir   => uw_elaboration_dir ,
      family_name      => "virtex7")
    port map (
        reset => reset,
        wr_clk => wr_clk,
        wr_en => wr_en,
        addr => addr,
        wr_data => wr_data,
        rd_clk => rd_clk,
        output_reg_en => output_reg_en,
        dp_rd_addr => dp_rd_addr,
        sp_rd_data => sp_rd_data,
        dp_rd_data => dp_rd_data
      );

end rtl;

-- XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
>>>>>>> d68cfb566fed6f983427010d388a4e39e9131875
