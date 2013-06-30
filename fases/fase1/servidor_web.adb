-- Práctica de SSOO: programación de un servidor web
-- Fase actual: fase 1 Servidor Hola

--Paquetes que vamos a utilizar:

with unix; use unix;
with net; use net;
with text_io; use Text_Io;
with ada.strings.unbounded; use ada.strings.unbounded;

--Cabecera del programa:
procedure servidor_web is
   --Declaración de variables
   Fd: natural;
   R: integer;

begin
   --Apertura del puerto 9999
   inicializar(9999);
   --Bucle infinito
   loop
      --Recogida del descriptor de fichero que representa la conexión establecida
      Fd:= Aceptar_Conexion_Navegador;
      Put_Line("Me piden" & To_String(Leer_Peticion(Fd).Url));
      R:= Write(Fd, "Hola",4);
      R:= Close(Fd);
   end loop;
end;






