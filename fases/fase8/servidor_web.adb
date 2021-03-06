-- ***********************************************************
-- Practica de SSOO: programacion de un servidor web en Ada95
-- Fase actual: fase 7
-- Autor: David Rozas
-- ***********************************************************

WITH UNIX; USE UNIX;
WITH net; USE net;
WITH ada.text_io;
WITH ada.strings.unbounded; use Ada.Strings.Unbounded;

PROCEDURE servidor_web IS

        -- Renombramientos y ctes
        PACKAGE ASU RENAMES Ada.Strings.Unbounded;
        PACKAGE TXT RENAMES Ada.text_io;
        --PACKAGE ASA RENAMES ada.strings.aliased;
        MAX_TAM_FICH: CONSTANT integer:= (5*1024);


-- ************************************************************************************************
-- Procedimientos y funciones auxiliares:
-- ***********************************************************************************************
procedure VerError (Num_Error: Integer) is
begin
   if Num_Error=-1 then
      TXT.Put_Line("Se produjo un error en alguna llamada al sistema");
   end if;
end;

function DameTitle (direccion: InfoPeticion_Type) return ASU.Unbounded_String is
   Title:ASU.Unbounded_String;
begin
   Title:=Direccion.Url;
   return Title;
end;

procedure MatarPadre (Pid:Integer) is
Res_Aux:Integer;
begin
   res_aux:=KILL(pid,SIGTERM); --le invitamos a morirse
   VerError(Res_Aux);
   res_aux:=SLEEP(2); --dormimos dos sg
   res_aux:=KILL(pid,SIGKILL); --si no se suicido, lo matamos
   VerError(Res_Aux);
end;

procedure TratarStat is
Res_Aux, Pid_Aux:Integer;
begin
   Pid_Aux:= FORK;
   case Pid_Aux is
      when -1 =>
         TXT.Put_Line("Error al crear el proceso hijo (en stat)");
      when 0 =>
         Res_Aux:= EXECLP(GETENV("HOME") & "/ssoo/estado_web","");
         VerError(Res_Aux);
       when others =>
         null; -- si es el padre, no hacemos nada
   end case;
end;

-- ***********************************************************************************************



        -- Variables
        conex_fd: Integer;
        res_aux: integer;
        direcc: infoPeticion_type;
        title: ASU.unbounded_string;
        directorio: ASU.unbounded_string;--se refiere a ruta
        desc_fich:integer;
        nBytesLect:integer;
        buffer: aliased String:=(1..MAX_TAM_FICH =>' ');
        Raiz: ASU.Unbounded_String;
        estructura_stat: stat_rec_ptr_type;
        res_aux2:integer;
        directorio_fd: dirhandle; --es el directorio en si
        directorio_actual: ASU.unbounded_string; --para mostrar el contenido
        pid: integer;
        signal_fd:int_proc;
        pid_aux:integer;


BEGIN
        INICIALIZAR(9999); --Ponemos a escuchar el puerto 9999
        signal_fd:= SIGNAL(SIGCHLD, SIG_IGN); --ignoramos se�al sigchld



        LOOP
           conex_fd:=ACEPTAR_CONEXION_NAVEGADOR; --recoge descriptor de conexion
           pid:= FORK; --creacion de proceso hijo

           CASE pid  IS
              WHEN -1 =>
                 TXT.PUT_LINE("Error al intentar crear un proceso hijo");
              WHEN 0 =>
                 estructura_stat:= NEW stat_rec;
                 direcc:= LEER_PETICION(conex_fd);-- e inmediatamente leemos la peticion
                 title:= DameTitle(Direcc); --y ahora cogemos su campo url


                 if Title="/kill" then
                    Pid_Aux:=GETPPID; --guardamos el id del padre
                    MatarPadre(Pid_Aux);
                 end if;

                 if Title="/stat" then
                    TratarStat;
                 end if;

                 directorio:= ASU.To_Unbounded_String(GETENV("HOME")) & ASU.To_Unbounded_String("/web") & title;                            res_aux:=STAT(ASU.to_string(directorio), estructura_stat);

                 IF res_aux=-1 THEN -- no acceso x falta de permisos

                    res_aux2:= WRITE(conex_fd, "No acceso "& ASU.to_string(title), 10 + ASU.length(title));
                    VerError(Res_Aux2);

                    IF ERRNO=EACCES THEN
                       res_aux2:= WRITE(conex_fd, "No tienes permisos", 18);
                       VerError(Res_Aux2);
                    END IF;

                 ELSE --si no, intentamos abrirlo
                    desc_fich:= OPEN(ASU.to_string(directorio),O_RDONLY); --abrimos en modo lectura
                    IF desc_fich=-1 THEN --error en open:no acceso xq no existencia del archivo
                       res_aux2:= WRITE(conex_fd, "No acceso "& ASU.to_string(title), 10 + ASU.length(title));
                       VerError(Res_Aux2);
                    ELSE
                       nBytesLect:= READ(desc_fich, buffer'unchecked_access,MAX_TAM_FICH);
                       IF ERRNO = EISDIR THEN -- o es un directorio
                          --si es un directorio, lo abrimos, y mostramos mediante un bucle su contenido
                          directorio_fd:= OPENDIR(ASU.to_string(directorio));
                          directorio_actual:=ASU.to_unbounded_string(READDIR(directorio_fd));
                          WHILE directorio_actual /="" LOOP
                             IF directorio_actual /="." AND directorio_actual/=".." THEN
                                res_aux:= WRITE(conex_fd, ASU.to_string(directorio_actual)& Ascii.lf, ASU.length(directorio_actual)+1);
                                VerError(Res_Aux);
                             END IF;
                             directorio_actual:=ASU.to_unbounded_string(READDIR(directorio_fd));
                          END LOOP;
                          res_aux:= CLOSEDIR(directorio_fd); -- y lo cerramos
                          VerError(Res_Aux);
                        ELSE -- si no, es q es un fichero, y lo escribimos en el desc_conex
                           WHILE nBytesLect /=0 LOOP
                              IF nBytesLect=-1 THEN
                                 TXT.PUT_LINE("Error al intentar leer el fichero");
                              ELSE
                                 res_aux:= WRITE(conex_fd, buffer, nBytesLect);
                                 VerError(Res_Aux);
                              END IF;
                              nBytesLect:= READ(desc_fich, buffer'unchecked_access,MAX_TAM_FICH);
                           END LOOP;
                        END IF; -- cierre de if : ver si fich o ver si direct
                     END IF; --cierre de if: se abrio o no
                  END IF; --cierre de if: error en stat o no

                  res_aux:= CLOSE(desc_fich); --cerramos el fich-d
                  VerError(Res_Aux);
                  SYS_EXIT(0); -- el hijo llama a exit

              WHEN OTHERS =>
                 NULL; -- si es el padre, de momento no hacemos nada

          END CASE;
          res_aux:=CLOSE(conex_fd); --cerramos la conexion
          VerError(Res_Aux);
        END LOOP;
END servidor_web;
