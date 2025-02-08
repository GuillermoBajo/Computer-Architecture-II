 ---------------------------------------------------------------------------------

-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:38:18 05/15/2014 
-- Design Name: 
-- Module Name:    UC_slave - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: la UC incluye un contador de 2 bits para llevar la cuenta de las transferencias de bloque y una m�quina de estados
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity UC_MC is
    Port ( 	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			RE : in  STD_LOGIC; --RE y WE son las ordenes del MIPs
			WE : in  STD_LOGIC;
			hit0 : in  STD_LOGIC; --se activa si hay acierto en la via 0
			hit1 : in  STD_LOGIC; --se activa si hay acierto en la via 1
			addr_non_cacheable: in STD_LOGIC; --indica que la direcci�n no debe almacenarse en MC. En este caso porque pertenece a la scratch
			bus_TRDY : in  STD_LOGIC; --indica que el esclavo no puede realizar la operaci�n solicitada en este ciclo
			Bus_DevSel: in  STD_LOGIC; --indica que el esclavo ha reconocido que la direcci�n est� dentro de su rango
			via_2_rpl :  in  STD_LOGIC; --indica que via se va a reemplazar
			Bus_grant :  in  STD_LOGIC; --indica la concesi�n del uso del bus
			Bus_req :  out  STD_LOGIC; --indica la petici�n al �rbitro del uso del bus
			-- Nueva se�al que indica que la direcci�n solicitada es de un registro de MC
			internal_addr: in STD_LOGIC;
			-- Nueva se�al que indica que la direcci�n que env�a el MIPS no est� alineada
			unaligned : in STD_LOGIC;
			
			-- Nueva se�al de error
			Mem_ERROR: out std_logic; -- Se activa si en la ultima transferencia el esclavo no respondi� a su direcci�n o la direcci�n solicitada no est� alineada
			load_addr_error: out std_logic; --para controlar el registro que guarda la direcci�n que caus� error
			--Interfaz con el bus
            MC_WE0 : out  STD_LOGIC; -- write enable de la VIA 0 y 1
            MC_WE1 : out  STD_LOGIC;
            MC_bus_Rd_Wr : out  STD_LOGIC; -- 1 para escritura en Memoria y 0 para lectura
            MC_tags_WE : out  STD_LOGIC; -- para escribir la etiqueta en la memoria de etiquetas
			palabra : out  STD_LOGIC_VECTOR (1 downto 0);--indica la palabra actual dentro de una transferencia de bloque (1�, 2�...)
            mux_origen: out STD_LOGIC; -- Se utiliza para elegir si el origen de la direcci�n y el dato es el Mips (cuando vale 0) o la UC y el bus (cuando vale 1)
            ready : out  STD_LOGIC; -- indica si podemos procesar la orden actual del MIPS en este ciclo. En caso contrario habr� que detener el MIPs
            -- ?
			block_addr : out  STD_LOGIC; -- indica si la direcci�n a enviar es la de bloque (rm) o la de palabra (w)
			MC_send_addr_ctrl : out  STD_LOGIC; --ordena que se env�en la direcci�n y las se�ales de control al bus
            MC_send_data : out  STD_LOGIC; --ordena que se env�en los datos
            Frame : out  STD_LOGIC; --indica que la operaci�n no ha terminado
			last_word : out  STD_LOGIC; --indica que es el �ltimo dato de la transferencia
            mux_output: out  std_logic_vector(1 downto 0); -- para elegir si le mandamos al procesador la salida de MC (valor 0),los datos que hay en el bus (valor 1), o un registro interno( valor 2)
			inc_m : out STD_LOGIC; -- indica que ha habido un fallo
			inc_w : out STD_LOGIC -- indica que ha habido una escritura	
           );
end UC_MC;

architecture Behavioral of UC_MC is
 
component counter is 
	generic (
	   size : integer := 10
	);
	Port ( clk : in  STD_LOGIC;
	       reset : in  STD_LOGIC;
	       count_enable : in  STD_LOGIC;
	       count : out  STD_LOGIC_VECTOR (size-1 downto 0)
		);
end component;		           
-- Ejemplos de nombres de estado. No hay que usar estos. Nombrad a vuestros estados con nombres descriptivos. As� se facilita la depuraci�n
type state_type is (Inicio, Arbitraje, No_cacheable, Traer_bloque, Write_through); 
type error_type is (memory_error, No_error); 
signal state, next_state : state_type; 
signal error_state, next_error_state : error_type; 
signal last_word_block: STD_LOGIC; --se activa cuando se est� pidiendo la �ltima palabra de un bloque
-- signal one_word: STD_LOGIC; --se activa cuando s�lo se quiere transferir una palabra
signal count_enable: STD_LOGIC; -- se activa si se ha recibido una palabra de un bloque para que se incremente el contador de palabras
signal hit: std_logic;
signal palabra_UC : STD_LOGIC_VECTOR (1 downto 0);
begin

hit <= hit0 or hit1;	
 
--el contador nos dice cuantas palabras hemos recibido. Se usa para saber cuando se termina la transferencia del bloque y para direccionar la palabra en la que se escribe el dato leido del bus en la MC
word_counter: counter 	generic map (size => 2)
						port map (clk, reset, count_enable, palabra_UC); --indica la palabra actual dentro de una transferencia de bloque (1�, 2�...)

last_word_block <= '1' when palabra_UC="11" else '0';--se activa cuando estamos pidiendo la �ltima palabra

palabra <= palabra_UC;



   State_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            state <= Inicio;
         else
            state <= next_state;
         end if;        
      end if;
   end process;
 
---------------------------------------------------------------------------
-- 2023
-- M�quina de estados para el bit de error
---------------------------------------------------------------------------

error_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then           
            error_state <= No_error;
        else
            error_state <= next_error_state;
         end if;   
      end if;
   end process;
   
--Salida Mem Error
Mem_ERROR <= '1' when (error_state = memory_error) else '0';

--Mealy State-Machine - Outputs based on state and inputs
   
--MEALY State-Machine - Outputs based on state and inputs
OUTPUT_DECODE: process (state, hit, last_word_block, bus_TRDY, RE, WE, Bus_DevSel, Bus_grant, via_2_rpl, hit0, hit1, addr_non_cacheable, internal_addr, unaligned)
begin
			  -- valores por defecto, si no se asigna otro valor en un estado valdr�n lo que se asigna aqu�
	MC_WE0 <= '0';
	MC_WE1 <= '0';
	MC_bus_Rd_Wr <= '0';
	MC_tags_WE <= '0';
    ready <= '0';
    mux_origen <= '0';
    MC_send_addr_ctrl <= '0';
    MC_send_data <= '0';
    next_state <= state;  -- por defecto se mantiene el estado
	count_enable <= '0';
	Frame <= '0';
	block_addr <= '0';
	inc_m <= '0';
	inc_w <= '0';
	Bus_req <= '0';
	-- one_word <= '0';
	mux_output <= "11";
	last_word <= '0'; 

	next_error_state <= error_state; -- por defecto se mantiene el estado
	load_addr_error <= '0';
				
    if (state = Inicio) then
    	if (RE= '0' and WE= '0') then -- si no piden nada no hacemos nada
			next_state <= Inicio;
			ready <= '1';
		elsif (state = Inicio) and ((RE= '1') or (WE= '1')) and  (unaligned ='1') then -- si el procesador quiere leer una direcci�n no alineada
			-- Se procesa el error y se ignora la solicitud
			next_state <= Inicio;
			ready <= '1';
			load_addr_error <= '1';
			next_error_state <= memory_error; --�ltima direcci�n incorrecta (no alineada)
	    elsif (state = Inicio) and (RE= '1' and  internal_addr ='1') then -- si quieren leer un registro de la MC se lo mandamos
	    	next_state <= Inicio;
			ready <= '1';
			mux_output <= "10"; -- Completar. "00" es el valor por defecto. �Qu� valor hay que poner?
			next_error_state <= No_error; --Cuando se lee el registro interno el controlador quita la se�al de error
		elsif (state = Inicio) and (RE= '1' and  hit='1') then -- si piden y es acierto de lectura mandamos el dato
	        next_state <= Inicio;
			ready <= '1';
			mux_output <= "00"; -- Completar. Es el valor por defecto. �Qu� valor hay que poner? La salida es un dato almacenado en la MC
		elsif (state = Inicio) and ((WE = '1') or (RE = '1' and hit = '0')) then -- fallo de lectura/Escritura o uso de MScratch
			Bus_req <= '1';
			ready <= '0';
			next_state <= Arbitraje;
		end if;	
	end if;
	
	if (state = Arbitraje) then
		Bus_req <= '1'; 
		
		if (Bus_grant = '0') then -- si no nos conceden el bus
			next_state <= Arbitraje;
	
		else
			MC_send_addr_ctrl <= '1'; -- mandamos la direcci�n
			MC_bus_Rd_Wr <= WE and (hit or addr_non_cacheable); -- leemos o escribimos de memoria
			
			if (Bus_DevSel = '0') then
				load_addr_error <= '1';
				ready <= '1';
				next_state <= Inicio;
				next_error_state <= memory_error;
			else
				if(addr_non_cacheable = '1') then -- RE/WE no cacheables
					next_state <= No_cacheable;

				elsif ((RE = '1' or WE = '1') and hit = '0') then 
					block_addr <= '1';
					next_state <= Traer_Bloque;

				elsif(WE = '1' and hit = '1') then	-- Write hit
					next_state <= Write_through;
				end if;
			end if;
		end if;
	end if;

	if (state = No_cacheable) then
		Frame <= '1';
		if (Bus_TRDY = '0') then
			next_state <= No_cacheable;
		else 
			if (RE = '1') then
					mux_output <= "01";
			elsif (WE = '1') then
					MC_send_data <= '1';
					inc_w <= '1';
			end if;
			ready <= '1';
			next_state <= Inicio;
		end if;
	end if;

	-- elsif ((RE = '1' or WE = '1') and hit = '0') then 	
	if (state = Traer_Bloque) then
		Frame <= '1';

		if (Bus_TRDY = '0') then
			next_state <= Traer_Bloque;
		else
			mux_origen <= '1'; -- datos de MP
			MC_WE0 <= not via_2_rpl;
			MC_WE1 <= via_2_rpl;
			count_enable <= '1';				

			if (last_word_block = '0') then
				next_state <= Traer_Bloque;					
			else 
				MC_tags_WE <= '1'; 
				last_word <= '1'; 
				inc_m <= '1';
				
				if (WE = '1') then
					next_state <= Arbitraje;
				else -- RE = '1'
					next_state <= Inicio;
				end if;
			end if;
		end if;
	end if;

	if (state = Write_through) then
		Frame <= '1';
		if (Bus_TRDY = '0') then
			next_state <= Write_through;
		else
			MC_send_data <= '1';
			mux_origen <= '0';
			last_word <= '1';
			MC_WE0 <= hit0;
			MC_WE1 <= hit1;
			inc_w <= '1';
			ready <= '1';
			next_state <= Inicio;
		end if;
	end if;
   end process;
end Behavioral;
