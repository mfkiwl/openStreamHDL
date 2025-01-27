Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;

-- Julian Loiacono

Entity spi_slave_dualclock Is
	Port (
		CLK : In Std_logic; -- SPI clock
		RST : In Std_logic; -- SPI clock
		-- SPI SLAVE INTERFACE
		SCLK : In Std_logic; -- SPI clock
		CS_N : In Std_logic; -- SPI chip select, active in low
		MOSI : In Std_logic_vector(0 Downto 0); -- SPI serial data from master to slave
		MISO : Out Std_logic_vector(0 Downto 0); -- SPI serial data from slave to master
		-- USER INTERFACE
		TX_DATA : In Std_logic_vector; -- input data for SPI master
		TX_VALID : In Std_logic; -- when TX_VALID = 1, input data are valid
		TX_READY : Out Std_logic; -- when TX_READY = 1, valid input data are accept
		TX_Enable : In Std_logic;

		RX_DATA : Out Std_logic_vector; -- output data from SPI master
		RX_VALID : Out Std_logic; -- when RX_VALID = 1, output data are valid
		RX_READY : In Std_logic
	);
End spi_slave_dualclock;

Architecture RTL Of spi_slave_dualclock Is

	Signal MISO_valid : Std_logic := '0'; -- Data Valid Pulse with TX_data
	Signal MISO_Ready : Std_logic := '1'; -- Transmit Ready for next byte
	Signal MISO_int : Std_logic_vector(0 Downto 0) := (Others => '0');

	Signal MOSI_valid : Std_logic := '0'; -- Data Valid Pulse with TX_data
	Signal MOSI_Ready : Std_logic := '0'; -- Transmit Ready for next byte

	Signal TXFIFO_DATA : Std_logic_vector(TX_DATA'high Downto 0); -- input data for SPI master
	Signal TXFIFO_VALID : Std_logic; -- when TX_VALID = 1, input data are valid
	Signal TXFIFO_READY : Std_logic; -- when TX_READY = 1, valid input data are accept
	Signal TX_Enable_LATCHED : Std_logic;

	Signal MISO_READY_and_enable : Std_logic;

	Signal RXFIFO_DATA : Std_logic_vector(RX_DATA'high Downto 0); -- output data from SPI master
	Signal RXFIFO_VALID : Std_logic; -- when RX_VALID = 1, output data are valid
	Signal RXFIFO_READY : Std_logic;
	Signal rst_or_deselected : Std_logic;

	Signal sclk_not : Std_logic;

Begin
	sclk_not <= Not sclk;
	MOSI_VALID <= Not CS_N;
	MISO_Ready <= Not CS_N;
	rst_or_deselected <= rst Or CS_N;
	MISO_READY_and_enable <= MISO_READY And TX_Enable_LATCHED; -- THIS SIGNAL CROSSES DOMAINS AND IDGAF

    MISO <= MISO_int;
    -- LATCH ENABLE ON DESELECT
	latch_process :
	Process (CS_N)
	Begin
		If rising_edge(CS_N) Then
			TX_Enable_LATCHED <= TX_Enable;
		End If;
	End Process;
	
	miso_process :
	Process (sclk)
	Begin
		If falling_edge(sclk) Then
           --MISO <= MISO_int;
		End If;
	End Process;
	
	-- transmit
	fs_tx : Entity work.fifo_stream_36_dual
		Generic Map(
			ALMOST_FULL_OFFSET => x"001F"
		)
		Port Map(
			inclk => clk,
			outclk => sclk_not,
			rst => rst,
			din_ready => TX_ready,
			din_valid => TX_valid,
			din_data => TX_data,
			dout_ready => TXFIFO_ready,
			dout_valid => TXFIFO_valid,
			dout_data => TXFIFO_data
		);

	ser : Entity work.serializer
		Port Map(
			clk => sclk_not,
			rst => rst,
			din_ready => TXFIFO_ready,
			din_valid => TXFIFO_valid,
			din_data => TXFIFO_data,
			dout_ready => MISO_READY_and_Enable,
			dout_valid => MISO_valid,
			dout_data => MISO_int
		);

	deser : Entity work.deserializer
		Port Map(
			clk => sclk,
			rst => rst_or_deselected, -- clear deserializer when deselected
			din_ready => MOSI_ready,
			din_valid => MOSI_valid,
			din_data => MOSI,
			dout_ready => RXFIFO_READY,
			dout_valid => RXFIFO_valid,
			dout_data => RXFIFO_data
		);

	-- receive
	fs_rx : Entity work.fifo_stream_36_dual
		Generic Map(
			ALMOST_FULL_OFFSET => x"00FF"
		)
		Port Map(
			inclk => sclk_not,
			outclk => clk,
			rst => rst,
			din_ready => RXFIFO_ready,
			din_valid => RXFIFO_valid,
			din_data => RXFIFO_data,
			dout_ready => RX_ready,
			dout_valid => RX_valid,
			dout_data => RX_data
		);

End RTL;