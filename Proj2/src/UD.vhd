library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--Mux 4 a 1
entity UD is
    Port ( 	
			valid_I_ID : in  STD_LOGIC; --indica si es una instrucci�n de ID es v�lida
			valid_I_EX : in  STD_LOGIC; --indica si es una instrucci�n de EX es v�lida
			valid_I_MEM : in  STD_LOGIC; --indica si es una instrucci�n de MEM es v�lida
    		Reg_Rs_ID: in  STD_LOGIC_VECTOR (4 downto 0); --registros Rs y Rt en la etapa ID
		  	Reg_Rt_ID	: in  STD_LOGIC_VECTOR (4 downto 0);
			MemRead_EX	: in std_logic; -- información sobre la instrucción en EX (destino, si lee de memoria y si escribe en registro)
			RegWrite_EX	: in std_logic;
			RW_EX			: in  STD_LOGIC_VECTOR (4 downto 0); -- registro destino en EX
			RegWrite_Mem	: in std_logic;-- informacion sobre la instruccion en Mem (destino y si escribe en registro)
			RW_Mem			: in  STD_LOGIC_VECTOR (4 downto 0);
			IR_op_code	: in  STD_LOGIC_VECTOR (5 downto 0); -- código de operación de la instrucción en IEEE
         	salto_tomado			: in std_logic; -- 1 cuando se produce un salto 0 en caso contrario
         	--Nuevo
         	Mem_ready: in std_logic; -- 1 cuando la memoria puede realizar la operaci�n solicitada en el ciclo actual
			parar_EX: out  STD_LOGIC; -- Indica que las etapas EX y previas deben parar
         	Kill_IF		: out  STD_LOGIC; -- Indica que la instrucci�n en IF no debe ejecutarse (fallo en la predicci�n de salto tomado)
			Parar_ID		: out  STD_LOGIC -- Indica que las etapas ID y previas deben parar
			); 
end UD;
Architecture Behavioral of UD is
signal dep_rs_EX, dep_rs_Mem, dep_rt_EX, dep_rt_Mem, ld_uso_rs, ld_uso_rt, WRO_rs, BEQ_rs, BEQ_rt, riesgo_datos_ID, parar_EX_internal : std_logic;
CONSTANT NOP : STD_LOGIC_VECTOR (5 downto 0) := "000000";
CONSTANT LW : STD_LOGIC_VECTOR (5 downto 0) := "000010";
CONSTANT BEQ : STD_LOGIC_VECTOR (5 downto 0) := "000100";
CONSTANT RTE_opcode : STD_LOGIC_VECTOR (5 downto 0) := "001000";
CONSTANT WRO_opcode : STD_LOGIC_VECTOR (5 downto 0) := "100000";
begin
-------------------------------------------------------------------------------------------------------------------------------
-- Kill_IF:
-- da la orden de matar la instrucci�n que se ha le�do en Fetch
-- Se debe activar cada vez que se salte (entrada salto_tomado), ya que por defecto se ha hecho el fetch de la instrucci�n siguiente al salto y si se
--  salta no hay que ejecutarla
-- IMPORTANTE: Fus operandos disponibles no sabe si debe saltar o no. Da igual lo que diga salto tomado, ya que se ha calculado con datos incorrectos
-- 	* si la instrucci�n que hay en ID no es v�lida hay que ignorarla cuando si nos dice que va a saltar (igual que si nos dice cualuier otra cosa), s�lo
--  hacmeos caso a las instrucciones v�lidas
-- Completar: activar Kill_IF cuando proceda
	Kill_IF <= '1' when (salto_tomado = '1' and (((BEQ_rs = '0') and (BEQ_rt = '0')) or (IR_op_code = RTE_opcode))) else '0';

-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-- Detecci�n de dependencias de datos:	
-- El c�digo incluye un ejemplo: dep_rs_EX. Deb�is completar el resto de opciones.	
	
	-- dep_rs_EX: la I en EX escribe en el registro rs y la I en ID usa rs (es decir no es un NOP ni RTE)
	dep_rs_EX 	<= 	'1' when ((valid_I_EX = '1') AND (Reg_Rs_ID = RW_EX) and (RegWrite_EX = '1') and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode))	else '0';
								
	------------------------------------------------------------------------------------
	-- Completar. Falta la l�gica que genera el valor correcto de estas se�ales.
	-- dep_rs_Mem: 
	dep_rs_Mem	<= 	'1' when ((valid_I_MEM = '1') AND (Reg_Rs_ID = RW_MEM) and (RegWrite_MEM = '1') and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode)) else '0';
							
	-- dep_rt_EX: 
	dep_rt_EX	<= 	'1' when ((valid_I_EX = '1') AND (Reg_Rt_ID = RW_EX) and (RegWrite_EX = '1') and (IR_op_code /= LW) and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode) and (IR_op_code /= WRO_opcode))	else '0';
								
	-- dep_rt_Mem:
	dep_rt_Mem	<= 	'1' when ((valid_I_MEM = '1') AND (Reg_Rt_ID = RW_MEM) and (RegWrite_MEM = '1') and (IR_op_code /= LW) and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode) and (IR_op_code /= WRO_opcode)) else '0';
-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-- Riesgos de datos:
	-- 1) lw_uso: Si hay dependencia y la instrucci�n en EX es lw tenemos un lw_uso
	ld_uso_rs <= 	'1' when (dep_rs_EX = '1') and (MemRead_EX = '1') else '0';
	ld_uso_rt <= 	'1' when (dep_rt_EX = '1') and (MemRead_EX = '1') else '0';
									
	-- 2) BEQ: si hay dependencias y la I en ID es un BEQ es un riesgo porque el BEQ lee los datos en ID, y no tenemos red de cortos en esa etapa
	BEQ_rs	<= 	'1' when ((dep_rs_EX = '1' or dep_rs_Mem = '1') and IR_op_code = BEQ) else '0';
	BEQ_rt	<= 	'1' when ((dep_rt_EX = '1' or dep_rt_Mem = '1') and IR_op_code = BEQ) else '0';
		
	-- 3) WRO: Dependencia similar al BEQ, pero hay que tener en cuenta que WRO s�lo usa Rs
	
	WRO_rs	<= 	'1' when ((dep_rs_EX = '1' or dep_rs_Mem = '1') and IR_op_code = WRO_opcode) else '0';
	
	-- Si se cumple alguna de las condiciones de riesgo de datos se detienen las etapas IF e ID
	riesgo_datos_ID <= BEQ_rt OR BEQ_rs OR ld_uso_rs OR ld_uso_rt OR WRO_rs;
	-- IMPORTANTE: s�lo hay riesgos de datos si la instrucci�n en ID es v�lida
	-- Si se da la orden de parar EX, tambi�n hay que parar ID. En el proyecto 1 no hace falta, pero lo ponemos para no tener que tocarlo luego
	Parar_ID <= parar_EX_internal or (valid_I_ID and riesgo_datos_ID);
-------------------------------------------------------------------------------------------------------------------------------
-- Parar_EX:
-- NOTA: en el proyecto 1, no hace falta parar nunca en EX porque la memoria siempre est� preparada para hacer lo que le pidas
-- En el P2, habr� que mirar Mem_ready y si no puede hacer lo que le has pedido (Mem_ready = '0') parar la etapa EX y las anteriores
-- parar_EX_internal se define para poder leerla en el c�digo (en vhdl las salidas de una entidad no se pueden leer dentro de la entidad. 
-- Depende de c�mo lo hag�is es necesaria o no

	parar_EX_internal <= '1' when Mem_ready = '0' else '0';
	parar_EX <= parar_EX_internal;
-------------------------------------------------------------------------------------------------------------------------------
end Behavioral;


