-- A fifo for streaming

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

ENTITY fifo_stream IS
    GENERIC(
        FIFO_SIZE : string := "18Kb"
    );
    PORT (
        clk    : IN std_logic;
        rst    : IN std_logic;
        din_ready  : out std_logic;
        din_valid  : IN  std_logic;
        din_data   : IN  std_logic_vector;
        dout_ready : IN  std_logic;
        dout_valid : out std_logic;
        dout_data  : out std_logic_vector
    );
END fifo_stream;

architecture Behavioral of fifo_stream is

signal fifo_almostfull : std_logic := '0';
signal fifo_empty : std_logic := '1';
signal peek_data   : std_logic_vector(din_data'high downto din_data'low);
signal peek_valid : std_logic := '0';
signal dout_valid_int : std_logic := '0';
signal fifo_rden : std_logic := '0';
signal initialized : std_logic := '0';
signal fifo_wren   : std_logic := '0';
signal resetcount : integer := 0;

signal fifo_FULL    : std_logic := '0';
signal fifo_RDERR   : std_logic := '0';
signal fifo_WRERR   : std_logic := '0';
      
BEGIN
    fifo_wren  <= initialized and din_valid and not rst;
    din_ready <= not fifo_almostfull;
    dout_valid<= dout_valid_int;
    dout_data <= peek_data;


    -- if peek data is invalid or being read, and buffer is nonempty
    -- read it into peek
    fifo_rden     <= not fifo_empty and (not dout_valid_int or dout_ready);

    -- FIFO_SYNC_MACRO: Synchronous First-In, First-Out (FIFO) RAM Buffer
    --                  Artix-7
    -- Xilinx HDL Language Template, version 2019.2
    
    -- Note -  This Unimacro model assumes the port directions to be "downto". 
    --         Simulation of this model with "to" in the port directions could lead to erroneous results.
    
    -----------------------------------------------------------------
    -- DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width --
    -- ===========|===========|============|=======================--
    --   37-72    |  "36Kb"   |     512    |         9-bit         --
    --   19-36    |  "36Kb"   |    1024    |        10-bit         --
    --   19-36    |  "18Kb"   |     512    |         9-bit         --
    --   10-18    |  "36Kb"   |    2048    |        11-bit         --
    --   10-18    |  "18Kb"   |    1024    |        10-bit         --
    --    5-9     |  "36Kb"   |    4096    |        12-bit         --
    --    5-9     |  "18Kb"   |    2048    |        11-bit         --
    --    1-4     |  "36Kb"   |    8192    |        13-bit         --
    --    1-4     |  "18Kb"   |    4096    |        12-bit         --
    -----------------------------------------------------------------

    FIFO_SYNC_MACRO_inst2 : FIFO_SYNC_MACRO
    generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5, "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0080",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold
      DATA_WIDTH => din_data'length,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => FIFO_SIZE)            -- Target BRAM, "18Kb" or "36Kb" 
    port map (
      ALMOSTEMPTY => open,   -- 1-bit output almost empty
      ALMOSTFULL  => fifo_almostfull,     -- 1-bit output almost full
      DO          => peek_data,-- Output data, width defined by DATA_WIDTH parameter
      EMPTY => fifo_empty,-- 1-bit output empty
      FULL    => fifo_FULL,    -- 1-bit output full
      RDCOUNT => open,           -- Output read count, width determined by FIFO depth
      RDERR   => fifo_RDERR,                 -- 1-bit output read error
      WRCOUNT => open,           -- Output write count, width determined by FIFO depth
      WRERR   => fifo_WRERR,                 -- 1-bit output write error
      CLK => CLK,                   -- 1-bit input clock
      DI => din_data,               -- Input data, width defined by DATA_WIDTH parameter
      RDEN => fifo_rden,             -- 1-bit input read wrrdenle
      RST => RST,                   -- 1-bit input reset
      WREN => fifo_wren              -- 1-bit input write wrrdenle
    );
    -- End of FIFO_SYNC_MACRO_inst instantiation

    PROCESS (clk)
    begin
    if rising_edge(clk) then
        if rst = '0' then
            -- not valid if being read
            if dout_ready = '1' then
                dout_valid_int <= '0';
            end if;
            
            -- if we read last cycle, data is valid
            if fifo_rden = '1' then
                dout_valid_int <= '1';
            end if;
            
            resetcount <= 0;
        else
            resetcount <= resetcount + 1;
            if resetcount >= 5 then
                initialized <= '1';
            end if;
        end if;
    end if;
    END PROCESS;
END;