# Examen Práctico: Replicación Lógica Bidireccional Heterogénea con SymmetricDS

## 📋 Descripción del Problema

**GlobalShop Inc.** es una empresa de e-commerce que opera en dos regiones principales:
- **Región América** (Sede en Miami, USA) - Base de datos PostgreSQL
- **Región Europa** (Sede en Madrid, España) - Base de datos MySQL

Cada región tiene su propia base de datos que gestiona las operaciones locales, pero necesitan mantener sincronizados ciertos datos críticos del negocio en tiempo real para:
- Mantener un catálogo de productos unificado
- Sincronizar inventario entre regiones
- Compartir información de clientes globales
- Coordinar precios y promociones

**El desafío**: Implementar una arquitectura de replicación lógica bidireccional heterogénea (PostgreSQL ↔ MySQL) utilizando SymmetricDS en modo multi-cluster con Docker Compose.

## 🎯 Objetivo del Examen

Configurar una replicación bidireccional entre dos bases de datos heterogéneas donde:
1. Los cambios en PostgreSQL (América) se repliquen automáticamente a MySQL (Europa)
2. Los cambios en MySQL (Europa) se repliquen automáticamente a PostgreSQL (América)
3. Se manejen correctamente las operaciones INSERT, UPDATE y DELETE
4. Se eviten conflictos y loops de replicación

## 📊 Modelo de Datos

### Entidades a Replicar

Se deben replicar las siguientes 4 tablas en ambas direcciones:

#### 1. **products** (Catálogo de Productos)
```sql
- product_id (PK, VARCHAR(50))
- product_name (VARCHAR(200))
- category (VARCHAR(100))
- base_price (DECIMAL(10,2))
- description (TEXT)
- is_active (BOOLEAN/TINYINT)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

#### 2. **inventory** (Control de Inventario)
```sql
- inventory_id (PK, VARCHAR(50))
- product_id (FK, VARCHAR(50))
- region (VARCHAR(50)) -- 'AMERICA' o 'EUROPE'
- quantity (INTEGER)
- warehouse_code (VARCHAR(50))
- last_updated (TIMESTAMP)
```

#### 3. **customers** (Clientes Globales)
```sql
- customer_id (PK, VARCHAR(50))
- email (VARCHAR(200), UNIQUE)
- full_name (VARCHAR(200))
- country (VARCHAR(100))
- registration_date (TIMESTAMP)
- is_premium (BOOLEAN/TINYINT)
- last_purchase_date (TIMESTAMP)
```

#### 4. **promotions** (Promociones y Descuentos)
```sql
- promotion_id (PK, VARCHAR(50))
- promotion_name (VARCHAR(200))
- discount_percentage (DECIMAL(5,2))
- start_date (DATE)
- end_date (DATE)
- applicable_regions (VARCHAR(100)) -- 'AMERICA', 'EUROPE', 'GLOBAL'
- is_active (BOOLEAN/TINYINT)
```

### Datos de Prueba Iniciales

El sistema incluye scripts con datos iniciales:
- 10 productos en diferentes categorías
- 20 registros de inventario (10 por región)
- 15 clientes de diferentes países
- 8 promociones activas

## 🏗️ Arquitectura Requerida

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Network                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐              ┌──────────────────┐    │
│  │   PostgreSQL     │◄────────────►│     MySQL        │    │
│  │   (América)      │              │    (Europa)      │    │
│  │   Puerto: 5432   │              │   Puerto: 3306   │    │
│  └────────┬─────────┘              └─────────┬────────┘    │
│           │                                   │              │
│           │                                   │              │
│  ┌────────▼─────────┐              ┌─────────▼────────┐    │
│  │  SymmetricDS     │◄────────────►│  SymmetricDS     │    │
│  │  Node: america   │              │  Node: europe    │    │
│  │  Puerto: 31415   │              │  Puerto: 31416   │    │
│  └──────────────────┘              └──────────────────┘    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 📝 Tareas a Realizar

### ✅ Proporcionado por el Profesor
- ✅ Esquema de base de datos (DDL) para PostgreSQL y MySQL
- ✅ Scripts de inicialización con datos de prueba
- ✅ Plantillas de configuración (con instrucciones pero INCOMPLETAS)
- ✅ Documentación completa en `docs/`
- ✅ Script de calificación automática

### 🎓 LO QUE DEBES HACER (100 puntos)

#### 1. **Crear `docker-compose.yml` desde CERO** (40 puntos)
**Archivo NO existe, debes crearlo.**

Debe incluir:
- ✅ Servicio `postgres-america` (PostgreSQL 15)
- ✅ Servicio `mysql-europe` (MySQL 8.0)
- ✅ Servicio `symmetricds-america` (SymmetricDS 3.14)
- ✅ Servicio `symmetricds-europe` (SymmetricDS 3.14)
- ✅ Red compartida
- ✅ Volúmenes correctamente montados
- ✅ Puertos expuestos (5432, 3306, 31415, 31416)
- ✅ Variables de entorno configuradas

**Ver ejemplo completo en**: `docs/SYMMETRICDS_GUIDE.md`

#### 2. **Completar configuración América** (30 puntos)

**Archivo 1**: `symmetricds/america/symmetric.properties`
- Completar todos los campos marcados con `COMPLETAR`
- Configurar conexión a PostgreSQL
- Definir `engine.name`, `group.id`, `external.id`
- Configurar puerto HTTP (31415)
- **NO** definir `registration.url` (es el nodo raíz)

**Archivo 2**: `symmetricds/america/engines/america.properties`
- Escribir SQL que defina:
  - Grupos de nodos (sym_node_group)
  - Enlaces bidireccionales (sym_node_group_link)
  - 4 Canales (sym_channel)
  - 4 Triggers (sym_trigger)
  - 2 Routers (sym_router)
  - Vinculación triggers-routers (sym_trigger_router)

**Ver SQL completo en**: `docs/SYMMETRICDS_GUIDE.md` sección "Paso 4"

#### 3. **Completar configuración Europa** (30 puntos)

**Archivo 1**: `symmetricds/europe/symmetric.properties`
- Completar todos los campos marcados con `COMPLETAR`
- Configurar conexión a MySQL
- Definir `engine.name`, `group.id`, `external.id`
- Configurar puerto HTTP (31416)
- **CRÍTICO**: `registration.url` debe apuntar a América

**Archivo 2**: `symmetricds/europe/engines/europe.properties`
- Puede estar vacío (configuración se hereda de América)

#### 4. **BONUS: Funcionalidad** (+20 puntos)
Si tu arquitectura funciona correctamente y pasa las pruebas automáticas

## 📁 Estructura del Proyecto

```
examen-abdd-2025-2/
├── README.md                          # Este archivo
├── docker-compose.yml                 # ⚠️ CREAR POR EL ESTUDIANTE
├── init-db/
│   ├── postgres/
│   │   └── 01-init.sql               # ✅ Proporcionado
│   └── mysql/
│       └── 01-init.sql               # ✅ Proporcionado
├── symmetricds/
│   ├── america/
│   │   ├── symmetric.properties      # ⚠️ CONFIGURAR POR EL ESTUDIANTE
│   │   └── engines/
│   │       └── america.properties    # ⚠️ CONFIGURAR POR EL ESTUDIANTE
│   └── europe/
│       ├── symmetric.properties      # ⚠️ CONFIGURAR POR EL ESTUDIANTE
│       └── engines/
│           └── europe.properties     # ⚠️ CONFIGURAR POR EL ESTUDIANTE
├── validation/
│   ├── validate.sh                   # ✅ Script principal de validación
│   ├── test-inserts.sql              # ✅ Tests de INSERT
│   ├── test-updates.sql              # ✅ Tests de UPDATE
│   └── test-deletes.sql              # ✅ Tests de DELETE
└── docs/
    ├── SYMMETRICDS_GUIDE.md          # ✅ Guía de SymmetricDS
    └── TROUBLESHOOTING.md            # ✅ Solución de problemas
```

## 🚀 Instrucciones de Ejecución

### Para el Estudiante

**📖 PASO 0: LEER DOCUMENTACIÓN PRIMERO**
```bash
# Lee primero estas guías antes de empezar:
cat docs/SYMMETRICDS_GUIDE.md        # Guía completa con ejemplos
cat INSTRUCCIONES_ESTUDIANTE.md      # Instrucciones paso a paso
```

**1. Completar las configuraciones requeridas**
   - ✅ Crear `docker-compose.yml` (desde cero)
   - ✅ Completar `symmetricds/america/symmetric.properties`
   - ✅ Completar `symmetricds/america/engines/america.properties`
   - ✅ Completar `symmetricds/europe/symmetric.properties`
   - ✅ Verificar `symmetricds/europe/engines/europe.properties`

**2. Levantar la arquitectura**
```bash
docker-compose up -d
```

**3. Verificar que los contenedores están corriendo**
```bash
docker-compose ps
# Debes ver 4 contenedores en estado "Up"
```

**4. Esperar a que todo inicie (2-3 minutos)**
```bash
# Ver logs si hay problemas
docker-compose logs -f
```

**5. Probar manualmente (opcional)**
```bash
# Ver INSTRUCCIONES_ESTUDIANTE.md para ejemplos de pruebas
```

**6. Entregar**
   - ZIP con todos los archivos configurados
   - Captura de pantalla de `docker-compose ps`

### Para el Profesor

**Calificación Automática en 1 Comando:**
```bash
./calificar.sh
```

El script calificará automáticamente (100 puntos total):

| Sección | Puntos | Qué Valida |
|---------|--------|------------|
| **1. Docker Compose** | 20 pts | • Archivo existe y sintaxis válida<br>• 4 servicios definidos correctamente |
| **2. Contenedores** | 20 pts | • Todos los contenedores en ejecución<br>• PostgreSQL, MySQL, 2x SymmetricDS |
| **3. Bases de Datos** | 15 pts | • Conexión PostgreSQL y MySQL<br>• Tablas de negocio creadas |
| **4. SymmetricDS** | 15 pts | • Tablas SymmetricDS creadas<br>• Grupos de nodos configurados |
| **5. Replicación** | 30 pts | • INSERT bidireccional<br>• UPDATE bidireccional<br>• DELETE bidireccional |

**Genera:**
- ✅ Reporte en pantalla con desglose detallado
- ✅ Archivo `calificacion_[timestamp].txt`
- ✅ Retroalimentación por sección
- ✅ Nota final (A, B, C, D, F)

**Ejemplo de salida:**
```
╔═════════════════════════════════════════════════╗
║   CALIFICACIÓN: EXCELENTE (A) - 95%            ║
╚═════════════════════════════════════════════════╝

1. Docker Compose:            20 / 20
2. Contenedores:              20 / 20
3. Bases de Datos:            15 / 15
4. SymmetricDS:               15 / 15
5. Replicación:               25 / 30
──────────────────────────────────────────
TOTAL:                        95 / 100
```

## ✅ Criterios de Evaluación (100 puntos = 80 automático + 20 manual)

### Sistema de Calificación

Este examen se divide en **2 partes**:

#### Parte 1: ARQUITECTURA (80 puntos) - Calificación Automática ⚙️

El script `calificar_todos.sh` evalúa automáticamente:

| Sección | Puntos | Qué se evalúa |
|---------|--------|---------------|
| **1. Docker Compose** | 25 | • Archivo existe (8 pts)<br>• Sintaxis YAML válida (8 pts)<br>• 4 servicios definidos (9 pts) |
| **2. Contenedores** | 20 | • postgres-america corriendo (5 pts)<br>• mysql-europe corriendo (5 pts)<br>• symmetricds-america corriendo (5 pts)<br>• symmetricds-europe corriendo (5 pts) |
| **3. Bases de Datos** | 15 | • Conexión PostgreSQL (5 pts)<br>• 4 tablas creadas (5 pts)<br>• Conexión MySQL (5 pts) |
| **4. SymmetricDS** | 20 | • Tablas SymmetricDS en PostgreSQL (8 pts)<br>• Tablas SymmetricDS en MySQL (8 pts)<br>• Grupos de nodos configurados (4 pts) |
| **SUBTOTAL AUTOMÁTICO** | **80** | |

#### Parte 2: EVIDENCIAS DE REPLICACIÓN (20 puntos) - Calificación Manual 📸

Debes crear una carpeta `replication-proofs/` en tu rama con capturas que demuestren:

| Evidencia | Puntos | Qué Mostrar |
|-----------|--------|-------------|
| **1. INSERT PG → MySQL** | 5 | Insertar en PostgreSQL, mostrar en MySQL |
| **2. INSERT MySQL → PG** | 5 | Insertar en MySQL, mostrar en PostgreSQL |
| **3. UPDATE bidireccional** | 5 | UPDATE en una BD, verificar en la otra |
| **4. DELETE bidireccional** | 5 | DELETE en una BD, verificar en la otra |
| **SUBTOTAL MANUAL** | **20** | |

**TOTAL EXAMEN: 100 puntos (80 automático + 20 manual)**

#### Parte 2: EVIDENCIAS DE REPLICACIÓN (Entrega Manual)

**IMPORTANTE:** Además de la arquitectura, debes demostrar que la replicación funciona con **capturas de pantalla** que muestren:

**📸 Capturas Requeridas:**

1. **INSERT: PostgreSQL → MySQL** (Captura 1)
   ```bash
   # En PostgreSQL, insertar:
   docker exec -it postgres-america psql -U symmetricds -d globalshop
   INSERT INTO products VALUES ('DEMO-001', 'Producto Demo', 'Demo', 99.99, 'Demo', true, NOW(), NOW());
   SELECT * FROM products WHERE product_id = 'DEMO-001';
   ```
   
   ```bash
   # En MySQL, verificar que aparece:
   docker exec -it mysql-europe mysql -u symmetricds -psymmetricds globalshop
   SELECT * FROM products WHERE product_id = 'DEMO-001';
   ```
   **Captura:** Debes mostrar AMBAS consultas (PostgreSQL con INSERT y MySQL con SELECT mostrando el dato replicado)

2. **INSERT: MySQL → PostgreSQL** (Captura 2)
   ```bash
   # En MySQL, insertar:
   INSERT INTO customers VALUES ('DEMO-CUST', 'demo@test.com', 'Cliente Demo', 'Spain', NOW(), 1, NOW());
   SELECT * FROM customers WHERE customer_id = 'DEMO-CUST';
   ```
   
   ```bash
   # En PostgreSQL, verificar:
   SELECT * FROM customers WHERE customer_id = 'DEMO-CUST';
   ```
   **Captura:** Ambas consultas mostrando la replicación inversa

3. **UPDATE Bidireccional** (Captura 3)
   ```bash
   # Actualizar en PostgreSQL:
   UPDATE products SET base_price = 149.99 WHERE product_id = 'DEMO-001';
   ```
   
   ```bash
   # Verificar en MySQL que el precio cambió:
   SELECT product_id, base_price FROM products WHERE product_id = 'DEMO-001';
   ```
   **Captura:** Mostrar el UPDATE y la verificación

4. **DELETE Bidireccional** (Captura 4)
   ```bash
   # Eliminar en MySQL:
   DELETE FROM customers WHERE customer_id = 'DEMO-CUST';
   ```
   
   ```bash
   # Verificar en PostgreSQL que se eliminó:
   SELECT COUNT(*) FROM customers WHERE customer_id = 'DEMO-CUST';
   -- Debe retornar 0
   ```
   **Captura:** Mostrar el DELETE y la verificación

**Formato de las capturas:**
- Deben ser legibles (texto visible)
- Incluir timestamp o comando completo
- Mostrar AMBAS bases de datos en cada operación
- Guardar en: `replication-proofs/01_insert_pg_mysql.png`, `02_insert_mysql_pg.png`, etc.

**Puntuación:**
- Cada captura vale 5 puntos
- Total: 20 puntos (calificación manual del profesor)

### Escala de Calificación

**Calificación Final = Arquitectura + Evidencias**

- **90-100**: Excelente (A)
- **80-89**: Bueno (B)  
- **70-79**: Aceptable (C)
- **60-69**: Suficiente (D)
- **<60**: Insuficiente (F)

**Si no presentas las capturas de replicación, tu calificación máxima será la de arquitectura únicamente.**

## 📚 Recursos y Referencias

### Documentación Incluida
- `docs/SYMMETRICDS_GUIDE.md` - Guía completa de configuración de SymmetricDS
- `docs/TROUBLESHOOTING.md` - Solución de problemas comunes

### Documentación Externa
- [SymmetricDS Documentation](https://www.symmetricds.org/documentation)
- [SymmetricDS Docker Hub](https://hub.docker.com/r/jumpmind/symmetricds)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## ⚠️ Consideraciones Importantes

1. **Identificadores Únicos**: Usar UUID o códigos que garanticen unicidad entre regiones
2. **Timestamps**: Incluir `updated_at` en todas las tablas para control de cambios
3. **Resolución de Conflictos**: SymmetricDS usa "last write wins" por defecto
4. **Triggers**: SymmetricDS crea triggers automáticamente - no los modifiquen
5. **Logs**: Revisar logs de SymmetricDS para debugging

## 🔍 Pruebas Manuales (Opcionales)

Si deseas probar manualmente antes de ejecutar el script de validación:

```bash
# Conectar a PostgreSQL
docker exec -it postgres-america psql -U symmetricds -d globalshop

# Conectar a MySQL
docker exec -it mysql-europe mysql -u symmetricds -psymmetricds globalshop

# Ejemplo: Insertar un producto en PostgreSQL
INSERT INTO products VALUES 
('PROD-TEST-001', 'Test Product', 'Electronics', 99.99, 'Test', true, NOW(), NOW());

# Verificar en MySQL (esperar unos segundos)
SELECT * FROM products WHERE product_id = 'PROD-TEST-001';
```

## 🎯 Entrega

**Archivos a entregar:**
1. `docker-compose.yml`
2. `symmetricds/america/symmetric.properties`
3. `symmetricds/america/engines/america.properties`
4. `symmetricds/europe/symmetric.properties`
5. `symmetricds/europe/engines/europe.properties`
6. Captura de pantalla del output de `validate.sh` exitoso

**Formato de entrega**: ZIP con el nombre `apellido_nombre_examen_abdd.zip`

## 📸 Evidencias de Replicación (REQUERIDO)

Además de la arquitectura, debes demostrar que la replicación bidireccional funciona correctamente mediante **capturas de pantalla**.

### Crear carpeta de evidencias

```bash
mkdir evidencias
cd evidencias
```

### Capturas Requeridas

#### 1. Arquitectura Funcionando (`01_arquitectura.png`)

```bash
docker compose ps
```

**Captura:** Debe mostrar los 4 contenedores en estado "Up"

#### 2. INSERT: PostgreSQL → MySQL (`02_insert_pg_mysql.png`)

```bash
# Terminal 1: Conectar a PostgreSQL
docker exec -it postgres-america psql -U symmetricds -d globalshop

# Insertar un producto
INSERT INTO products VALUES ('EVIDENCIA-01', 'Producto de Evidencia', 'Demo', 199.99, 'Test replicacion', true, NOW(), NOW());

# Verificar inserción
SELECT product_id, product_name, base_price FROM products WHERE product_id = 'EVIDENCIA-01';
```

```bash
# Terminal 2: Conectar a MySQL y verificar (esperar 10 segundos)
docker exec -it mysql-europe mysql -u symmetricds -psymmetricds globalshop

# Verificar que se replicó
SELECT product_id, product_name, base_price FROM products WHERE product_id = 'EVIDENCIA-01';
```

**Captura:** Mostrar AMBAS terminales mostrando que el dato insertado en PostgreSQL aparece en MySQL

#### 3. INSERT: MySQL → PostgreSQL (`03_insert_mysql_pg.png`)

```bash
# Terminal 1: Conectar a MySQL
docker exec -it mysql-europe mysql -u symmetricds -psymmetricds globalshop

# Insertar un cliente
INSERT INTO customers VALUES ('EVIDENCIA-02', 'test@evidencia.com', 'Cliente Evidencia', 'Ecuador', NOW(), 1, NOW());

# Verificar
SELECT customer_id, email, full_name FROM customers WHERE customer_id = 'EVIDENCIA-02';
```

```bash
# Terminal 2: Conectar a PostgreSQL y verificar (esperar 10 segundos)
docker exec -it postgres-america psql -U symmetricds -d globalshop

# Verificar que se replicó
SELECT customer_id, email, full_name FROM customers WHERE customer_id = 'EVIDENCIA-02';
```

**Captura:** Ambas terminales mostrando la replicación de MySQL a PostgreSQL

#### 4. UPDATE Bidireccional (`04_update.png`)

```bash
# En PostgreSQL
UPDATE products SET base_price = 299.99 WHERE product_id = 'EVIDENCIA-01';
SELECT product_id, base_price FROM products WHERE product_id = 'EVIDENCIA-01';
```

```bash
# En MySQL (esperar 10 segundos)
SELECT product_id, base_price FROM products WHERE product_id = 'EVIDENCIA-01';
-- Debe mostrar 299.99
```

**Captura:** Mostrar el UPDATE y la verificación en la otra BD

#### 5. DELETE Bidireccional (`05_delete.png`)

```bash
# En MySQL
DELETE FROM customers WHERE customer_id = 'EVIDENCIA-02';
SELECT COUNT(*) FROM customers WHERE customer_id = 'EVIDENCIA-02';
-- Debe retornar 0
```

```bash
# En PostgreSQL (esperar 10 segundos)
SELECT COUNT(*) FROM customers WHERE customer_id = 'EVIDENCIA-02';
-- Debe retornar 0
```

**Captura:** Mostrar el DELETE y la verificación

### Documentar Evidencias

Crear `evidencias/README.md`:

```markdown
# Evidencias de Replicación Bidireccional

## Estudiante
- **Nombre:** [Tu nombre]
- **Cédula:** [Tu cédula]
- **Fecha:** [Fecha de pruebas]

## Descripción de Capturas

### 01_arquitectura.png
Muestra los 4 contenedores corriendo correctamente.

### 02_insert_pg_mysql.png
Inserción en PostgreSQL replicada a MySQL.
- Producto ID: EVIDENCIA-01
- Tiempo de replicación: ~10 segundos

### 03_insert_mysql_pg.png
Inserción en MySQL replicada a PostgreSQL.
- Cliente ID: EVIDENCIA-02  
- Tiempo de replicación: ~10 segundos

### 04_update.png
Actualización bidireccional funcionando.

### 05_delete.png
Eliminación bidireccional funcionando.

## Conclusión
La replicación bidireccional está funcionando correctamente en ambas direcciones.
```

### Subir Evidencias

```bash
git add replication-proofs/
git commit -m "Add: Evidencias de replicación bidireccional"
git push origin student/nombre_apellido_cedula
```

### Estructura Final de tu Rama

```
student/tu_nombre_apellido_cedula/
├── docker-compose.yml                    ← Tu solución
├── symmetricds/                          ← Configuraciones completadas
│   ├── america/...
│   └── europe/...
└── replication-proofs/                   ← Tus evidencias (20pts)
    ├── 01_insert_pg_to_mysql.png
    ├── 02_insert_mysql_to_pg.png
    ├── 03_update_bidireccional.png
    ├── 04_delete_bidireccional.png
    └── README.md
```

## 📞 Soporte

Si tienes dudas sobre el enunciado (NO sobre la solución):
- Revisa la documentación en `docs/`
- Verifica los logs de Docker: `docker compose logs`
- Consulta la documentación oficial de SymmetricDS

## 🏆 ¡Buena Suerte!

Este examen evalúa tu capacidad para:
- Diseñar arquitecturas distribuidas con Docker
- Configurar replicación de datos entre sistemas heterogéneos
- Resolver problemas de sincronización en sistemas distribuidos
- Trabajar con herramientas empresariales de replicación

**Tiempo estimado**: 2-3 horas

---

**Versión**: 1.0  
**Fecha**: Enero 2026  
**Materia**: Administración de Bases de Datos  
