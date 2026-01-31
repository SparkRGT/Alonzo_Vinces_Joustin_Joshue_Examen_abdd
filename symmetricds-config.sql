-- ============================================
-- SymmetricDS Configuration for PostgreSQL (América)
-- Este script debe ejecutarse después de que SymmetricDS cree sus tablas
-- ============================================

-- Esperar a que existan las tablas de SymmetricDS
DO $$
BEGIN
    -- Loop hasta que las tablas existan (máximo 60 intentos = 60 segundos)
    FOR i IN 1..60 LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sym_node_group') THEN
            EXIT;
        END IF;
        PERFORM pg_sleep(1);
    END LOOP;
END $$;

-- 1. DEFINIR GRUPOS DE NODOS
INSERT INTO sym_node_group (node_group_id, description) 
VALUES ('europe-store', 'Stores in Europe region')
ON CONFLICT (node_group_id) DO NOTHING;

-- 2. ENLACES BIDIRECCIONALES ENTRE GRUPOS
INSERT INTO sym_node_group_link (source_node_group_id, target_node_group_id, data_event_action) 
VALUES ('america-store', 'europe-store', 'W')
ON CONFLICT DO NOTHING;

INSERT INTO sym_node_group_link (source_node_group_id, target_node_group_id, data_event_action) 
VALUES ('europe-store', 'america-store', 'W')
ON CONFLICT DO NOTHING;

-- 3. DEFINIR CANALES DE SINCRONIZACIÓN
INSERT INTO sym_channel (channel_id, processing_order, max_batch_size, enabled, description)
VALUES ('products_channel', 10, 10000, 1, 'Channel for products catalog')
ON CONFLICT (channel_id) DO NOTHING;

INSERT INTO sym_channel (channel_id, processing_order, max_batch_size, enabled, description)
VALUES ('inventory_channel', 20, 10000, 1, 'Channel for inventory data')
ON CONFLICT (channel_id) DO NOTHING;

INSERT INTO sym_channel (channel_id, processing_order, max_batch_size, enabled, description)
VALUES ('customers_channel', 30, 10000, 1, 'Channel for customer data')
ON CONFLICT (channel_id) DO NOTHING;

INSERT INTO sym_channel (channel_id, processing_order, max_batch_size, enabled, description)
VALUES ('promotions_channel', 40, 10000, 1, 'Channel for promotions')
ON CONFLICT (channel_id) DO NOTHING;

-- 4. DEFINIR TRIGGERS
INSERT INTO sym_trigger (trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES ('products_trigger', 'products', 'products_channel', current_timestamp, current_timestamp)
ON CONFLICT (trigger_id) DO NOTHING;

INSERT INTO sym_trigger (trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES ('inventory_trigger', 'inventory', 'inventory_channel', current_timestamp, current_timestamp)
ON CONFLICT (trigger_id) DO NOTHING;

INSERT INTO sym_trigger (trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES ('customers_trigger', 'customers', 'customers_channel', current_timestamp, current_timestamp)
ON CONFLICT (trigger_id) DO NOTHING;

INSERT INTO sym_trigger (trigger_id, source_table_name, channel_id, last_update_time, create_time)
VALUES ('promotions_trigger', 'promotions', 'promotions_channel', current_timestamp, current_timestamp)
ON CONFLICT (trigger_id) DO NOTHING;

-- 5. DEFINIR ROUTERS
INSERT INTO sym_router (router_id, source_node_group_id, target_node_group_id, router_type, create_time, last_update_time)
VALUES ('america_to_europe', 'america-store', 'europe-store', 'default', current_timestamp, current_timestamp)
ON CONFLICT (router_id) DO NOTHING;

INSERT INTO sym_router (router_id, source_node_group_id, target_node_group_id, router_type, create_time, last_update_time)
VALUES ('europe_to_america', 'europe-store', 'america-store', 'default', current_timestamp, current_timestamp)
ON CONFLICT (router_id) DO NOTHING;

-- 6. VINCULAR TRIGGERS CON ROUTERS
INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('products_trigger', 'america_to_europe', 100, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('products_trigger', 'europe_to_america', 100, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('inventory_trigger', 'america_to_europe', 200, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('inventory_trigger', 'europe_to_america', 200, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('customers_trigger', 'america_to_europe', 300, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('customers_trigger', 'europe_to_america', 300, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('promotions_trigger', 'america_to_europe', 400, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

INSERT INTO sym_trigger_router (trigger_id, router_id, initial_load_order, last_update_time, create_time)
VALUES ('promotions_trigger', 'europe_to_america', 400, current_timestamp, current_timestamp)
ON CONFLICT DO NOTHING;

-- 7. REGISTRAR NODO EUROPA
INSERT INTO sym_node (node_id, node_group_id, external_id, sync_enabled, sync_url)
VALUES ('002', 'europe-store', '002', 1, 'http://symmetricds-europe:31416/sync/europe')
ON CONFLICT (node_id) DO NOTHING;

INSERT INTO sym_node_security (node_id, node_password, registration_enabled, registration_time, initial_load_enabled, initial_load_time, created_at_node_id)
VALUES ('002', '002', 0, current_timestamp, 0, current_timestamp, '001')
ON CONFLICT (node_id) DO NOTHING;
-- ============================================
-- NOTA SOBRE TRIGGERS AUTOMÁTICOS
-- ============================================
-- 
-- SymmetricDS NO requiere triggers manuales. Cuando se inserta
-- configuración en las tablas sym_trigger y sym_trigger_router,
-- SymmetricDS AUTOMÁTICAMENTE crea triggers en las tablas de datos
-- (products, inventory, customers, promotions) para capturar:
--   - INSERT (nuevos registros)
--   - UPDATE (modificaciones)
--   - DELETE (eliminaciones)
--
-- Los triggers creados por SymmetricDS tienen nombres como:
--   - sym_on_i_for_products (INSERT)
--   - sym_on_u_for_products (UPDATE)  
--   - sym_on_d_for_products (DELETE)
--
-- Estos triggers capturan los cambios y los guardan en la tabla
-- sym_data para posteriormente sincronizarlos con otros nodos.
--
-- ============================================
-- COMANDOS PARA VER TRIGGERS AUTOMÁTICOS
-- ============================================

-- En PostgreSQL (América):
-- SELECT trigger_name, event_object_table, action_timing, event_manipulation
-- FROM information_schema.triggers 
-- WHERE trigger_name LIKE 'sym_%'
-- ORDER BY event_object_table, trigger_name;

-- En MySQL (Europa):
-- SHOW TRIGGERS WHERE `Trigger` LIKE 'sym_%';

-- ============================================
-- FUNCIONES CREADAS POR SYMMETRICDS
-- ============================================
-- SymmetricDS también crea funciones auxiliares automáticamente:

-- Ver funciones en PostgreSQL:
-- SELECT routine_name, routine_type 
-- FROM information_schema.routines 
-- WHERE routine_name LIKE 'fsym_%' OR routine_name LIKE 'sym_%'
-- ORDER BY routine_name;

-- Estas funciones son llamadas por los triggers para:
--   - Capturar datos (data capture)
--   - Generar eventos de sincronización
--   - Manejar conflictos

-- ============================================
-- VERIFICACIÓN DE LA CONFIGURACIÓN
-- ============================================

-- Ver grupos de nodos:
-- SELECT * FROM sym_node_group;

-- Ver enlaces entre grupos:
-- SELECT * FROM sym_node_group_link;

-- Ver canales:
-- SELECT channel_id, processing_order, enabled FROM sym_channel;

-- Ver triggers configurados:
-- SELECT trigger_id, source_table_name, channel_id FROM sym_trigger;

-- Ver routers:
-- SELECT router_id, source_node_group_id, target_node_group_id FROM sym_router;

-- Ver nodos registrados:
-- SELECT node_id, node_group_id, sync_enabled, sync_url FROM sym_node;

-- Ver batches pendientes:
-- SELECT batch_id, channel_id, status, error_flag FROM sym_outgoing_batch 
-- WHERE status != 'OK' ORDER BY batch_id DESC LIMIT 10;