-- ***********************************************************
-- Practica de SSOO: programacion de un servidor web en Ada95
-- Fase actual: fase 3
-- Autor: David Rozas
-- ***********************************************************

WITH UNIX; USE UNIX;
WITH net; USE net;
WITH ada.text_io;
WITH ada.strings.unbounded; use Ada.Strings.Unbounded;
--WITH ada.strings.aliased;

PROCEDURE servidor_web IS

        -- Renombramientos y ctes
        PACKAGE ASU RENAMES Ada.Strings.Unbounded;
        PACKAGE TXT RENAMES Ada.text_io;
        --PACKAGE ASA RENAMES ada.strings.aliased;
        MAX_TAM_FICH: CONSTANT integer:= (5*1024);

        -- Variables
        conex_fd: Integer;
        res_aux: integer;
        direcc: infoPeticion_type;
        title: ASU.unbounded_string;
        directorio: ASU.unbounded_string;
        desc_fich:integer;
        nBytesLect:integer;
        buffer: aliased String:=(1..MAX_TAM_FICH =>' ');
        Raiz: ASU.Unbounded_String;

BEGIN
        inicializar(9999); --Ponemos a escuchar el puerto 9999

        LOOP

                conex_fd:=aceptar_conexion_navegador; --recoge descriptor de conexion
                direcc:= leer_peticion(conex_fd);-- e inmediatamente leemos la peticion
                title:= direcc.url; --y ahora cogemos su campo url
                --Directorio:= GetEnv("HOME") & "/web" & Title;
                directorio:= ASU.To_Unbounded_String(Getenv("HOME")) & ASU.To_Unbounded_String("/web") & title;

                desc_fich:=open(ASU.to_string(directorio),o_rdonly); --apertura del fich

                IF desc_fich=-1 THEN
                        TXT.put_line("Error al intentar abrir el fichero en modo lectura");
                ELSE
                        nBytesLect:= read(desc_fich, buffer'unchecked_access,MAX_TAM_FICH);

                        IF nBytesLect=-1 THEN --si dio -1

                                        IF ERRNO = EISDIR THEN -- o es un directorio
                                                res_aux:=write(conex_fd, "Es directorio " & ASU.to_string(title), ASU.length(title)+14);

                                                IF res_aux=-1 THEN
                                                        TXT.put_line("Error de escritura");
                                                END IF;

                                        ELSE --o si no, hubo error de lectura
                                                TXT.put_line("Error al intentar leer");
                                        END IF;

                        ELSE -- si no, es q es un fichero, y lo escribimos en el desc_conex

                                res_aux:=write(conex_fd, buffer, nBytesLect);

                                        IF res_aux=-1 THEN
                                                TXT.put_line("Error al intentar escribir");
                                        END IF;

                        END IF;

                END IF;

                res_aux:=close(desc_fich); --cerramos el fich

                IF res_aux=-1 THEN
                        TXT.put_line("Error al intentar cerrar el fichero");
                END IF;

                res_aux:=close(conex_fd); --cerramos la conexion

                IF res_aux=-1 THEN
                        TXT.put_line("No fue posible cerrar la conexion");
                END IF;

        END LOOP;

END servidor_web;
