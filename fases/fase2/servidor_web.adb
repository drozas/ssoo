-- ***********************************************************
-- Practica de SSOO: programacion de un servidor web en Ada95
-- Fase actual: fase 2
-- Autor: David Rozas
-- ***********************************************************

WITH UNIX; USE UNIX;
WITH net; USE net; 
WITH ada.text_io;
WITH ada.strings.unbounded;

PROCEDURE servidor_web IS
	PACKAGE ASU RENAMES Ada.Strings.Unbounded;
	PACKAGE TXT RENAMES Ada.text_io;
	
	conex: integer;
	res_aux: integer;
	direcc: infoPeticion_type; 
	title: ASU.unbounded_string;
	

BEGIN
	inicializar(9999); --Ponemos a escuchar el puerto 9999
	
	LOOP
	
		conex:=aceptar_conexion_navegador; --recoge descriptor de conexion
		direcc:= leer_peticion(conex);-- e inmediatamente leemos la peticion
		
		res_aux:= write(conex, "Hola", 4); --saludamos
	
		IF res_aux=-1 THEN
			TXT.put_line("Error en la escritura");
		END IF;
		
		title:= direcc.url; --y ahora cogemos su campo url
		res_aux:= write(conex, ", pides " & ASU.To_String(title), ASU.length(title) + 8);
	
		IF res_aux=-1 THEN
			TXT.put_line("Error en la escritura");
		END IF;
	
		res_aux:=close(conex);
	
		IF res_aux=-1 THEN
			TXT.put_line("No fue posible cerrar la conexion");
		END IF;

	END LOOP;

END servidor_web;
