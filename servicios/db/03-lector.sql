-- Rol de solo lectura para consultar el inventario.
-- La contraseña viene de LECTOR_PASSWORD (en .env), no de este archivo.
\getenv clave_lector LECTOR_PASSWORD

CREATE ROLE lector LOGIN;
SELECT format('ALTER ROLE lector PASSWORD %L', :'clave_lector') \gexec

GRANT CONNECT ON DATABASE inventario TO lector;
GRANT USAGE ON SCHEMA public TO lector;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lector;
ALTER ROLE lector SET default_transaction_read_only = on;
