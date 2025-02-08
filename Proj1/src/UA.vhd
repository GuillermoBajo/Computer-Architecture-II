library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- Unidad de anticipación incompleta. Ahora mismo selecciona siempre la entrada 0
-- Entradas: 
-- Reg_Rs_EX
-- Reg_Rt_EX
-- RegWrite_MEM
-- RW_MEM
-- RegWrite_WB
-- RW_WB
-- Salidas:
-- MUX_ctrl_A
-- MUX_ctrl_B
entity UA is
	Port(
			valid_I_MEM : in  STD_LOGIC; --indica si es una instrucci�n de MEM es v�lida
			valid_I_WB : in  STD_LOGIC; --indica si es una instrucci�n de WB es v�lida
			Reg_Rs_EX: IN  std_logic_vector(4 downto 0); 
			Reg_Rt_EX: IN  std_logic_vector(4 downto 0);
			RegWrite_MEM: IN std_logic;
			RW_MEM: IN  std_logic_vector(4 downto 0);
			RegWrite_WB: IN std_logic;
			RW_WB: IN  std_logic_vector(4 downto 0);
			MUX_ctrl_A: out std_logic_vector(1 downto 0);
			MUX_ctrl_B: out std_logic_vector(1 downto 0)
		);
	end UA;

Architecture Behavioral of UA is
signal Corto_A_Mem, Corto_B_Mem, Corto_A_WB, Corto_B_WB: std_logic;
begin


-- Dise�o incompleto. Os lo ponemos c�mo ejemplo. Deb�is completarlo vosotros
-- Activamos la se�al corto_A_Mem, cuand detectamos que el operando almacenado en A (Rs) es el mismo en el que va a escribir la instrucci�n que est� en la etapa Mem
-- Importante: s�lo activamos el corto si la instrucci�n de la etapa MEM en v�lida
Corto_A_Mem <= '1' when ((Reg_Rs_EX = RW_MEM) and (RegWrite_MEM = '1') and (valid_I_MEM = '1'))	else '0';
-- Resto de cortos:
Corto_B_Mem <= '1' when ((Reg_Rt_EX = RW_MEM) and (RegWrite_MEM = '1') and (valid_I_MEM = '1'))	else '0';
--Para WB, comprobar ademas que no haya doble dependencia
Corto_A_WB	<= '1' when ((Reg_Rs_EX = RW_WB) and (RegWrite_WB = '1') and (valid_I_WB = '1')) else '0';
Corto_B_WB	<= '1' when ((Reg_Rt_EX = RW_WB) and (RegWrite_WB = '1') and (valid_I_WB = '1')) else '0';
-- Con las se�ales anteriores se elige la entrada de los muxes:
-- entrada 00: se corresponde al dato del banco de registros
-- entrada 01: dato de la etapa Mem
-- entrada 10: dato de la etapa WB
-- Ponemos un ejemplo para el Corto_A_Mem. Deb�is completarlo
MUX_ctrl_A <= 	"01" when (Corto_A_Mem = '1') else
				"10" when (Corto_A_WB = '1') else
				"00";

MUX_ctrl_B <= 	"01" when (Corto_B_Mem = '1') else
				"10" when (Corto_B_WB = '1') else
				"00";	
end Behavioral;