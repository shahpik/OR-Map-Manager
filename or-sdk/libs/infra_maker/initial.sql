
create database or_dot;

create database ordb;

SET statement_timeout = 0;

SET lock_timeout = 0;

SET idle_in_transaction_session_timeout = 0;

SET client_encoding = 'UTF8';

SET standard_conforming_strings = on;

SELECT pg_catalog.set_config('search_path', '', false);

SET check_function_bodies = false;

SET xmloption = content;

SET client_min_messages = warning;

SET row_security = off;

SET default_tablespace = '';


SET default_table_access_method = heap;



-- Create and adjust user role;



create user oradmin with login inherit;

grant rds_superuser to oradmin;

alter role oradmin with createrole;

alter role oradmin with createdb;

alter role oradmin with valid until 'infinity';

alter role oradmin with password 'MyLongSecurePassword!';



REVOKE ALL ON SCHEMA public FROM rdsadmin;

REVOKE ALL ON SCHEMA public FROM PUBLIC;

GRANT ALL ON SCHEMA public TO pgadmin;

GRANT ALL ON SCHEMA public TO oradmin;

GRANT ALL ON SCHEMA public TO PUBLIC;



