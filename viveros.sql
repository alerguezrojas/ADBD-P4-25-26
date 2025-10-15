/* ===========================================================
   TAJINASTE S.A. - Script de base de datos (PostgreSQL)
   Crea BD, tablas, restricciones, datos de prueba, deletes y selects.
   =========================================================== */

-- 0) Crear BD (si existe la borra) y conectarse (válido para psql)
DROP DATABASE IF EXISTS viveros;
CREATE DATABASE viveros;
\connect viveros

-- 1) (Opcional recomendado) extensión para la restricción de "no solapamiento"
-- Si tu usuario no puede crear extensiones, comenta la línea siguiente y también
-- el EXCLUDE USING gist de la tabla ASIGNADO_A.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 2) ENTIDADES -------------------------------------------------------------

-- 2.1 VIVERO
DROP TABLE IF EXISTS VIVERO CASCADE;
CREATE TABLE VIVERO (
  id_vivero   SERIAL PRIMARY KEY,
  nombre      VARCHAR(50)  NOT NULL,
  latitud     NUMERIC(9,6) NOT NULL CHECK (latitud  BETWEEN -90  AND 90),
  longitud    NUMERIC(9,6) NOT NULL CHECK (longitud BETWEEN -180 AND 180),
  direccion   VARCHAR(120) NOT NULL
);

-- 2.1.b Atributo multivaluado: teléfonos de vivero
DROP TABLE IF EXISTS VIVERO_TELEFONO;
CREATE TABLE VIVERO_TELEFONO (
  id_vivero INT NOT NULL REFERENCES VIVERO(id_vivero) ON DELETE CASCADE ON UPDATE CASCADE,
  telefono  VARCHAR(20) NOT NULL,
  PRIMARY KEY (id_vivero, telefono)
);

-- 2.2 ZONA
DROP TABLE IF EXISTS ZONA CASCADE;
CREATE TABLE ZONA (
  id_zona    SERIAL PRIMARY KEY,
  id_vivero  INT NOT NULL REFERENCES VIVERO(id_vivero) ON DELETE CASCADE ON UPDATE CASCADE,
  nombre     VARCHAR(50) NOT NULL,
  tipo       VARCHAR(20) NOT NULL CHECK (tipo IN ('Exterior','Interior','Almacén')),
  latitud    NUMERIC(9,6) NOT NULL CHECK (latitud  BETWEEN -90  AND 90),
  longitud   NUMERIC(9,6) NOT NULL CHECK (longitud BETWEEN -180 AND 180),
  CONSTRAINT uq_zona_por_vivero UNIQUE (id_vivero, nombre)
);

-- 2.3 PRODUCTO
DROP TABLE IF EXISTS PRODUCTO CASCADE;
CREATE TABLE PRODUCTO (
  id_producto    SERIAL PRIMARY KEY,
  nombre         VARCHAR(60) NOT NULL,
  categoria      VARCHAR(20) NOT NULL CHECK (categoria IN ('Planta','Jardinería','Decoración')),
  unidad_medida  VARCHAR(20) NOT NULL
);

-- 2.4 EMPLEADO
DROP TABLE IF EXISTS EMPLEADO CASCADE;
CREATE TABLE EMPLEADO (
  id_empleado  SERIAL PRIMARY KEY,
  dni          VARCHAR(12) UNIQUE NOT NULL,
  nombre       VARCHAR(50) NOT NULL,
  apellidos    VARCHAR(80) NOT NULL,
  fecha_alta   DATE        NOT NULL
);

-- 2.5 CLIENTE (superclase)
DROP TABLE IF EXISTS CLIENTE CASCADE;
CREATE TABLE CLIENTE (
  id_cliente  SERIAL PRIMARY KEY,
  nombre      VARCHAR(60)  NOT NULL,
  email       VARCHAR(120) UNIQUE NOT NULL,
  telefono    VARCHAR(20)
);

-- 2.6 CLIENTE_PLUS (subclase de CLIENTE)
DROP TABLE IF EXISTS CLIENTE_PLUS CASCADE;
CREATE TABLE CLIENTE_PLUS (
  id_cliente     INT  PRIMARY KEY REFERENCES CLIENTE(id_cliente) ON DELETE CASCADE ON UPDATE CASCADE,
  fecha_ingreso  DATE NOT NULL,
  estado         VARCHAR(10) NOT NULL CHECK (estado IN ('activa','inactiva')),
  nivel          VARCHAR(10)     CHECK (nivel IN ('Bronce','Plata','Oro'))
);

-- 2.7 BONIFICACION_MENSUAL
DROP TABLE IF EXISTS BONIFICACION_MENSUAL CASCADE;
CREATE TABLE BONIFICACION_MENSUAL (
  id_bonificacion       SERIAL PRIMARY KEY,
  id_cliente            INT NOT NULL REFERENCES CLIENTE_PLUS(id_cliente) ON DELETE CASCADE ON UPDATE CASCADE,
  anio_mes              CHAR(7) NOT NULL CHECK (anio_mes ~ '^[0-9]{4}-[0-9]{2}$'),
  volumen_compras       NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (volumen_compras >= 0),
  bonificacion_asignada NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (bonificacion_asignada >= 0),
  -- derivados útiles
  anio INT GENERATED ALWAYS AS ((split_part(anio_mes,'-',1))::INT) STORED,
  mes  INT GENERATED ALWAYS AS ((split_part(anio_mes,'-',2))::INT) STORED,
  CONSTRAINT uq_bonus_por_mes UNIQUE (id_cliente, anio_mes)
);

-- 2.8 PEDIDO
DROP TABLE IF EXISTS PEDIDO CASCADE;
CREATE TABLE PEDIDO (
  id_pedido     SERIAL PRIMARY KEY,
  id_cliente    INT REFERENCES CLIENTE(id_cliente)    ON DELETE SET NULL ON UPDATE CASCADE,
  id_empleado   INT REFERENCES EMPLEADO(id_empleado)  ON DELETE SET NULL ON UPDATE CASCADE,
  fecha         DATE NOT NULL,
  importe_total NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (importe_total >= 0)
);


-- 3) RELACIONES M:N CON ATRIBUTOS (tablas puente) -------------------------

-- 3.1 INVENTARIO (ZONA <> PRODUCTO)
DROP TABLE IF EXISTS INVENTARIO;
CREATE TABLE INVENTARIO (
  id_zona      INT NOT NULL REFERENCES ZONA(id_zona) ON DELETE CASCADE ON UPDATE CASCADE,
  id_producto  INT NOT NULL REFERENCES PRODUCTO(id_producto) ON DELETE CASCADE ON UPDATE CASCADE,
  cantidad_disponible INT NOT NULL CHECK (cantidad_disponible >= 0),
  fecha_ult_actualizacion DATE NOT NULL,
  PRIMARY KEY (id_zona, id_producto)
);

-- 3.2 ASIGNADO_A (EMPLEADO <> ZONA) con histórico y "no solapamiento"
DROP TABLE IF EXISTS ASIGNADO_A;
CREATE TABLE ASIGNADO_A (
  id_empleado  INT NOT NULL REFERENCES EMPLEADO(id_empleado) ON DELETE CASCADE ON UPDATE CASCADE,
  id_zona      INT NOT NULL REFERENCES ZONA(id_zona)         ON DELETE CASCADE ON UPDATE CASCADE,
  puesto       VARCHAR(50) NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_fin    DATE,
  activo       BOOLEAN GENERATED ALWAYS AS (fecha_fin IS NULL) STORED,
  PRIMARY KEY (id_empleado, id_zona, fecha_inicio),
  CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  periodo DATERANGE GENERATED ALWAYS AS (daterange(fecha_inicio, COALESCE(fecha_fin, 'infinity'::date))) STORED,
  EXCLUDE USING gist (id_empleado WITH =, periodo WITH &&)
);

-- 4) DATOS DE PRUEBA (≥ 5 filas por tabla) --------------------------------

-- VIVERO
INSERT INTO VIVERO (nombre, latitud, longitud, direccion) VALUES
('Vivero La Laguna', 28.485400, -16.313200, 'Av. Trinidad 12, La Laguna'),
('Vivero Santa Cruz', 28.463600, -16.251800, 'C/ Castillo 21, Santa Cruz'),
('Vivero La Orotava', 28.390000, -16.523000, 'Ctra. Orotava 5, La Orotava'),
('Vivero Arona',     28.099900, -16.681300, 'Av. Suecia 10, Arona'),
('Vivero Adeje',     28.122700, -16.726000, 'TF-1 Salida 79, Adeje');

-- VIVERO_TELEFONO
INSERT INTO VIVERO_TELEFONO VALUES
(1,'922111222'), (1,'922333444'),
(2,'922555666'),
(3,'922777888'),
(4,'922999000'),
(5,'922123456');

-- ZONA
INSERT INTO ZONA (id_vivero, nombre, tipo, latitud, longitud) VALUES
(1,'Exterior','Exterior',28.485500,-16.313000),
(1,'Almacén','Almacén', 28.485300,-16.313400),
(2,'Interior','Interior',28.463700,-16.251700),
(3,'Exterior','Exterior',28.390200,-16.522800),
(4,'Exterior','Exterior',28.100100,-16.681500);

-- PRODUCTO
INSERT INTO PRODUCTO (nombre, categoria, unidad_medida) VALUES
('Begonia','Planta','maceta'),
('Pala Jardín','Jardinería','unidad'),
('Maceta Terracota 20cm','Decoración','unidad'),
('Geranio','Planta','maceta'),
('Tierra Universal 20L','Jardinería','saco');

-- EMPLEADO
INSERT INTO EMPLEADO (dni, nombre, apellidos, fecha_alta) VALUES
('12345678A','Lucía','García Pérez','2021-01-10'),
('87654321B','Carlos','Díaz Martín','2020-03-05'),
('11223344C','Marta','López Ruiz','2022-07-15'),
('55667788D','Diego','Hernández León','2019-11-20'),
('99887766E','Ana','Sosa Trujillo','2023-04-01');

-- CLIENTE
INSERT INTO CLIENTE (nombre, email, telefono) VALUES
('Juan Pérez','juan@example.com','600111111'),
('María López','maria@example.com','600222222'),
('Pedro Díaz','pedro@example.com','600333333'),
('Eva Martín','eva@example.com','600444444'),
('Laura Gómez','laura@example.com',NULL);

-- CLIENTE_PLUS
INSERT INTO CLIENTE_PLUS (id_cliente, fecha_ingreso, estado, nivel) VALUES
(1,'2024-01-15','activa','Plata'),
(2,'2023-11-01','activa','Oro'),
(4,'2024-06-10','inactiva','Bronce');

-- BONIFICACION_MENSUAL
INSERT INTO BONIFICACION_MENSUAL (id_cliente, anio_mes, volumen_compras, bonificacion_asignada) VALUES
(1,'2025-07',250.00,10.00),
(1,'2025-08',120.00,5.00),
(2,'2025-07',600.00,30.00),
(2,'2025-09',100.00,5.00),
(4,'2025-06',0.00,0.00);

-- PEDIDO
INSERT INTO PEDIDO (id_cliente, id_empleado, fecha, importe_total) VALUES
(1,1,'2025-07-03', 80.00),
(2,2,'2025-07-15',120.50),
(3,3,'2025-08-01', 45.00),
(4,1,'2025-06-20', 60.00),
(5,5,'2025-09-12',220.00);

-- INVENTARIO
INSERT INTO INVENTARIO (id_zona, id_producto, cantidad_disponible, fecha_ult_actualizacion) VALUES
(1,1,30,'2025-07-01'),
(1,3,50,'2025-07-05'),
(2,5,90,'2025-07-04'),
(3,4,25,'2025-07-10'),
(4,2,10,'2025-07-11');

-- ASIGNADO_A (no solapado por empleado)
INSERT INTO ASIGNADO_A (id_empleado, id_zona, puesto, fecha_inicio, fecha_fin) VALUES
(1,1,'Vendedor','2024-01-01','2024-12-31'),
(1,3,'Encargado','2025-01-01',NULL),
(2,2,'Almacenero','2023-06-01',NULL),
(3,4,'Jardinero','2024-03-10','2024-09-30'),
(5,5,'Vendedor','2025-05-01',NULL);

-- 5) DELETES DE EJEMPLO (descomenta para probar cada caso) ----------------
--DELETE FROM CLIENTE_PLUS WHERE id_cliente = 4;   -- borra sus bonificaciones (CASCADE)
--DELETE FROM ZONA WHERE id_zona = 2;              -- borra inventario y asignaciones de esa zona
--DELETE FROM EMPLEADO WHERE id_empleado = 1;      -- pedidos quedan con id_empleado NULL
--DELETE FROM VIVERO WHERE id_vivero = 1;          -- borra zonas, teléfonos e inventarios (CASCADE)

-- 6) SELECTS PARA CAPTURAS -----------------------------------------------
SELECT * FROM VIVERO ORDER BY id_vivero;
SELECT * FROM VIVERO_TELEFONO ORDER BY id_vivero, telefono;
SELECT * FROM ZONA ORDER BY id_zona;
SELECT * FROM PRODUCTO ORDER BY id_producto;
SELECT * FROM EMPLEADO ORDER BY id_empleado;
SELECT * FROM CLIENTE ORDER BY id_cliente;
SELECT * FROM CLIENTE_PLUS ORDER BY id_cliente;
SELECT * FROM BONIFICACION_MENSUAL ORDER BY id_bonificacion;
SELECT * FROM PEDIDO ORDER BY id_pedido;
SELECT * FROM INVENTARIO ORDER BY id_zona, id_producto;
SELECT * FROM ASIGNADO_A ORDER BY id_empleado, fecha_inicio;

-- Comprobaciones de columnas derivadas
SELECT id_bonificacion, anio_mes, anio, mes FROM BONIFICACION_MENSUAL ORDER BY id_bonificacion;
SELECT id_empleado, id_zona, fecha_inicio, fecha_fin, activo FROM ASIGNADO_A ORDER BY id_empleado, fecha_inicio;
