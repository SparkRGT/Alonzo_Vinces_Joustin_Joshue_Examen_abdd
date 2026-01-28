#!/bin/bash

# ============================================
# SCRIPT DE CALIFICACIÓN AUTOMÁTICA - TODOS LOS ESTUDIANTES
# Ejecuta desde main, califica todas las ramas student/*
# Genera JSON, CSV, reportes individuales
# ============================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Directorio de resultados
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S-05:00")
RESULTS_DIR="resultados_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

# Arrays para acumular resultados
declare -a ESTUDIANTES=()
TOTAL_ESTUDIANTES=0
APROBADOS=0
REPROBADOS=0
SUMA_CALIFICACIONES=0

# ============================================
# Banner
# ============================================

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║    SISTEMA DE CALIFICACIÓN AUTOMÁTICA MASIVA - ABDD          ║"
    echo "║    Replicación Bidireccional con SymmetricDS                 ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}Este script calificará automáticamente a TODOS los estudiantes${NC}"
    echo -e "${BLUE}que hayan subido su rama al repositorio.${NC}"
    echo ""
    echo -e "${YELLOW}Resultados se guardarán en: ${BOLD}$RESULTS_DIR/${NC}"
    echo ""
}

# ============================================
# Calificar un estudiante
# ============================================

calificar_estudiante() {
    local branch=$1
    local student_name=""
    local student_id=""
    
    # Extraer información del nombre de la rama
    if [[ $branch =~ student/(.+)_(.+)_([0-9]+) ]]; then
        local nombre="${BASH_REMATCH[1]}"
        local apellido="${BASH_REMATCH[2]}"
        student_id="${BASH_REMATCH[3]}"
        student_name="${nombre} ${apellido}"
    else
        student_name="Desconocido"
        student_id="0000000000"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Calificando: ${GREEN}$student_name${NC} ${BLUE}($student_id)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Cambiar a la rama del estudiante
    if ! git checkout "$branch" > /dev/null 2>&1; then
        echo -e "${RED}✗ Error: No se pudo cambiar a la rama $branch${NC}"
        return 1
    fi
    
    # Variables de puntuación
    local docker_compose_pts=0
    local containers_pts=0
    local databases_pts=0
    local symmetricds_pts=0
    local replication_pts=0
    local total_pts=0
    local tests_passed=0
    local tests_total=20
    
    # ========== VALIDACIÓN 1: Docker Compose (20pts) ==========
    echo -e "${YELLOW}[1/5]${NC} Validando Docker Compose..."
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}  ✗ docker-compose.yml no existe${NC}"
    else
        ((docker_compose_pts+=5))
        ((tests_passed++))
        
        if docker compose config > /dev/null 2>&1; then
            ((docker_compose_pts+=5))
            ((tests_passed++))
            
            # Verificar servicios
            local config_output=$(docker compose config 2>/dev/null)
            if echo "$config_output" | grep -q "postgres-america:" && \
               echo "$config_output" | grep -q "mysql-europe:"; then
                ((docker_compose_pts+=5))
                ((tests_passed++))
            fi
            
            if echo "$config_output" | grep -q "symmetricds-america:" && \
               echo "$config_output" | grep -q "symmetricds-europe:"; then
                ((docker_compose_pts+=5))
                ((tests_passed++))
            fi
        fi
    fi
    echo -e "${GREEN}  ✓ Docker Compose: $docker_compose_pts / 20 pts${NC}"
    
    # ========== VALIDACIÓN 2: Contenedores (20pts) ==========
    echo -e "${YELLOW}[2/5]${NC} Levantando y validando contenedores..."
    
    # Limpiar ambiente previo
    docker compose down -v > /dev/null 2>&1 || true
    
    if docker compose up -d > /dev/null 2>&1; then
        sleep 60  # Esperar inicialización
        
        if docker compose ps | grep -q "postgres-america.*Up"; then
            ((containers_pts+=5))
            ((tests_passed++))
        fi
        
        if docker compose ps | grep -q "mysql-europe.*Up"; then
            ((containers_pts+=5))
            ((tests_passed++))
        fi
        
        if docker compose ps | grep -q "symmetricds-america.*Up"; then
            ((containers_pts+=5))
            ((tests_passed++))
        fi
        
        if docker compose ps | grep -q "symmetricds-europe.*Up"; then
            ((containers_pts+=5))
            ((tests_passed++))
        fi
    fi
    echo -e "${GREEN}  ✓ Contenedores: $containers_pts / 20 pts${NC}"
    
    # ========== VALIDACIÓN 3: Bases de Datos (15pts) ==========
    echo -e "${YELLOW}[3/5]${NC} Validando bases de datos..."
    
    if docker exec postgres-america psql -U symmetricds -d globalshop -c "SELECT 1;" > /dev/null 2>&1; then
        ((databases_pts+=5))
        ((tests_passed++))
    fi
    
    local pg_tables=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('products','inventory','customers','promotions');" 2>/dev/null | tr -d ' ')
    if [ "$pg_tables" = "4" ]; then
        ((databases_pts+=5))
        ((tests_passed++))
    fi
    
    if docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e "SELECT 1;" > /dev/null 2>&1; then
        ((databases_pts+=5))
        ((tests_passed++))
    fi
    echo -e "${GREEN}  ✓ Bases de Datos: $databases_pts / 15 pts${NC}"
    
    # ========== VALIDACIÓN 4: SymmetricDS (15pts) ==========
    echo -e "${YELLOW}[4/5]${NC} Validando SymmetricDS..."
    
    local sym_tables=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'sym_%';" 2>/dev/null | tr -d ' ')
    if [ "$sym_tables" -gt 30 ]; then
        ((symmetricds_pts+=5))
        ((tests_passed++))
    fi
    
    local sym_tables_mysql=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='globalshop' AND table_name LIKE 'sym_%';" 2>/dev/null)
    if [ "$sym_tables_mysql" -gt 30 ]; then
        ((symmetricds_pts+=5))
        ((tests_passed++))
    fi
    
    local node_groups=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -c \
        "SELECT COUNT(*) FROM sym_node_group;" 2>/dev/null | tr -d ' ')
    if [ "$node_groups" -ge 2 ]; then
        ((symmetricds_pts+=5))
        ((tests_passed++))
    fi
    echo -e "${GREEN}  ✓ SymmetricDS: $symmetricds_pts / 15 pts${NC}"
    
    # ========== VALIDACIÓN 5: Replicación (30pts) ==========
    echo -e "${YELLOW}[5/5]${NC} Validando replicación bidireccional..."
    
    sleep 15
    
    # Limpiar datos previos
    docker exec postgres-america psql -U symmetricds -d globalshop -c \
        "DELETE FROM products WHERE product_id LIKE 'CAL-%';" > /dev/null 2>&1
    docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e \
        "DELETE FROM products WHERE product_id LIKE 'CAL-%';" > /dev/null 2>&1
    sleep 5
    
    # Test INSERT PG → MySQL (10pts)
    docker exec postgres-america psql -U symmetricds -d globalshop -c \
        "INSERT INTO products VALUES ('CAL-PG-001', 'Test PG', 'Test', 99.99, 'Test', true, NOW(), NOW());" > /dev/null 2>&1
    sleep 15
    local count_my=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT COUNT(*) FROM products WHERE product_id = 'CAL-PG-001';" 2>/dev/null)
    if [ "$count_my" = "1" ]; then
        ((replication_pts+=10))
        ((tests_passed++))
    fi
    
    # Test INSERT MY → PG (10pts)
    docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e \
        "INSERT INTO products VALUES ('CAL-MY-001', 'Test MY', 'Test', 149.99, 'Test', 1, NOW(), NOW());" > /dev/null 2>&1
    sleep 15
    local count_pg=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -A -c \
        "SELECT COUNT(*) FROM products WHERE product_id = 'CAL-MY-001';" 2>/dev/null)
    if [ "$count_pg" = "1" ]; then
        ((replication_pts+=10))
        ((tests_passed++))
    fi
    
    # Test UPDATE PG → MY (5pts)
    docker exec postgres-america psql -U symmetricds -d globalshop -c \
        "UPDATE products SET base_price = 88.88 WHERE product_id = 'CAL-PG-001';" > /dev/null 2>&1
    sleep 15
    local price_my=$(docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -N -e \
        "SELECT base_price FROM products WHERE product_id = 'CAL-PG-001';" 2>/dev/null)
    if [ "$price_my" = "88.88" ]; then
        ((replication_pts+=5))
        ((tests_passed++))
    fi
    
    # Test DELETE MY → PG (5pts)
    docker exec mysql-europe mysql -u symmetricds -psymmetricds globalshop -e \
        "DELETE FROM products WHERE product_id = 'CAL-MY-001';" > /dev/null 2>&1
    sleep 15
    local del_pg=$(docker exec postgres-america psql -U symmetricds -d globalshop -t -A -c \
        "SELECT COUNT(*) FROM products WHERE product_id = 'CAL-MY-001';" 2>/dev/null)
    if [ "$del_pg" = "0" ]; then
        ((replication_pts+=5))
        ((tests_passed++))
    fi
    
    echo -e "${GREEN}  ✓ Replicación: $replication_pts / 30 pts${NC}"
    
    # ========== CALCULAR TOTAL ==========
    total_pts=$((docker_compose_pts + containers_pts + databases_pts + symmetricds_pts + replication_pts))
    local percentage=$((total_pts * 100 / 100))
    
    # Determinar nota y aprobación
    local nota=""
    local aprobado="false"
    if [ $percentage -ge 90 ]; then
        nota="A - Excelente"
        aprobado="true"
        ((APROBADOS++))
    elif [ $percentage -ge 80 ]; then
        nota="B - Bueno"
        aprobado="true"
        ((APROBADOS++))
    elif [ $percentage -ge 70 ]; then
        nota="C - Aceptable"
        aprobado="true"
        ((APROBADOS++))
    elif [ $percentage -ge 60 ]; then
        nota="D - Suficiente"
        aprobado="true"
        ((APROBADOS++))
    else
        nota="F - Insuficiente"
        aprobado="false"
        ((REPROBADOS++))
    fi
    
    # Mostrar resultado
    echo ""
    echo -e "${BOLD}Resultado:${NC} $total_pts / 100 pts - ${nota}"
    echo ""
    
    # Guardar para JSON consolidado
    ESTUDIANTES+=("{
      \"nombre\": \"$student_name\",
      \"cedula\": \"$student_id\",
      \"rama\": \"$branch\",
      \"calificacion\": {
        \"total\": $total_pts,
        \"nota\": \"$nota\",
        \"aprobado\": $aprobado
      },
      \"desglose\": {
        \"docker_compose\": { \"obtenido\": $docker_compose_pts, \"maximo\": 20 },
        \"contenedores\": { \"obtenido\": $containers_pts, \"maximo\": 20 },
        \"bases_datos\": { \"obtenido\": $databases_pts, \"maximo\": 15 },
        \"symmetricds\": { \"obtenido\": $symmetricds_pts, \"maximo\": 15 },
        \"replicacion\": { \"obtenido\": $replication_pts, \"maximo\": 30 }
      },
      \"detalles\": {
        \"tests_pasados\": $tests_passed,
        \"tests_totales\": $tests_total,
        \"tablas_creadas\": 4,
        \"tablas_requeridas\": 4,
        \"servicios_docker\": 4
      }
    }")
    
    ((SUMA_CALIFICACIONES+=total_pts))
    
    # Generar reporte individual
    cat > "$RESULTS_DIR/${student_name// /_}_${student_id}.log" << EOF
============================================================
REPORTE INDIVIDUAL DE CALIFICACIÓN
============================================================
Estudiante: $student_name
Cédula: $student_id
Rama: $branch
Fecha: $(date)

CALIFICACIÓN:
  Total: $total_pts / 100
  Nota: $nota
  Estado: $([ "$aprobado" = "true" ] && echo "APROBADO ✓" || echo "REPROBADO ✗")

DESGLOSE:
  1. Docker Compose:      $docker_compose_pts / 20
  2. Contenedores:        $containers_pts / 20
  3. Bases de Datos:      $databases_pts / 15
  4. SymmetricDS:         $symmetricds_pts / 15
  5. Replicación:         $replication_pts / 30

ESTADÍSTICAS:
  Tests pasados: $tests_passed / $tests_total
  Porcentaje: ${percentage}%
============================================================
EOF
    
    # Limpiar contenedores
    docker compose down -v > /dev/null 2>&1 || true
    
    # Volver a main
    git checkout main > /dev/null 2>&1
}

# ============================================
# Generar reportes consolidados
# ============================================

generate_consolidated_reports() {
    local promedio=0
    if [ $TOTAL_ESTUDIANTES -gt 0 ]; then
        promedio=$((SUMA_CALIFICACIONES / TOTAL_ESTUDIANTES))
    fi
    
    local porcentaje_aprobados=0
    if [ $TOTAL_ESTUDIANTES -gt 0 ]; then
        porcentaje_aprobados=$(awk "BEGIN {printf \"%.2f\", ($APROBADOS * 100.0 / $TOTAL_ESTUDIANTES)}")
    fi
    
    # ========== JSON CONSOLIDADO ==========
    local estudiantes_json=$(IFS=,; echo "${ESTUDIANTES[*]}")
    
    cat > "$RESULTS_DIR/calificaciones.json" << EOF
{
  "fecha": "$TIMESTAMP_ISO",
  "estudiantes": [
    $estudiantes_json
  ],
  "estadisticas": {
    "total_estudiantes": $TOTAL_ESTUDIANTES,
    "aprobados": $APROBADOS,
    "reprobados": $REPROBADOS,
    "promedio": $promedio,
    "porcentaje_aprobados": $porcentaje_aprobados
  }
}
EOF
    
    # ========== CSV CONSOLIDADO ==========
    cat > "$RESULTS_DIR/calificaciones.csv" << 'EOF'
nombre,cedula,rama,docker_compose,contenedores,bases_datos,symmetricds,replicacion,total,nota,aprobado
EOF
    
    # Procesar cada estudiante para CSV
    for branch in $(git branch -r | grep 'origin/student/' | sed 's/origin\///'); do
        git checkout "$branch" > /dev/null 2>&1
        
        local student_name=""
        local student_id=""
        if [[ $branch =~ student/(.+)_(.+)_([0-9]+) ]]; then
            student_name="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
            student_id="${BASH_REMATCH[3]}"
        fi
        
        # Buscar el log individual para extraer datos
        if [ -f "$RESULTS_DIR/${student_name// /_}_${student_id}.log" ]; then
            local total=$(grep "Total:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | awk '{print $2}' | cut -d'/' -f1)
            local nota=$(grep "Nota:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | cut -d':' -f2 | xargs)
            local aprobado=$(grep "Estado:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | grep -q "APROBADO" && echo "true" || echo "false")
            
            local dc=$(grep "Docker Compose:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | awk '{print $3}' | cut -d'/' -f1)
            local cont=$(grep "Contenedores:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | awk '{print $2}' | cut -d'/' -f1)
            local db=$(grep "Bases de Datos:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | awk '{print $4}' | cut -d'/' -f1)
            local sym=$(grep "SymmetricDS:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | awk '{print $2}' | cut -d'/' -f1)
            local rep=$(grep "Replicación:" "$RESULTS_DIR/${student_name// /_}_${student_id}.log" | awk '{print $2}' | cut -d'/' -f1)
            
            echo "\"$student_name\",$student_id,$branch,$dc,$cont,$db,$sym,$rep,$total,\"$nota\",$aprobado" >> "$RESULTS_DIR/calificaciones.csv"
        fi
    done
    
    git checkout main > /dev/null 2>&1
    
    # ========== RESUMEN TXT ==========
    cat > "$RESULTS_DIR/RESUMEN.txt" << EOF
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         REPORTE CONSOLIDADO DE CALIFICACIONES                ║
║         Examen: Replicación Bidireccional SymmetricDS        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Fecha de evaluación: $(date)
Generado automáticamente por: calificar_todos.sh

ESTADÍSTICAS GENERALES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Total de estudiantes:       $TOTAL_ESTUDIANTES
  Aprobados:                  $APROBADOS
  Reprobados:                 $REPROBADOS
  Promedio general:           $promedio / 100
  % Aprobación:               ${porcentaje_aprobados}%

DISTRIBUCIÓN DE CALIFICACIONES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    # Listar cada estudiante
    for logfile in "$RESULTS_DIR"/*.log; do
        if [ -f "$logfile" ]; then
            local nombre=$(basename "$logfile" .log | sed 's/_/ /g')
            local total=$(grep "Total:" "$logfile" | awk '{print $2}' | cut -d'/' -f1)
            local nota=$(grep "Nota:" "$logfile" | cut -d':' -f2 | xargs)
            echo "  • $nombre: $total pts - $nota" >> "$RESULTS_DIR/RESUMEN.txt"
        fi
    done
    
    cat >> "$RESULTS_DIR/RESUMEN.txt" << EOF

ARCHIVOS GENERADOS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  → calificaciones.json    (Formato JSON para sistemas)
  → calificaciones.csv     (Formato CSV para Excel)
  → RESUMEN.txt            (Este archivo)
  → *.log                  (Reportes individuales)

============================================================
EOF
}

# ============================================
# Función Principal
# ============================================

main() {
    print_banner
    
    # Verificar que estamos en main
    local current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ]; then
        echo -e "${RED}Error: Debes ejecutar este script desde la rama main${NC}"
        echo -e "${YELLOW}Ejecuta: git checkout main${NC}"
        exit 1
    fi
    
    # Actualizar ramas
    echo -e "${BLUE}Actualizando ramas del repositorio...${NC}"
    git fetch --all > /dev/null 2>&1
    
    # Obtener todas las ramas de estudiantes
    local student_branches=($(git branch -r | grep 'origin/student/' | sed 's/origin\///'))
    TOTAL_ESTUDIANTES=${#student_branches[@]}
    
    if [ $TOTAL_ESTUDIANTES -eq 0 ]; then
        echo -e "${RED}No se encontraron ramas de estudiantes (student/*)${NC}"
        echo -e "${YELLOW}Los estudiantes deben crear ramas con formato: student/nombre_apellido_cedula${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Encontradas $TOTAL_ESTUDIANTES rama(s) de estudiantes${NC}"
    echo ""
    
    # Mostrar ramas encontradas
    echo -e "${BLUE}Ramas a calificar:${NC}"
    for branch in "${student_branches[@]}"; do
        echo -e "  • $branch"
    done
    echo ""
    
    read -p "Presiona ENTER para comenzar la calificación o Ctrl+C para cancelar..."
    echo ""
    
    # Calificar cada estudiante
    local counter=1
    for branch in "${student_branches[@]}"; do
        echo ""
        echo -e "${CYAN}${BOLD}[Estudiante $counter / $TOTAL_ESTUDIANTES]${NC}"
        calificar_estudiante "$branch"
        ((counter++))
        sleep 2
    done
    
    # Generar reportes consolidados
    echo ""
    echo -e "${BLUE}${BOLD}Generando reportes consolidados...${NC}"
    generate_consolidated_reports
    
    # Mostrar resumen final
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║            ✓ CALIFICACIÓN COMPLETADA                          ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Estudiantes calificados: ${BOLD}$TOTAL_ESTUDIANTES${NC}"
    echo -e "${GREEN}Aprobados: ${BOLD}$APROBADOS${NC}"
    echo -e "${RED}Reprobados: ${BOLD}$REPROBADOS${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}📁 Resultados guardados en:${NC} ${YELLOW}$RESULTS_DIR/${NC}"
    echo ""
    echo -e "${BLUE}Archivos generados:${NC}"
    echo -e "  → ${CYAN}$RESULTS_DIR/calificaciones.json${NC}  (JSON consolidado)"
    echo -e "  → ${CYAN}$RESULTS_DIR/calificaciones.csv${NC}   (CSV para Excel)"
    echo -e "  → ${CYAN}$RESULTS_DIR/RESUMEN.txt${NC}          (Resumen legible)"
    echo -e "  → ${CYAN}$RESULTS_DIR/*.log${NC}                (Reportes individuales)"
    echo ""
    
    # Mostrar contenido del JSON
    echo -e "${YELLOW}${BOLD}📄 Contenido del JSON:${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    cat "$RESULTS_DIR/calificaciones.json"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Mostrar quick stats
    echo -e "${BLUE}${BOLD}📊 Estadísticas Rápidas:${NC}"
    echo -e "   Promedio: $(awk "BEGIN {printf \"%.2f\", ($SUMA_CALIFICACIONES / $TOTAL_ESTUDIANTES)}")/100"
    echo -e "   Aprobación: $(awk "BEGIN {printf \"%.2f\", ($APROBADOS * 100.0 / $TOTAL_ESTUDIANTES)}")%"
    echo ""
}

# Ejecutar
main
exit 0
