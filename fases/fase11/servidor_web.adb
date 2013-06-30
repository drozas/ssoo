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
with ADA.UNCHECKED_CONVERSION;
with SYSTEM; use SYSTEM;
with Semaforos; use Semaforos;
PROCEDURE servidor_web IS

        -- Renombramientos y ctes
        PACKAGE ASU RENAMES Ada.Strings.Unbounded;
        PACKAGE TXT RENAMES Ada.text_io;
        MAX_TAM_FICH: CONSTANT integer:= (5*1024);


        -- ************************************************
        -- Tipos para la cache:
        -- ************************************************
        N_PAGS: constant Integer:= 10;
        subtype TNombrePag is String(1..50);
        subtype TInfoPag is String(1..MAX_TAM_FICH);

        type TNodoCache is record
           NombrePag: tNombrePag;
           InfoPag: tInfoPag;
        end record;

        type ArrayCache is array (0..N_PAGS) of TNodoCache;

        type TCache is record
           ContenidoCache: ArrayCache;
           posActual: Integer;
        end record;

        type TPuntCache is access TCache;
        -- ************************************************
FUNCTION Address_To_Access is NEW ADA.Unchecked_Conversion(Address,TPuntCache);

-- ************************************************************************************************
-- Procedimientos y funciones auxiliares:
-- ***********************************************************************************************
procedure VerError (Num_Error: Integer) is
begin
   if Num_Error=-1 then
      TXT.Put_Line("Se produjo un error en alguna llamada al sistema");
   end if;
end VerError;

function DameTitle (direccion: InfoPeticion_Type) return ASU.Unbounded_String is
   Title:ASU.Unbounded_String;
begin
   Title:=Direccion.Url;
   return Title;
end DameTitle;

procedure MatarPadre (Pid:Integer) is
   Res_Aux:Integer;
begin
   res_aux:=KILL(pid,SIGTERM); --le invitamos a morirse
   VerError(Res_Aux);
   res_aux:=SLEEP(2); --dormimos dos sg
   res_aux:=KILL(pid,SIGKILL); --si no se suicido, lo matamos
   VerError(Res_Aux);
end MatarPadre;

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
   Res_Aux:=PIPE(Mi_Pipe'Unchecked_Access);
   VerError(Res_Aux);
   Pid_Aux:= FORK;
   case Pid_Aux is
      when -1 =>
         TXT.Put_Line("Error al crear el proceso hijo (en stat)");
      when 0 => -- si soy el hijo
         Res_Aux:=CLOSE(1);
         VerError(Res_Aux);
         Res_Aux:=DUP(Mi_Pipe(1));
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(1));
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(0));
         VerError(Res_Aux);
         Res_Aux:= EXECLP(GETENV("HOME") & "/ssoo/estado_web","");
         VerError(Res_Aux);
         SYS_EXIT(0);
      when others => -- si soy el padre
         Res_Aux:=CLOSE(0);
         VerError(Res_Aux);
         Res_Aux:=DUP(Mi_Pipe(0));
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(0));
         VerError(Res_Aux);
         Res_Aux:=CLOSE(1);
         VerError(Res_Aux);
         Res_Aux:=DUP(Conex_Fd);
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Conex_Fd);
         VerError(Res_Aux);
         Res_Aux:=CLOSE(Mi_Pipe(1));
         VerError(Res_Aux);
         Res_Aux:=WAIT(State'Unchecked_Access); -- esperamos a que el hijo acabe
         -- y entonces podemos leer el contenido

         loop
            NBytesLect:=READ(0,Buffer'Unchecked_Access,1);
            exit when NBytesLect=0;
            if  nBytesLect=-1 then
               TXT.PUT_LINE("Error al intentar leer del pipe");
            else
               res_aux:= WRITE(1, buffer, nBytesLect);
               VerError(Res_Aux);
            end if;
         end loop;

   end case;
end TratarStat;

procedure MeterDirectorio(Directorio_Fd:Dirhandle; Cache:TPuntCache; Tam : out integer) is
   Aux, Directorio_Actual: ASU.Unbounded_String;
   TamAux: Integer;
begin
   TamAux := 0;
   loop
      directorio_actual:=ASU.to_unbounded_string(READDIR(directorio_fd));
      exit when (directorio_actual ="");
      if directorio_actual /="." and directorio_actual/=".." then
         Aux := Aux & Directorio_Actual & Ascii.lf;
         TamAux := TamAux + 1 + ASU.Length (Directorio_Actual);
      end if;
   end loop;
   Cache.ContenidoCache(Cache.PosActual).InfoPag(1..Asu.Length(Aux)) := Asu.To_String(aux)(1..ASU.Length(Aux));
   Tam := TamAux;
end MeterDirectorio;

-- **********************************************************************************************
-- Procedimientos y funciones de manejo de cache:
-- ***********************************************************************************************

function PosicionSiguiente (Pos: Integer) return Integer is
PosAux: Integer;
begin
   PosAux:= Pos mod N_PAGS + 1;
   return PosAux;
end PosicionSiguiente;



--procedure PosicionSiguiente (Pos : in out Integer) is
--begin
  -- Pos := Pos mod N_Pags + 1;
   --TXT.Put_Line("posicion procedimiento" & Integer'Image(Pos));
--end PosicionSiguiente;

function CrearCache return TPuntCache is
   PCache: TPuntCache;
   Cache : Tcache;
   PAux: Address;
   Tam_Aux: Integer;
   Res_Aux: Integer;
   Cache_Fd:Integer;
begin
   Cache_Fd:=OPEN(GetEnv("HOME")&"/ssoo/cache",O_CREAT+O_RDWR+O_TRUNC);
   VerError(Cache_Fd);
   Tam_Aux:=Cache'Size;
   Res_Aux:=LSEEK(Cache_Fd,Tam_Aux/8-1,SEEK_SET);
   VerError(Res_Aux);
   Res_Aux:=WRITE(Cache_Fd," ",1);
   VerError(Res_Aux);
   PAux:=MMAP(Int_To_Adr(0),Tam_Aux/8, PROT_READ+PROT_WRITE,MAP_SHARED,Cache_Fd,0);
   Res_Aux:=Adr_To_Int(PAux);
   VerError(Res_Aux);
   PCache:=Address_To_Access(PAux);
   Res_Aux:=CLOSE(Cache_Fd);
   VerError(Res_Aux);
   return PCache;
end CrearCache;

function EsCacheVacia(pCache:TPuntCache) return Boolean is
EsVacia:Boolean;
begin
   EsVacia:=pCache.PosActual=0;
   return EsVacia;
end EsCacheVacia;

function EsCacheLLena(pCache:TPuntCache) return Boolean is
EsLLena:Boolean;
begin
   EsLLena:=pCache.posActual>=N_PAGS;
   return EsLlena;
end EsCacheLLena;

function EstaEnCache(PagABuscar:ASU.Unbounded_String; pCache:TPuntCache) return integer is
Encontrada:Boolean;
I:Integer;
Posicion: Integer;
begin
   Encontrada:=False;
   Posicion:=-1;
   I:=1;
   if not EsCacheVacia(pCache) then
      while (I<=N_PAGS) and not(Encontrada) loop
         if pCache.ContenidoCache(I).NombrePag = ASU.To_String(PagABuscar) then
            Encontrada:=True;
            Posicion:=I;
         else
            I:=I+1;
         end if;
      end loop;
   end if;
   return Posicion;
end EstaEnCache;

procedure Leer_Pagina(NombreFichero: ASU.Unbounded_String; pCache:TPuntCache;
                                     Title : ASU.Unbounded_String; Salida: out ASU.Unbounded_String; Tam : out integer) is
   buffer: aliased String:=(1..1 =>' ');
   directorio: ASU.unbounded_string;--se refiere a ruta
   desc_fich:Integer;
   nBytesLect:integer;
   estructura_stat: stat_rec_ptr_type;
   directorio_fd: dirhandle; --es el directorio en si
   Pos : Integer;
   Existe : Boolean;
   BufferAux: Unbounded_String:=Null_Unbounded_String;
   Res_Aux : Integer;
begin
   Existe := True;
   Pos:=EstaEnCache(NombreFichero,pCache);
   if Pos =-1 then
      estructura_stat:= NEW stat_rec;
      res_aux:=STAT(ASU.To_String(NombreFichero), estructura_stat);
      IF res_aux=-1 THEN -- no acceso x falta de permisos
         Salida := ASU.To_Unbounded_String("No acceso "& ASU.to_string(title));
         Tam := 10 + Asu.Length(Title);
         Existe := False;
         IF ERRNO=EACCES THEN
            Salida := ASU.To_Unbounded_String("No tienes permisos");
            Existe := False;
         END IF;
      ELSE --si no, intentamos abrirlo
         desc_fich:= OPEN(ASU.to_string(NombreFichero),O_RDONLY); --abrimos en modo lectura
         IF desc_fich=-1 THEN --error en open:no acceso xq no existencia del archivo
            Salida := ASU.To_Unbounded_String("No acceso "& ASU.To_String(Title));
            Tam := 10 + Asu.Length(Title);
            Existe := False;
         ELSE
            nBytesLect:= READ(desc_fich, buffer'unchecked_access,1);
            IF ERRNO = EISDIR THEN -- si es un direct., lo abrimos y mostramos su contenido por el navegador
               directorio_fd:= OPENDIR(ASU.to_string(NombreFichero));
               PCache.PosActual:=PosicionSiguiente(PCache.PosActual);
               MeterDirectorio(Directorio_Fd, PCache, tam);
               res_aux:= CLOSEDIR(directorio_fd);
               VerError(Res_Aux);
               Pos := pCache.PosActual;
            ELSE -- si no, es q es un fichero, y lo escribimos en el desc_conex
               BufferAux := BufferAux & Buffer;
               PCache.PosActual:=PosicionSiguiente(PCache.PosActual);
               PCache.PosActual:= PosicionSiguiente(PCache.PosActual);
               Tam := 0;
               loop
                  nBytesLect:= READ(desc_fich, buffer'unchecked_access,1);
                  IF nBytesLect=-1 THEN
                     Existe := False;
                  ELSE
                     BufferAux := BufferAux & ASU.To_Unbounded_String(Buffer(1..1));
                     Tam := Tam + 1;
                  END IF;
                  exit when (NBytesLect = 0);
               END LOOP;
               res_aux:= CLOSE(desc_fich); --cerramos el fich-d
               PCache.ContenidoCache(PCache.PosActual).InfoPag(1..tam) := Asu.To_String(BufferAux)(1..tam);
               pCache.ContenidoCache(pCache.PosActual).NombrePag(1..ASU.Length(title)) := ASU.To_String(title);
               Pos := pCache.PosActual;
            END IF; -- cierre de if : ver si fich o ver si direct
         END IF; --cierre de if: se abrio o n
      END IF; --cierre de if: error en stat o no
   END IF;
   IF Existe then
      Salida:= ASU.To_Unbounded_String(pCache.ContenidoCache(Pos).InfoPag(1..pCache.ContenidoCache(Pos).InfoPag'Length));
   END IF;
   res_aux:= CLOSE(desc_fich); --cerramos el fich-d
end leer_Pagina;

-- ***********************************************************************************************
--              PROGRAMA PRINCIPAL
-- ***********************************************************************************************


        -- Variables
        conex_fd: Integer;
        res_aux: integer;
        direcc: infoPeticion_type;
        title: ASU.unbounded_string;
        directorio: ASU.unbounded_string;--se refiere a ruta
        Salida : ASU.Unbounded_String;
        pid: integer;
        signal_fd:int_proc;
        pid_aux:integer;
        PCache:TPuntCache;
        Tam : Integer;
        Mutex : Semaforo;
begin
   Signal_fd:=SIGNAL(SIGCHLD,Sig_Ign);
   inicializar(9999);
   PCache:=CrearCache;
   pCache.posactual:=0;
   Create (Mutex);
   Up (Mutex);
   loop
      Conex_fd:=aceptar_conexion_navegador;
      pid:=FORK;
   IF pid = 0 THEN
      direcc:=leer_peticion(Conex_fd);
      title:=direcc.url;
      IF title = "/kill" THEN
         Pid_aux:=GETPPID;
         matarpadre(Pid_aux);
      ELSIF title = "/stat" THEN
         tratarstat(Conex_Fd);
      ELSE
     -------------------------------------------
         directorio:= ASU.To_Unbounded_String(GETENV("HOME")) & ASU.To_Unbounded_String("/web") & title;
         Down (Mutex);
         Leer_Pagina(Directorio, PCache, Title, Salida, tam);
         Up (Mutex);
         Res_aux:=WRITE(Conex_fd,To_String(Salida),Tam);
         Res_aux:=Close(Conex_fd);
      END IF;
      sys_exit(0);
--   else

   END IF;
   Res_aux:= CLOSE(Conex_fd);
   end loop;
end servidor_web;
