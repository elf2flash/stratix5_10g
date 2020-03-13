----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
library altera;
use altera.altera_primitives_components.all;
library work;
use work.std_package.all;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
entity s5_temperature is
	port
	(
		i_clk								: in std_logic := '0';										-- 50МГц
		o_TEMP_CLK							: out std_logic := '1';										-- i2c
		io_TEMP_DATA						: inout std_logic := '1';									-- i2c
		o_TempByte							: out std_logic_vector(7 downto 0) := (others => '0');		-- результирующее прочитанное слово
		--
		o_TempByte_L_valid					: out std_logic := '0';										-- 
		o_TempByte_L						: out std_logic_vector(7 downto 0) := (others => '0');		-- 
		o_TempByte_R_valid					: out std_logic := '0';										-- 
		o_TempByte_R						: out std_logic_vector(7 downto 0) := (others => '0');		-- 
		o_TempByte_MAN_ID_valid				: out std_logic := '0';										-- 
		o_TempByte_MAN_ID					: out std_logic_vector(7 downto 0) := (others => '0');		-- 
		o_TempByte_DEV_ID_valid				: out std_logic := '0';										-- 
		o_TempByte_DEV_ID					: out std_logic_vector(7 downto 0) := (others => '0')		-- 
	);
end entity;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
architecture rtl of s5_temperature is
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
signal inx									: std_logic_vector(6 downto 0) := (others => '0');
signal inx_prev								: std_logic_vector(6 downto 0) := (others => '0');
signal tclk_cnt								: std_logic_vector(31 downto 0) := (others => '0');
signal tclk									: std_logic := '0';
signal tclk_prev							: std_logic := '0';
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Направление шины i2с
signal TempDIR								: std_logic_vector(127 downto 0) := "11111"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"000"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"000"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"111111111111111";
-- Посылка для получения локальной температуры                                  [    S] [          ADDRESS = 0X30               ] [ WR] [ASK] [        COMMAND = 0x00                       ] [ASK] [  S] [      ADDRESS = 0x31                   ] [ RD] [ASK] [   DATA                                      ] [  P            ]
signal TempOUT_L							: std_logic_vector(127 downto 0) := "11100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000001111111111";
-- Посылка для получения удаленной температуры                                  [    S] [          ADDRESS = 0X30               ] [ WR] [ASK] [        COMMAND = 0x01                       ] [ASK] [  S] [      ADDRESS = 0x31                   ] [ RD] [ASK] [   DATA                                      ] [  P            ]
signal TempOUT_R							: std_logic_vector(127 downto 0) := "11100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"111"&"000"&"100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000001111111111";
-- Посылка для получения ID мануфактуры 0x4D                                    [    S] [          ADDRESS = 0X30               ] [ WR] [ASK] [        COMMAND = 0xFE (1111 1110)           ] [ASK] [  S] [      ADDRESS = 0x31                   ] [ RD] [ASK] [   DATA                                      ] [  P            ]
signal TempOUT_MAN_ID						: std_logic_vector(127 downto 0) := "11100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"000"&"000"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"000"&"000"&"100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000001111111111";
-- Посылка для получения ID устройства 0x04                                     [    S] [          ADDRESS = 0X30               ] [ WR] [ASK] [        COMMAND = 0xFF (1111 1111)           ] [ASK] [  S] [      ADDRESS = 0x31                   ] [ RD] [ASK] [   DATA                                      ] [  P            ]
signal TempOUT_DEV_ID						: std_logic_vector(127 downto 0) := "11100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"000"&"000"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"111"&"000"&"100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000001111111111";
-- Циклограмма клока
signal TempCLK								: std_logic_vector(127 downto 0) := "11110"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"110"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"010"&"001111111111111";
-- Общиц вектор
signal TempOUT								: std_logic_vector(127 downto 0) := "11100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"100"&"000"&"000"&"111"&"111"&"000"&"000"&"000"&"111"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000"&"000001111111111";
signal TempOUT_f							: integer := 0;
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
signal TempByteTmp							: std_logic_vector(7 downto 0) := (others => '0');
--
signal TempByte_L							: std_logic_vector(7 downto 0) := (others => '0');
signal TempByte_R							: std_logic_vector(7 downto 0) := (others => '0');
signal TempByte_MAN_ID						: std_logic_vector(7 downto 0) := (others => '0');
signal TempByte_DEV_ID						: std_logic_vector(7 downto 0) := (others => '0');
--
signal TempByte_DEV_ID_valid				: std_logic := '0';
signal TempByte_L_valid						: std_logic := '0';
signal TempByte_R_valid						: std_logic := '0';
signal TempByte_MAN_ID_valid				: std_logic := '0';
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
	
	
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	io_TEMP_DATA												<= TempOUT(uint(inx)) when TempDIR(uint(inx)) = '1' else 'Z';
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	o_TempByte_L_valid											<= TempByte_L_valid;
	o_TempByte_L												<= TempByte_L;
	o_TempByte_R_valid											<= TempByte_R_valid;
	o_TempByte_R												<= TempByte_R;
	o_TempByte_MAN_ID_valid										<= TempByte_MAN_ID_valid;
	o_TempByte_MAN_ID											<= TempByte_MAN_ID;
	o_TempByte_DEV_ID_valid										<= TempByte_DEV_ID_valid;
	o_TempByte_DEV_ID											<= TempByte_DEV_ID;
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- понижаем частоту для шины i2c
	tclk														<= tclk_cnt(15);
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	process(i_clk)
	begin
		if (rising_edge(i_clk)) then
			inx_prev											<= inx;
			tclk_cnt											<= tclk_cnt + 1;
			tclk_prev											<= tclk;
			if (tclk = '1' AND tclk_prev = '0') then
				inx												<= inx - 1;
				o_TEMP_CLK										<= TempCLK(uint(inx-1));
			end if;
			----------------------------------------------------------------------------------------------------------------------------------------------------------------
			if (tclk = '0' AND tclk_prev = '1') then
				if (TempDIR(uint(inx)) = '0') then
					-- накопление ответного слова
					if (uint(inx) = 37) then
						TempByteTmp(7)							<= io_TEMP_DATA;
					elsif (uint(inx) = 34) then
						TempByteTmp(6)							<= io_TEMP_DATA;
					elsif (uint(inx) = 31) then
						TempByteTmp(5)							<= io_TEMP_DATA;
					elsif (uint(inx) = 28) then
						TempByteTmp(4)							<= io_TEMP_DATA;
					elsif (uint(inx) = 25) then
						TempByteTmp(3)							<= io_TEMP_DATA;
					elsif (uint(inx) = 22) then
						TempByteTmp(2)							<= io_TEMP_DATA;
					elsif (uint(inx) = 19) then
						TempByteTmp(1)							<= io_TEMP_DATA;
					elsif (uint(inx) = 16) then
						o_TempByte(7 downto 1)					<= TempByteTmp(7 downto 1);
						TempByteTmp(0)							<= io_TEMP_DATA;
						o_TempByte(0)							<= io_TEMP_DATA;	-- результирующее прочитанное слово
					end if;
				end if;
			end if;
			----------------------------------------------------------------------------------------------------------------------------------------------------------------
			-- раскидываем прочитанные слова по соответствующим регистрам
			if (inx = 127 AND inx_prev = 0) then
				if (TempOUT_f = 0) then
					TempOUT_f									<= 1;
					TempOUT										<= TempOUT_L;
					TempByte_DEV_ID_valid						<= '1';
					TempByte_L_valid							<= '0';
					TempByte_R_valid							<= '0';
					TempByte_MAN_ID_valid						<= '0';
					TempByte_DEV_ID								<= TempByteTmp;
				elsif (TempOUT_f = 1) then
					TempOUT_f									<= 2;
					TempOUT										<= TempOUT_R;
					TempByte_DEV_ID_valid						<= '0';
					TempByte_L_valid							<= '1';
					TempByte_R_valid							<= '0';
					TempByte_MAN_ID_valid						<= '0';
					TempByte_L									<= TempByteTmp;
				elsif (TempOUT_f = 2) then
					TempOUT_f									<= 3;
					TempOUT										<= TempOUT_MAN_ID;
					TempByte_DEV_ID_valid						<= '0';
					TempByte_L_valid							<= '0';
					TempByte_R_valid							<= '1';
					TempByte_MAN_ID_valid						<= '0';
					TempByte_R									<= TempByteTmp;
				elsif (TempOUT_f = 3) then
					TempOUT_f									<= 0;
					TempOUT										<= TempOUT_DEV_ID;
					TempByte_DEV_ID_valid						<= '0';
					TempByte_L_valid							<= '0';
					TempByte_R_valid							<= '0';
					TempByte_MAN_ID_valid						<= '1';
					TempByte_MAN_ID								<= TempByteTmp;
				end if;
			end if;
			
		end if;
	end process;
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
end rtl;

