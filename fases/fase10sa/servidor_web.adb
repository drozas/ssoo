-- ***********************************************************
-- Practica de SSOO: programacion de un servidor web en Ada95
-- Fase actual: fase 10
-- Autor: David Rozas
-- ***********************************************************

WITH UNIX; USE UNIX;
WITH net; USE net;
WITH ada.text_io;
WITH ada.strings.unbounded; use Ada.Strings.Unbounded;
with Interfaces.C; use Interfaces.C;

PROCEDURE servidor_web IS

        -- Renombramientos y ctes
        PACKAGE ASU RENAMES Ada.Strings.Unbounded;
        PACKAGE TXT RENAMES Ada.text_io;
        --PACKAGE ASA RENAMES ada.strings.aliased;
        MAX_TAM_FICH: CONSTANT integer:= (5*1024);

-- ******************************************************************
-- Definición de tipos de la cache
-- ******************************************************************
        N_PAGS: constant Integer :=15;
        type TNombrePag is  String(1..25);
        type TContenidoPag is String(1.. MAX_TAM_FICH);
        type TRangoCache is  1..N_PAGS;

        type TNodoCache is record
           NombrePag: TNombrePag;
           ContenidoPag: TContenidoPag;
           Tamano: Integer:=0;
        end record;

        type TArrayCache is array(tRangoCache) of TNodoCache;

        type TCache is record
           info: TArrayCache;
           NActual: Integer:=0;
        end record;

        type TPunteroCache is access all TCache;


-- *********************************************************************




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

procedure TratarStat(Conex_Fd:integer) is
Res_Aux, Pid_Aux:Integer;
Mi_Pipe: aliased T_Fildes;
state: aliased integer;
NBytesLect: Integer;
buffer: aliased String:=(1..MAX_TAM_FICH =>' ');
begin
   -- **********Info de los redireccionamientos:************
   -- Entrada del hijo: tal cual
   -- Salida del hijo: mi_pipe(1)
   -- Entrada del padre: mi_pipe(0)
   -- Salida del padre: conex_fd(navegador)
   -- *****************************************************
   State:=0;
   Res_Aux:=PIPE(Mi_Pipe'Unchecked_Access); --preparamos el pipe
   VerError(Res_Aux);
   Pid_Aux:= FORK;
   case Pid_Aux is
      when -1 =>
         TXT.Put_Line("Error al crear el proceso hijo (en stat)");
      when 0 => --si soy el hijo (en realidad el nieto del PP)
         Res_Aux:=CLOSE(1);--cierro sal estandar(escritura)
         VerError(Res_Aux);
         Res_Aux:=DUP(Mi_Pipe(1));--ahora mi sal estandar es el pipe
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(1)); --cierro este extremo pq ya lo tengo apuntado
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(0)); --y este, pq no voy a leer de el
         VerError(Res_Aux);
         Res_Aux:= EXECLP(GETENV("HOME") & "/ssoo/estado_web","");
         VerError(Res_Aux);
         SYS_EXIT(0);
      when others =>
         --si soy el padre (en realidad el hijo del PP);
         Res_Aux:=CLOSE(0);--cierro mi entrada estandar
         VerError(Res_Aux);
         Res_Aux:=DUP(Mi_Pipe(0));--ahora mi entra estandar es la del pipe
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(0)); --y lo cierro, pq ya lo tengo apuntado con el std
         VerError(Res_Aux);
         Res_Aux:=CLOSE(1); --cierro mi sal estandar
         VerError(Res_Aux);
         Res_Aux:=DUP(Conex_Fd);--y la redirijo al navegador
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Conex_Fd);--y ahora puedo cerrar este(lo stoy apuntando con la std)
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(1)); --cierro sal std; pq no voy a escribir en el pipe
         VerError(Res_Aux);
         Res_Aux:=WAIT(State'Unchecked_Access); -- esperamos a que el hijo acabe
         -- y entonces podemos leer el contenido
         nBytesLect:= READ(0, buffer'unchecked_access,1);
         WHILE nBytesLect /=0 LOOP
              IF nBytesLect=-1 THEN
                 TXT.PUT_LINE("Error al intentar leer del pipe");
              ELSE
                 res_aux:= WRITE(1, buffer, nBytesLect);
                 VerError(Res_Aux);
              END IF;
              nBytesLect:= READ(0, buffer'unchecked_access,1);
         END LOOP;

   end case;
end;


-- ***********************************************************************************************

-- ************************************************************
-- Procedimientos y funciones de cache
-- ***********************************************************

procedure CrearCache is
Cache_Fd:Integer;
begin
   Cache_fd:=OPEN(GetEnv("HOME")&"/ssoo/cache",O_CREAT+O_RDWR+O_TRUNC);
end;

procedure BuscarPag (Cache: TCache; NombreABuscar:TNombrePag; Pos:TRangoCache) is
-- Busca en la cache si existe la pagina.
-- Si está devuelve la posicion en el array. Si no, devuelve -1 (tb en pos)
I:Integer;
Encontrado: Boolean;
begin
   I:=1;
   Encontrado:=FALSE;
   while I<= Cache.NTotal  and not Encontrado  loop
      if Cache.info[i].NombrePag = NombreABuscar then
         Encontrado:=True;
         Pos:=I;
      else
         I:=I+1;
      end if;
   end loop;

   if NotEncontrado then
      Pos:=-1;
   end if;
end;

function EsCacheLLena (cache: tCache) return boolean is
   EstaLLena: Boolean;
begin

   if Cache.NTotal < N_PAGS then
      EstaLLena:=FALSE;
   else
      EstaLLena:=TRUE;
   end if;

   return estaLLena;
end;

procedure EscribirPagEnCache (Cache: TCache; PagAEscribir: TNodoCache) is
begin
   if not EsCacheLLena(Cache) then
      Cache.NTotal:= Cache.NTotal+1;
      Cache.info[NTotal].NombrePag:=PagAEscribir.NombrePag;
      Cache.info[NTotal].ContenidoPag:=PagAEscribir.ContenidoPag;
      Cache.info[NTotal].Tamano:=PagAEscribir.Tamano;
   end if;
end;





-- *****************************************************************************************
        -- Variables globales
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


begin
        CrearCache;
        INICIALIZAR(9999); --Ponemos a escuchar el puerto 9999
        signal_fd:= SIGNAL(SIGCHLD, SIG_IGN); --ignoramos señal sigchld



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
                    TratarStat(Conex_Fd);
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
