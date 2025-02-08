----------------------------------------------------------------------------------
-- Description: Mips segmentado tal y como lo hemos estudiado en clase. Sus caracter�sticas son:
-- Saltos 1-retardados
-- instrucciones aritm�ticas, LW, SW y BEQ
-- MI y MD de 128 palabras de 32 bits
-- Excepciones: IRQ, ABORT y UNDEF
-- L�nea de IRQ
-- Nuevas instrucciones: RTE y WRO
-- Hay funcionalidad incompleta en este archivo, y en UD y UA. Buscar la etiqueta: completar
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MIPs_segmentado is
    Port ( 	clk : in  STD_LOGIC;
           	reset : in  STD_LOGIC;
           	IRQ	: 	in  STD_LOGIC; 
           	IO_input: in STD_LOGIC_VECTOR (31 downto 0); -- 32 bits de entrada para el MIPS para IO. En el primer proyecto no se usa. En el segundo s�
	   		IO_output : out  STD_LOGIC_VECTOR (31 downto 0)); -- 32 bits de salida para el MIPS para IO
end MIPs_segmentado;

architecture Behavioral of MIPs_segmentado is

component reg is
    generic (size: natural := 32);  -- por defecto son de 32 bits, pero se puede usar cualquier tama�o
	Port ( Din : in  STD_LOGIC_VECTOR (size -1 downto 0);
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
           load : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (size -1 downto 0));
end component;
---------------------------------------------------------------

component adder32 is
    Port ( Din0 : in  STD_LOGIC_VECTOR (31 downto 0);
           Din1 : in  STD_LOGIC_VECTOR (31 downto 0);
           Dout : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component mux2_1 is
  Port (   DIn0 : in  STD_LOGIC_VECTOR (31 downto 0);
           DIn1 : in  STD_LOGIC_VECTOR (31 downto 0);
		   ctrl : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component Data_Memory_Subsystem is port (
		  CLK : in std_logic;
		  reset: in std_logic; 
		  ADDR : in std_logic_vector (31 downto 0); --Dir solicitada por el Mips
          Din : in std_logic_vector (31 downto 0);--entrada de datos desde el Mips
		  WE : in std_logic;		-- write enable	del MIPS
		  RE : in std_logic;		-- read enable del MIPS	
		  IO_input: in std_logic_vector (31 downto 0); --dato que viene de una entrada del sistema
		  Mem_ready: out std_logic; -- indica si podemos hacer la operaci�n solicitada en el ciclo actual
		  Data_abort: out std_logic; --indica que el �ltimo acceso a memoria ha sido un error
		  Dout : out std_logic_vector (31 downto 0) --dato que se env�a al Mips
		  ); 
end component;


component memoriaRAM_I is port (
		  CLK : in std_logic;
		  ADDR : in std_logic_vector (31 downto 0); --Dir 
          Din : in std_logic_vector (31 downto 0);--entrada de datos para el puerto de escritura
          WE : in std_logic;		-- write enable	
		  RE : in std_logic;		-- read enable		  
		  Dout : out std_logic_vector (31 downto 0));
end component;

component Banco_ID is
 Port ( IR_in : in  STD_LOGIC_VECTOR (31 downto 0); -- instrucci�n leida en IF
        PC4_in:  in  STD_LOGIC_VECTOR (31 downto 0); -- PC+4 sumado en IF
		clk : in  STD_LOGIC;
		reset : in  STD_LOGIC;
        load : in  STD_LOGIC;
        IR_ID : out  STD_LOGIC_VECTOR (31 downto 0); -- instrucci�n en la etapa ID
        PC4_ID:  out  STD_LOGIC_VECTOR (31 downto 0);
        --nuevo para excepciones
        PC_exception:  in  STD_LOGIC_VECTOR (31 downto 0); -- PC al que se volver� si justo esta instrucci�n est� en MEM cuando llega una excepci�n. 
        PC_exception_ID:  out  STD_LOGIC_VECTOR (31 downto 0);-- PC+4 en la etapa ID
        --bits de validez
        valid_I_IF: in STD_LOGIC;
        valid_I_ID: out STD_LOGIC ); 
end component;

COMPONENT BReg
    PORT(
         clk : IN  std_logic;
		 reset : in  STD_LOGIC;
         RA : IN  std_logic_vector(4 downto 0);
         RB : IN  std_logic_vector(4 downto 0);
         RW : IN  std_logic_vector(4 downto 0);
         BusW : IN  std_logic_vector(31 downto 0);
         RegWrite : IN  std_logic;
         BusA : OUT  std_logic_vector(31 downto 0);
         BusB : OUT  std_logic_vector(31 downto 0)
        );
END COMPONENT;

component Ext_signo is
    Port ( inm : in  STD_LOGIC_VECTOR (15 downto 0);
           inm_ext : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component two_bits_shifter is
    Port ( Din : in  STD_LOGIC_VECTOR (31 downto 0);
           Dout : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component UC is
Port ( 		valid_I_ID : in  STD_LOGIC; --indica si es una instrucci�n v�lida			
			IR_op_code : in  STD_LOGIC_VECTOR (5 downto 0);
         	Branch : out  STD_LOGIC;
           	RegDst : out  STD_LOGIC;
           	ALUSrc : out  STD_LOGIC;
		   	MemWrite : out  STD_LOGIC;
           	MemRead : out  STD_LOGIC;
           	MemtoReg : out  STD_LOGIC;
           	RegWrite : out  STD_LOGIC;
            -- Nuevas se�ales
		   	RTE	: out  STD_LOGIC; -- indica que es una instrucci�n RTE
		   	Write_output: out STD_LOGIC; --indica que es una instrucci�n que escribe en la salida
		   	UNDEF: out STD_LOGIC --indica que el c�digo de operaci�n no pertenence a una instrucci�n conocida
			  -- Fin Nuevas se�ales
           );
end component;
-- Unidad de detecci�n de riesgos
component UD is
Port (   	valid_I_ID : in  STD_LOGIC; --indica si es una instrucci�n v�lida
			valid_I_EX : in  STD_LOGIC; --indica si es una instrucci�n de EX es v�lida
			valid_I_MEM : in  STD_LOGIC; --indica si es una instrucci�n de MEM es v�lida
			Reg_Rs_ID: in  STD_LOGIC_VECTOR (4 downto 0); --registros Rs y Rt en la etapa ID
		  	Reg_Rt_ID	: in  STD_LOGIC_VECTOR (4 downto 0);
			MemRead_EX	: in std_logic; -- información sobre la instrucción en EX (destino, si lee de memoria y si escribe en registro)
			RegWrite_EX	: in std_logic;
			RW_EX			: in  STD_LOGIC_VECTOR (4 downto 0);
			RegWrite_Mem	: in std_logic;-- informacion sobre la instruccion en Mem (destino y si escribe en registro)
			RW_Mem			: in  STD_LOGIC_VECTOR (4 downto 0);
			IR_op_code	: in  STD_LOGIC_VECTOR (5 downto 0); -- código de operación de la instrucción en IEEE
         	salto_tomado			: in std_logic; -- 1 cuando se produce un salto 0 en caso contrario
         	--Nuevo
         	Mem_ready: in std_logic; -- 1 cuando la memoria puede realizar la operaci�n solicitada en el ciclo actual
			parar_EX: out  STD_LOGIC; -- Indica que las etapas MEM y previas deben parar
			Kill_IF		: out  STD_LOGIC; -- Indica que la instrucción en IF no debe ejecutarse (fallo en la predicción de salto tomado)
			Parar_ID		: out  STD_LOGIC); -- Indica que las etapas ID y previas deben parar
end component;

COMPONENT Banco_EX
    PORT(
         	 clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			load : in  STD_LOGIC;
	        busA : in  STD_LOGIC_VECTOR (31 downto 0);
           	busB : in  STD_LOGIC_VECTOR (31 downto 0);
			busA_EX : out  STD_LOGIC_VECTOR (31 downto 0);
           	busB_EX : out  STD_LOGIC_VECTOR (31 downto 0);
           	RegDst_ID : in  STD_LOGIC;
           	ALUSrc_ID : in  STD_LOGIC;
           	MemWrite_ID : in  STD_LOGIC;
           	MemRead_ID : in  STD_LOGIC;
           	MemtoReg_ID : in  STD_LOGIC;
           	RegWrite_ID : in  STD_LOGIC;
			inm_ext: IN  std_logic_vector(31 downto 0);
			inm_ext_EX: OUT  std_logic_vector(31 downto 0);
           	RegDst_EX : out  STD_LOGIC;
           	ALUSrc_EX : out  STD_LOGIC;
           	MemWrite_EX : out  STD_LOGIC;
           	MemRead_EX : out  STD_LOGIC;
           	MemtoReg_EX : out  STD_LOGIC;
           	RegWrite_EX : out  STD_LOGIC;
			  -- Nuevo
			Reg_Rs_ID : in  std_logic_vector(4 downto 0);
			Reg_Rs_EX : out std_logic_vector(4 downto 0);
						  --Fin nuevo
			ALUctrl_ID: in STD_LOGIC_VECTOR (2 downto 0);
			ALUctrl_EX: out STD_LOGIC_VECTOR (2 downto 0);
           	Reg_Rt_ID : in  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rd_ID : in  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rt_EX : out  STD_LOGIC_VECTOR (4 downto 0);
           	Reg_Rd_EX : out  STD_LOGIC_VECTOR (4 downto 0);
            -- Nuevo excepci�n
           	PC_exception_ID:  in  STD_LOGIC_VECTOR (31 downto 0);
           	PC_exception_EX:  out  STD_LOGIC_VECTOR (31 downto 0);
           	--bits de validez
        	valid_I_EX_in: in STD_LOGIC;
        	valid_I_EX: out STD_LOGIC);
    END COMPONENT;
        
-- Unidad de anticipaci�n de operandos
    COMPONENT UA
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
	end component;
-- Mux 4 a 1
	component mux4_1_32bits is
	Port ( DIn0 : in  STD_LOGIC_VECTOR (31 downto 0);
		   DIn1 : in  STD_LOGIC_VECTOR (31 downto 0);
		   DIn2 : in  STD_LOGIC_VECTOR (31 downto 0);
		   DIn3 : in  STD_LOGIC_VECTOR (31 downto 0);
		   ctrl : in  std_logic_vector(1 downto 0);
		   Dout : out  STD_LOGIC_VECTOR (31 downto 0));
	end component;
	
	COMPONENT ALU
    PORT(
         DA : IN  std_logic_vector(31 downto 0);
         DB : IN  std_logic_vector(31 downto 0);
         ALUctrl : IN  std_logic_vector(2 downto 0);
         Dout : OUT  std_logic_vector(31 downto 0)
               );
    END COMPONENT;
	 
	component mux2_5bits is
	Port ( DIn0 : in  STD_LOGIC_VECTOR (4 downto 0);
		   DIn1 : in  STD_LOGIC_VECTOR (4 downto 0);
		   ctrl : in  STD_LOGIC;
		   Dout : out  STD_LOGIC_VECTOR (4 downto 0));
	end component;
	
COMPONENT Banco_MEM
    PORT(
       		ALU_out_EX : in  STD_LOGIC_VECTOR (31 downto 0); 
			ALU_out_MEM : out  STD_LOGIC_VECTOR (31 downto 0); -- instrucci�n leida en IF
         	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
    		load : in  STD_LOGIC;
			MemWrite_EX : in  STD_LOGIC;
    	    MemRead_EX : in  STD_LOGIC;
        	MemtoReg_EX : in  STD_LOGIC;
         	RegWrite_EX : in  STD_LOGIC;
			MemWrite_MEM : out  STD_LOGIC;
        	MemRead_MEM : out  STD_LOGIC;
         	MemtoReg_MEM : out  STD_LOGIC;
         	RegWrite_MEM : out  STD_LOGIC;
         	BusB_EX: in  STD_LOGIC_VECTOR (31 downto 0); -- para los store
			BusB_MEM: out  STD_LOGIC_VECTOR (31 downto 0); -- para los store
			RW_EX : in  STD_LOGIC_VECTOR (4 downto 0); -- registro destino de la escritura
         	RW_MEM : out  STD_LOGIC_VECTOR (4 downto 0);
         	-- Nuevo excepci�n
            PC_exception_EX:  in  STD_LOGIC_VECTOR (31 downto 0);
            PC_exception_MEM:  out  STD_LOGIC_VECTOR (31 downto 0);           	
         	--bits de validez
        	valid_I_EX: in STD_LOGIC;
        	valid_I_MEM: out STD_LOGIC);
    END COMPONENT;
 
    COMPONENT Banco_WB
    PORT(
        ALU_out_MEM : in  STD_LOGIC_VECTOR (31 downto 0); 
		ALU_out_WB : out  STD_LOGIC_VECTOR (31 downto 0); 
		MEM_out : in  STD_LOGIC_VECTOR (31 downto 0); 
		MDR : out  STD_LOGIC_VECTOR (31 downto 0); --memory data register
        clk : in  STD_LOGIC;
		reset : in  STD_LOGIC;
        load : in  STD_LOGIC;
		MemtoReg_MEM : in  STD_LOGIC;
        RegWrite_MEM : in  STD_LOGIC;
		MemtoReg_WB : out  STD_LOGIC;
        RegWrite_WB : out  STD_LOGIC;
        RW_MEM : in  STD_LOGIC_VECTOR (4 downto 0); -- registro destino de la escritura
        RW_WB : out  STD_LOGIC_VECTOR (4 downto 0); -- PC+4 en la etapa IDend Banco_WB;
        --bits de validez
        valid_I_WB_in: in STD_LOGIC;
        valid_I_WB: out STD_LOGIC);
    END COMPONENT; 
    
    COMPONENT counter 
 	generic (
   			size : integer := 10);
	Port ( 	clk : in  STD_LOGIC;
       		reset : in  STD_LOGIC;
       		count_enable : in  STD_LOGIC;
       		count : out  STD_LOGIC_VECTOR (size-1 downto 0));
	end COMPONENT;
-- Se�ales internas MIPS	
	CONSTANT ARIT : STD_LOGIC_VECTOR (5 downto 0) := "000001";
	signal load_PC, RegWrite_ID, RegWrite_EX, RegWrite_MEM, RegWrite_WB, RegWrite, Z, Branch_ID, RegDst_ID, RegDst_EX, ALUSrc_ID, ALUSrc_EX: std_logic;
	signal MemtoReg_ID, MemtoReg_EX, MemtoReg_MEM, MemtoReg_WB, MemWrite_ID, MemWrite_EX, MemWrite_MEM, MemRead_ID, MemRead_EX, MemRead_MEM, WE, RE: std_logic;
	signal PC_in, PC_out, four, PC4, Dirsalto_ID, IR_in, IR_ID, PC4_ID, inm_ext_EX, ALU_Src_out : std_logic_vector(31 downto 0);
	signal BusW, BusA, BusB, BusA_EX, BusB_EX, BusB_MEM, inm_ext, inm_ext_x4, ALU_out_EX, ALU_out_MEM, ALU_out_WB, Mem_out, MDR : std_logic_vector(31 downto 0);
	signal RW_EX, RW_MEM, RW_WB, Reg_Rs_ID, Reg_Rs_EX, Reg_Rt_ID, Reg_Rd_EX, Reg_Rt_EX: std_logic_vector(4 downto 0);
	signal ALUctrl_ID, ALUctrl_EX : std_logic_vector(2 downto 0);
	signal ALU_INT_out, Mux_A_out, Mux_B_out: std_logic_vector(31 downto 0);
	signal IR_op_code: std_logic_vector(5 downto 0);
	signal MUX_ctrl_A, MUX_ctrl_B : std_logic_vector(1 downto 0);
	signal salto_tomado: std_logic;
--Se�ales soluci�n
	signal parar_ID, parar_EX, RegWrite_EX_mux_out, Kill_IF, reset_ID, load_ID, load_EX, load_Mem : std_logic;
	signal Write_output, write_output_UC : std_logic;
-- Soporte Excepciones--
	signal MIPS_status, status_input: std_logic_vector(1 downto 0);
	signal PC_exception, PC_exception_MEM, PC_exception_EX, PC_exception_ID, Return_I,Exception_LR_output: std_logic_vector(31 downto 0);
	signal Exception_accepted, RTE_ID, update_status, reset_EX, reset_MEM: std_logic;													
	signal Data_Abort, Undef: std_logic;
-- Bit validez etapas
	signal valid_I_IF, valid_I_ID, valid_I_EX_in, valid_I_EX, valid_I_MEM, valid_I_WB_in, valid_I_WB: std_logic;
-- contadores
	signal cycles: std_logic_vector(15 downto 0);
	signal Ins, data_stalls, control_stalls, Exceptions, Exception_cycles: std_logic_vector(7 downto 0);
	signal inc_cycles, inc_I, inc_data_stalls, inc_control_stalls, inc_Exceptions, inc_Exception_cycles : std_logic;
--interfaz con memoria
	signal Mem_ready : std_logic;
	

begin
	-- ****************************************************************************************************
	-- Gesti�n de Excepciones: 
	--		* IRQ: es una entrada del MIPs 
	--		* Data_abort: la genera el controlador de memoria cuando recibe una direcci�n no alienada, o fuera del rango de la memoria
	--		* UNDEF: la genera la unidad de control cuando le llega una instrucci�n v�lida con un c�digo de operaci�n desconocido
	-- ****************************************************************************************************
	-------------------------------------------------------------------------------------------------------------------------------
	-- Status_register	 
	-- el registro tiene como entradas y salidas vectores de se�ales cuya longitud se indica en size. En este caso es un vector de tama�o 2
	-- El bit m�s significativo permite deshabilitar (valor 1) o habilitar las excepciones (valor 0)
	-- El bit menos significativo informa si estamos en modo Excepci�n o estamos en modo normal
	
	status_reg: reg generic map (size => 2)
			port map (	Din => status_input, clk => clk, reset => reset, load => update_status, Dout => MIPS_status);
	------------------------------------------------------------------------------------
	-- Completar: falta la l�gica que detecta cu�ndo se va a procesar Una excepci�n: cuando se recibe una de las se�ales 
	-- (IRQ, Data_abort y Undef) y las excepciones est�n habilitadas (MIPS_status(1)='0')
	Exception_accepted <= '1' when ((IRQ = '1' or Data_Abort = '1' or UNDEF = '1') and (MIPS_status(1) = '0')) else '0';

	------------------------------------------------------------------------------------
	-- Completar: falta la l�gica que gestiona update_status. Dise�adla.
	update_status	<= '1' when ((Exception_accepted = '1') or (RTE_ID = '1' and valid_I_ID = '1')) else '0';
	-- Fin completar;
	------------------------------------------------------------------------------------
				
	-- multiplexor para elegir la entrada del registro de estado
	-- En este procesador s�lo hay dos opciones ya que al entrar en modo excepci�n se deshabilitan las excepciones:
	-- 		* "11" al entrar en una IRQ (Excepciones deshabilitadas y modo Excepci�n)
	--		* "00" en el resto de casos
	-- Podr�a hacerse con un bit, pero usamos dos para permitir ampliaciones)
	status_input	<= 	"11" when (Exception_accepted = '1') else "00";							
	
	------------------------------------------------------------------------------------
	-- Al procesar una excepci�n las instrucciones que est�n en Mem y WB contin�an su ejecuci�n. El resto se matan
	-- Para retornar se debe eligir la siguiente instrucci�n v�lida. Para ello tenemos sus direcciones almacenadas en:
	-- PC_exception_EX y PC_exception_ID, y sus bits de validez en valid_I_EX y valid_I_ID
	-- Si no hay v�lidas se almacena el valor del PC.
	Return_I	<= 	PC_exception_EX when (valid_I_EX = '1') else 	
					PC_exception_ID when (valid_I_ID = '1') else
					PC_out;		
	------------------------------------------------------------------------------------	
	-- Exception_LR: almacena la direcci�n a la que hay que retornar tras una excepci�n	 
	-- Vamos a guardar la direcci�n seleccionada en el MUX de arriba
	Exception_LR: reg generic map (size => 32)
			port map (	Din => Return_I, clk => clk, reset => reset, load => Exception_accepted, Dout => Exception_LR_output);
	
	
	-- ****************************************************************************************************
	pc: reg generic map (size => 32)
			port map (	Din => PC_in, clk => clk, reset => reset, load => load_PC, Dout => PC_out);
	
	------------------------------------------------------------------------------------
	-- Completar:
	-- load_pc vale '1' porque en la versi�n actual el procesador no para nunca
	-- Si queremos detener una instrucci�n en la etapa fetch habr� que ponerlo a '0'
	-- Si paramos en ID, tambi�n hay que parar en IF. Parar_ID nos avisa de esto.
	-- Importante: Puede ser que Parar_ID se active, y a la vez se procese una excepci�n: �hay que actualizar el pc?
	load_PC <= '1' when (parar_ID = '0' or Exception_accepted = '1') else '0';
	-- Fin completar;
	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	 -- la x en x"00000004" indica que est� en hexadecimal
	adder_4: adder32 port map (Din0 => PC_out, Din1 => x"00000004", Dout => PC4);
	------------------------------------------------------------------------------------
	-- Completar: sustituir los (--completar) por la condici�n correcta y descomentar el c�digo. Ver ejemplo para el data abort.
	-- Este c�digo es el mux de entrada al PC: elige entre PC+4, la direcci�n de salto generada en ID, la direcci�n de la rutina de tratamiento de la excepci�n, o la direcci�n de retorno de la excepci�n
	-- El orden asigna prioridad si se cumplen dos o m�s condiciones			
	
	PC_in <= 	x"00000008" 		when (Exception_accepted = '1') and (Data_abort = '1') else -- Si llega un data abort y est� habilitado saltamos a la direcci�n 0x00000008
				x"0000000C" 		when (Exception_accepted = '1') and (UNDEF = '1') else -- Si llega un UNDEF saltamos a la direcci�n 0x0000000C
				x"00000004" 		when (Exception_accepted = '1') and (IRQ = '1') else -- Si llega una IRQ saltamos a la dirección 0x00000004
				Exception_LR_output when (salto_tomado = '1' and RTE_ID = '1') else --@ retorno. Si es una RTE volvemos a la @ que ten�amos almacenada en el Exception_LR		
				Dirsalto_ID 		when (salto_tomado = '1') else --@ Salto 
				PC4; -- PC+4
				
								
	------------------------------------------------------------------------------------
	-- Memoria de instrucciones. Tiene el puerto de escritura inhabilitado (WE='0')
	Mem_I: memoriaRAM_I PORT MAP (CLK => CLK, ADDR => PC_out, Din => x"00000000", WE => '0', RE => '1', Dout => IR_in);
	------------------------------------------------------------------------------------
	-- Reset del banco ID: reseteamos el banco si hay una excepci�n aceptada, ya que en ese caso se matan las intrucciones en IF, ID y EX 
	reset_ID <= (reset or Exception_accepted);
	
	--------------------------------------------------------------
	-- anulaci�n de la instrucci�n. Si en ID se detecta que la instrucci�n de IF no debe ejecutarse se desactiva la se�al valid_I_IF
	valid_I_IF <= not(kill_IF);
	-----------------------------------------------------------------
	-- Para detener la etapa ID 
	load_ID <= not(parar_ID);

	Banco_IF_ID: Banco_ID port map (	IR_in => IR_in, PC4_in => PC4, clk => clk, reset => reset_ID, load => load_ID, IR_ID => IR_ID, PC4_ID => PC4_ID, 
										--Nuevo
										valid_I_IF => valid_I_IF, valid_I_ID => valid_I_ID,  
										PC_exception => PC_out, PC_exception_ID => PC_exception_ID); 
	--
	------------------------------------------Etapa ID-------------------------------------------------------------------
	Reg_Rs_ID <= IR_ID(25 downto 21);
	Reg_Rt_ID <= IR_ID(20 downto 16);
	--------------------------------------------------
	-- BANCOS DE REGISTROS
	
	-- s�lo se escribe si la instrucci�n en WB es v�lida
	RegWrite <= RegWrite_WB and valid_I_WB;
	
	INT_Register_bank: BReg PORT MAP (clk => clk, reset => reset, RA => Reg_Rs_ID, RB => Reg_Rt_ID, RW => RW_WB, BusW => BusW, RegWrite => RegWrite, BusA => BusA, BusB => BusB);
	
	-------------------------------------------------------------------------------------
	sign_ext: Ext_signo port map (inm => IR_ID(15 downto 0), inm_ext => inm_ext);
	
	two_bits_shift: two_bits_shifter	port map (Din => inm_ext, Dout => inm_ext_x4);
	
	adder_dir: adder32 port map (Din0 => inm_ext_x4, Din1 => PC4_ID, Dout => Dirsalto_ID);
	
	Z <= '1' when (busA=busB) else '0';
	
	-------------------------------------------------------------------------------------
	IR_op_code <= IR_ID(31 downto 26);
	
	-- Si la Instrucci�n en ID no es v�lida, todas las se�ales son 0
	UC_seg: UC port map (valid_I_ID => valid_I_ID, IR_op_code => IR_op_code, Branch => Branch_ID, RegDst => RegDst_ID,  ALUSrc => ALUSrc_ID, MemWrite => MemWrite_ID,  
								MemRead => MemRead_ID, MemtoReg => MemtoReg_ID, RegWrite => RegWrite_ID, 
								--Se�ales nuevas
								-- RTE
								RTE => RTE_ID,
								-- Write_output
								undef => undef,
								write_output => write_output_UC);
	
	------------------------------------------------------------------------------------
	-- Completar:
	-- Write_output da la orden de escribir en el registro de salida. �Cuidado, no se deben escribir datos equivocados!
	-- IMPORTANTE: si hay dependencias de datos no hay que escribir en la salida
	-- A�adid lo necesario para evitar escrituras incorrectas
	Write_output <= '1' when (write_output_UC = '1' and parar_ID = '0') else '0';			
	-- Fin completar;
	------------------------------------------------------------------------------------							
	-- Salto tomado se debe activar cada vez que la instrucci�n en D produzca un salto en la ejecuci�n.
	-- Eso incluye los saltos tomados en los BEQs (Z AND Branch_ID) y los saltos debidos a una RTE
	-- IMPORTANTE: si la instrucci�n no es v�lida no se salta
	salto_tomado <= ((Z AND Branch_ID) or RTE_ID) AND valid_I_ID;
								
	------------------------Unidad de detenci�n-----------------------------------
	-- Deb�is completar la unidad para que genere las siguientes se�ales correctamente:
	-- Kill_IF: mata la instrucci�n que se est� leyendo en la etapa IF (para que no se ejecute)
	-- parar_ID: detiene la ejecuci�n de las etpas ID e IF cuando hay riesgos
	-- parar_EX: se utiliza para parar las etapas IF, ID y EX cuando la memoria no puede realizar la operaci�n solicitada en el ciclo actual (es decir cuando Mem_ready es 0). En el primer proyecto no hace flata parar.
	-- IMPORTANTE: para detectar un riesgo, primero comprobar que las instrucciones implicadas son v�lidas. �Las instrucciones invalidas no generan riesgos porque no son instrucciones que se vayan a ejecutar
	-------------------------------------------------------------------------------------
	
	Unidad_detencion_riesgos: UD port map (	valid_I_ID => valid_I_ID, valid_I_EX => valid_I_EX, valid_I_MEM => valid_I_MEM, Reg_Rs_ID => Reg_Rs_ID, Reg_Rt_ID => Reg_Rt_ID, MemRead_EX => MemRead_EX, RW_EX => RW_EX, RegWrite_EX => RegWrite_EX,
											RW_Mem => RW_Mem, RegWrite_Mem => RegWrite_Mem, IR_op_code => IR_op_code, salto_tomado => salto_tomado,
											kill_IF => kill_IF, parar_ID => parar_ID,
											Mem_ready => Mem_ready, parar_EX => parar_EX);
								
	-- Si nos paran en ID marcamos como invalida la instrucci�n que mandamos a la etapa EX
	-- La instrucci�n de EX ser� v�lida el pr�ximo ciclo, si lo es la de ID y no hay detenci�n
	
	valid_I_EX_in	<=  valid_I_ID and not( parar_ID);				
				
	-------------------------------------------------------------------------------------
	-- si la operaci�n es aritm�tica (es decir: IR_op_code= "000001") miro el campo funct
	-- como s�lo hay 4 operaciones en la alu, basta con los bits menos significativos del campo func de la instrucci�n	
	-- si no es aritm�tica le damos el valor de la suma (000)
	ALUctrl_ID <= IR_ID(2 downto 0) when IR_op_code= ARIT else "000"; 
	
	
	-- Reset del banco EX: reseteamos el banco si hay una excepci�n aceptada, ya que en ese caso se matan las intrucciones en IF, ID y EX
	reset_EX <= (reset or Exception_accepted);
	-- Banco ID/EX parte de enteros
	load_EX <= not(parar_EX);
	Banco_ID_EX: Banco_EX PORT MAP ( 	clk => clk, reset => reset_EX, load => load_EX, busA => busA, busB => busB, busA_EX => busA_EX, busB_EX => busB_EX,
						RegDst_ID => RegDst_ID, ALUSrc_ID => ALUSrc_ID, MemWrite_ID => MemWrite_ID, MemRead_ID => MemRead_ID,
						MemtoReg_ID => MemtoReg_ID, RegWrite_ID => RegWrite_ID, RegDst_EX => RegDst_EX, ALUSrc_EX => ALUSrc_EX,
						MemWrite_EX => MemWrite_EX, MemRead_EX => MemRead_EX, MemtoReg_EX => MemtoReg_EX, RegWrite_EX => RegWrite_EX,
						-- Nuevo (para la anticipaci�n)
						Reg_Rs_ID => Reg_Rs_ID,
						Reg_Rs_EX => Reg_Rs_EX,
						--Fin nuevo
						ALUctrl_ID => ALUctrl_ID, ALUctrl_EX => ALUctrl_EX, inm_ext => inm_ext, inm_ext_EX=> inm_ext_EX,
						Reg_Rt_ID => IR_ID(20 downto 16), Reg_Rd_ID => IR_ID(15 downto 11), Reg_Rt_EX => Reg_Rt_EX, Reg_Rd_EX => Reg_Rd_EX, 
						--Nuevo
						valid_I_EX_in => valid_I_EX_in, valid_I_EX => valid_I_EX, 
						PC_exception_ID => PC_exception_ID, PC_exception_EX => PC_exception_EX); --Sol: para llevar el PC a la etapa MEM		
	
	------------------------------------------Etapa EX-------------------------------------------------------------------
	---------------------------------------------------------------------------------
	-- Unidad de anticipaci�n de enteros incompleta. Deb�is dise�adla teniendo en cuenta que instrucciones lee y escribe cada instrucci�n
	-- Entradas: Reg_Rs_EX, Reg_Rt_EX, RegWrite_MEM, RW_MEM, RegWrite_WB, RW_WB
	-- Salidas: MUX_ctrl_A, MUX_ctrl_B
	Unidad_Ant_INT: UA port map (	valid_I_MEM => valid_I_MEM, valid_I_WB => valid_I_WB, Reg_Rs_EX => Reg_Rs_EX, Reg_Rt_EX => Reg_Rt_EX, RegWrite_MEM => RegWrite_MEM,
									RW_MEM => RW_MEM, RegWrite_WB => RegWrite_WB, RW_WB => RW_WB, MUX_ctrl_A => MUX_ctrl_A, MUX_ctrl_B => MUX_ctrl_B);
	---------------------------------------------------------------------------------
	-- Muxes para la anticipaci�n
	Mux_A: mux4_1_32bits port map  ( DIn0 => BusA_EX, DIn1 => ALU_out_MEM, DIn2 => busW, DIn3 => x"00000000", ctrl => MUX_ctrl_A, Dout => Mux_A_out);
	Mux_B: mux4_1_32bits port map  ( DIn0 => BusB_EX, DIn1 => ALU_out_MEM, DIn2 => busW, DIn3 => x"00000000", ctrl => MUX_ctrl_B, Dout => Mux_B_out);
	
	----------------------------------------------------------------------------------
	
	
	muxALU_src: mux2_1 port map (Din0 => Mux_B_out, DIn1 => inm_ext_EX, ctrl => ALUSrc_EX, Dout => ALU_Src_out);
	
	ALU_MIPs: ALU PORT MAP ( DA => Mux_A_out, DB => ALU_Src_out, ALUctrl => ALUctrl_EX, Dout => ALU_out_EX);
	
	
	mux_dst: mux2_5bits port map (Din0 => Reg_Rt_EX, DIn1 => Reg_Rd_EX, ctrl => RegDst_EX, Dout => RW_EX);
	
	-- No reseteamos el banco si hay una excepci�n porque podr�a llegar a mitad de una transferencia y corromper la MC 
	reset_MEM <= (reset);
	--si paramos en EX no hay que cargar una instrucci�n nueva en la etap MEM
	load_MEM <= not(parar_EX);
	Banco_EX_MEM: Banco_MEM PORT MAP ( ALU_out_EX => ALU_out_EX, ALU_out_MEM => ALU_out_MEM, clk => clk, reset => reset_MEM, load => load_MEM, MemWrite_EX => MemWrite_EX,
													MemRead_EX => MemRead_EX, MemtoReg_EX => MemtoReg_EX, RegWrite_EX => RegWrite_EX, MemWrite_MEM => MemWrite_MEM, MemRead_MEM => MemRead_MEM,
													MemtoReg_MEM => MemtoReg_MEM, RegWrite_MEM => RegWrite_MEM, 
													--sol:
													BusB_EX => Mux_B_out, -- antes pon�a BusB_EX, pero entonces los sw no pod�an hacer cortos en rt
													--fin sol
													BusB_MEM => BusB_MEM, RW_EX => RW_EX, RW_MEM => RW_MEM,
													-- Nuevo
													valid_I_EX => valid_I_EX, valid_I_MEM => valid_I_MEM,
													PC_exception_EX => PC_exception_EX, PC_exception_MEM => PC_exception_MEM); --Sol: para llevar el PC a la etapa MEM	
													
	
	--
	------------------------------------------Etapa MEM-------------------------------------------------------------------
	--
	
	WE <= MemWrite_MEM and valid_I_MEM; --s�lo se escribe si es una instrucci�n v�lida
	RE <= MemRead_MEM and valid_I_MEM; --s�lo se lee si es una instrucci�n v�lida
	
	Mem_D: Data_Memory_Subsystem PORT MAP (CLK => CLK, ADDR => ALU_out_MEM, Din => BusB_MEM, WE => MemWrite_MEM, RE => MemRead_MEM, reset => reset, IO_input => IO_input, Mem_ready => Mem_ready, Dout => Mem_out, Data_abort => Data_abort);

	
	-- parar_EX indica que hay que detener la etapa de memoria (se usa m�s adelante cuando la jerarqu�a de memoria sea m�s compleja)
	-- La instrucci�n en WB ser� v�lida el pr�ximo ciclo si la instrucci�n en Mem es v�lida y no hay que parar 
	valid_I_WB_in <= valid_I_MEM and not(parar_EX);
	
	Banco_MEM_WB: Banco_WB PORT MAP ( 	ALU_out_MEM => ALU_out_MEM, ALU_out_WB => ALU_out_WB, Mem_out => Mem_out, MDR => MDR, clk => clk, reset => reset, load => '1', 
										MemtoReg_MEM => MemtoReg_MEM, RegWrite_MEM => RegWrite_MEM, MemtoReg_WB => MemtoReg_WB, RegWrite_WB => RegWrite_WB, 
										RW_MEM => RW_MEM, RW_WB => RW_WB,
										-- Nuevo
										valid_I_WB_in => valid_I_WB_in, valid_I_WB => valid_I_WB);
	
	--
	------------------------------------------Etapa WB-------------------------------------------------------------------
	--											
	mux_busW: mux2_1 port map (Din0 => ALU_out_WB, DIn1 => MDR, ctrl => MemtoReg_WB, Dout => busW);
	
-- *********************************************************************************************	-----------
	-- IO_output son 32 pines de salida para que el MIPS pueda comunicarse con el exterior
	-- En la etapa ID de la instrucci�n WRO Rs el contenido de Rs se carga en el registro de salida que se puede ver desde el exterior
	output_reg: reg generic map (size => 32)
				port map (	Din => BusA, clk => clk, reset => reset, load => write_output, Dout => IO_output);
--------------------------------------------------------------------------------------------------
----------- Contadores de eventos
-------------------------------------------------------------------------------------------------- 
	-- Contador de ciclos totales
	cont_cycles: counter 	generic map (size => 16)
							port map (clk => clk, reset => reset, count_enable => inc_cycles, count => cycles);
	-- Contador de Instrucciones ejecutadas
	cont_I: counter 		generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_I, count => Ins);
	-- Contador de detenciones por riesgos de datos						
	cont_data_stalls: counter generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_data_stalls, count => data_stalls);
	-- Contador de detenciones por riesgos de control							
	cont_control_stalls: counter generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_control_stalls, count => control_stalls);
	-- Contador de n�mero de excepciones							
	cont_Exceptions: counter 		generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_Exceptions, count => Exceptions);
	-- Contador de ciclos ejecutando excepciones						
	cont_Exceptions_cycles : counter generic map (size => 8)
							port map (clk => clk, reset => reset, count_enable => inc_Exception_cycles, count => Exception_cycles);
	------------------------------------------------------------------------------------
	-- Completar:
	inc_cycles <= '1';--Done
	inc_I <= valid_I_WB; --completar
	inc_data_stalls <= parar_ID or parar_EX; --completar
	inc_control_stalls <= kill_IF; --completar
	inc_Exceptions <= Exception_accepted;--completar
	inc_Exception_cycles <= MIPS_status(1);	--completar	
	-- Fin completar;
	------------------------------------------------------------------------------------			
end Behavioral;

