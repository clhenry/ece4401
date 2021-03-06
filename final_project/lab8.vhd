library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lab8 is
	port(
		vgaRed : out std_logic_vector(3 downto 1);
		vgaGreen : out std_logic_vector(3 downto 1);
		vgaBlue : out std_logic_vector(3 downto 2);
		Hsync : out std_logic;
		Vsync : out std_logic;
		MemAdr : out std_logic_vector(23 downto 1);
		MemDB  : inout std_logic_vector(15 downto 0);
		RamCS  : out std_logic;
		RamUB  : out std_logic;
		RamLB  : out std_logic;
		RamAdv  : out std_logic;
		RamClk  : out std_logic;
		RamCRE  : out std_logic;
		MemOE  : out std_logic;
		MemWR  : out std_logic;
		ps2c : inout std_logic;
		ps2d : inout std_logic;
		led : out std_logic_vector(7 downto 0);
		btn : in std_logic_vector(3 downto 3);
		clk : in std_logic;
    spi_clock : OUT STD_LOGIC;
    spi_mosi : OUT STD_LOGIC;
    spi_miso : IN STD_LOGIC;
    spi_csn : OUT STD_LOGIC;
    spi_ce : OUT STD_LOGIC;
    spi_interrupt : IN STD_LOGIC
	);
end lab8;

architecture Behavioral of lab8 is
	-- Wishbone signals
	signal ACK_I_M : std_logic_vector(3 downto 0);
	signal ACK_O_S : std_logic_vector(3 downto 0);
	signal ADR_O_M0 : std_logic_vector( 31 downto 0 );
	signal ADR_O_M1 : std_logic_vector( 31 downto 0 );
	signal ADR_O_M2 : std_logic_vector( 31 downto 0 );
	signal ADR_O_M3 : std_logic_vector( 31 downto 0 );
	signal ADR_I_S  :	std_logic_vector( 31 downto 0 );
	signal CYC_O_M : std_logic_vector(3 downto 0);
	signal DAT_O_M0 : std_logic_vector( 31 downto 0 );
	signal DAT_O_M1 : std_logic_vector( 31 downto 0 );
	signal DAT_O_M2 : std_logic_vector( 31 downto 0 );
	signal DAT_O_M3 : std_logic_vector( 31 downto 0 );
	signal DWR : std_logic_vector( 31 downto 0 );
	signal DAT_O_S0 : std_logic_vector( 31 downto 0 );
	signal DAT_O_S1 : std_logic_vector( 31 downto 0 );
	signal DAT_O_S2 : std_logic_vector( 31 downto 0 );
	signal DAT_O_S3 : std_logic_vector( 31 downto 0 );
	signal DRD : std_logic_vector( 31 downto 0 );
	signal IRQ_O_S : std_logic_vector(3 downto 0);
	signal IRQ_I_M : std_logic;
	signal IRQV_I_M :	std_logic_vector(1 downto 0);
	signal STB_I_S : std_logic_vector(3 downto 0);
	signal STB_O_M : std_logic_vector(3 downto 0);
	signal WE_O_M : std_logic_vector(3 downto 0);
	signal WE : std_logic;

	signal rst : std_logic;

begin

  rst <= btn(3);

	wb_intercon : entity work.wb_intercon
	port map(
		clk => clk, rst => rst,
		ack_i_m => ack_i_m,
		ack_o_s => ack_o_s,
		adr_o_m0 => adr_o_m0,
		adr_o_m1 => adr_o_m1,
		adr_o_m2 => adr_o_m2,
		adr_o_m3 => adr_o_m3,
		dat_o_m0 => dat_o_m0,
		dat_o_m1 => dat_o_m1,
		dat_o_m2 => dat_o_m2,
		dat_o_m3 => dat_o_m3,
		dat_o_s0 => dat_o_s0,
		dat_o_s1 => dat_o_s1,
		dat_o_s2 => dat_o_s2,
		dat_o_s3 => dat_o_s3,
		adr_i_s => adr_i_s,
		drd => drd,
		dwr => dwr,
		irq_o_s => irq_o_s,
		irq_i_m => irq_i_m,
		irqv_i_m => irqv_i_m,
		cyc_o_m => cyc_o_m,
		stb_o_m => stb_o_m,
		stb_i_s => stb_i_s,
		we_o_m => we_o_m,
		we => we
	);
		
	-- wb_kb_read_sram_write is the master module that waits for interrupts 
	-- from the ps2_kb module and then reads the scancode from the ps2_kb module
	-- and then converts the scancode to a ascii code which is then written to
	-- the SRAM
	wb_kb_read_sram_write : entity work.wb_kb_read_sram_write -- master
	port map(
		clk_i => clk,
		rst_i => rst,
		adr_o => adr_o_m0,
		dat_i => drd,
		dat_o => dat_o_m0,
		ack_i => ack_i_m(0),
		cyc_o => cyc_o_m(0),
		stb_o => stb_o_m(0),
		we_o => we_o_m(0),
		irq_i => irq_i_m,
		irqv_i => irqv_i_m,
    spi_clock => spi_clock,
    spi_mosi => spi_mosi,
    spi_miso => spi_miso,
    spi_csn => spi_csn,
    spi_ce => spi_ce,
    spi_interrupt => spi_interrupt,
		leds_o => led
	);

	-- The VGA module needs 4 bits per pixel and has a pixel clock period of 40ns
	-- The system can read 32 bits/8 pixels from RAM in roughly 200ns. We need 80 RAM reads
	-- for a complete line (640 pixels). During front porch + sync + back porch period
	-- The idea is to read data from memory maybe a line at a time then write it into
  -- some block RAM, possibly enough to hold a display line at a time

	vga : entity work.wb_vga640x480 -- master
	port map(
		sys_clk => clk,
		reset => rst,
		adr_o => adr_o_m1,
		dat_i => drd,
		dat_o => dat_o_m1,
		ack_i => ack_i_m(1),
		cyc_o => cyc_o_m(1),
		stb_o => stb_o_m(1),
		we_o => we_o_m(1),
		red => vgaRed,
		green => vgaGreen,
		blue => vgaBlue,
		hsync => Hsync,
		vsync => Vsync
	);

	wb_ps2_kb : entity work.wb_ps2_kb -- slave
	port map(
		clk_i => clk,
		rst_i => rst, 
		ps2_clk => ps2c,
		ps2_data => ps2d, 
		adr_i => adr_i_s,
		dat_i => dwr,
		dat_o => dat_o_s0,
		ack_o => ack_o_s(0),
		stb_i => stb_i_s(0),
		we_i => we,
		irq_o => irq_o_s(0)
	);

	sram16ctl : entity work.sram16ctl -- slave
	port map(
		clk_i => clk,
		rst_i => rst, 
		adr_i => adr_i_s,
		dat_i => dwr,
		dat_o => dat_o_s1,
		ack_o => ack_o_s(1),
		stb_i => stb_i_s(1),
		we_i => we,
		MemAdr => MemAdr,
		MemOE => MemOE,
		MemWR => MemWR,
		MemDB => MemDB, 
		RamClk => RamClk,
		RamCRE => RamCRE,
		RamAdv => RamAdv,
		RamCS => RamCS,
		RamUB => RamUB,
		RamLB => RamLB
	);

	cyc_o_m(3) <= '0';
	cyc_o_m(2) <= '0';

end Behavioral;
